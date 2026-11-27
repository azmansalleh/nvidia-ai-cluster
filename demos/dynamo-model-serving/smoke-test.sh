#!/usr/bin/env bash
set -euo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-kubernetes-admin@asalleh-h200-k8s}"
DEMO_PORT="${DEMO_PORT:-18000}"
namespace=demo-dynamo-model-serving
model=nemotron
endpoint="http://127.0.0.1:${DEMO_PORT}"
smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/dynamo-model-serving.XXXXXX")"
forward_pid=

cleanup() {
  if [[ -n "${forward_pid}" ]]; then
    kill "${forward_pid}" 2>/dev/null || true
    wait "${forward_pid}" 2>/dev/null || true
  fi
  rm -rf "${smoke_dir}"
}
trap cleanup EXIT

for dependency in kubectl curl python3; do
  command -v "${dependency}" >/dev/null || { echo "Missing dependency: ${dependency}" >&2; exit 1; }
done

kubectl --context "${KUBE_CONTEXT}" --request-timeout=20s -n "${namespace}" \
  wait --for=condition=Ready dynamographdeployment/dynamo-model-serving --timeout=10s

kubectl --context "${KUBE_CONTEXT}" -n agentgateway-system \
  port-forward svc/inference-gateway "${DEMO_PORT}:80" \
  >"${smoke_dir}/port-forward.log" 2>&1 &
forward_pid=$!

listed=false
for ((attempt = 0; attempt < 60; attempt++)); do
  if ! kill -0 "${forward_pid}" 2>/dev/null; then
    cat "${smoke_dir}/port-forward.log" >&2
    exit 1
  fi
  if curl --fail --silent --show-error --connect-timeout 2 --max-time 5 \
    "${endpoint}/v1/models" -o "${smoke_dir}/models.json" 2>/dev/null && \
    python3 - "${smoke_dir}/models.json" "${model}" <<'PY'
import json
import sys

with open(sys.argv[1]) as response:
    models = json.load(response)
sys.exit(0 if any(item.get('id') == sys.argv[2] for item in models.get('data', [])) else 1)
PY
  then
    listed=true
    break
  fi
  sleep 2
done
if [[ "${listed}" != true ]]; then
  echo "The gateway did not list ${model} within the discovery timeout." >&2
  exit 1
fi

unknown_status="$(curl --silent --show-error --connect-timeout 5 --max-time 15 \
  -o "${smoke_dir}/unknown.json" -w '%{http_code}' \
  "${endpoint}/v1/chat/completions" -H 'Content-Type: application/json' \
  --data '{"model":"unknown-smoke-test-model","messages":[{"role":"user","content":"Hello"}]}')"
python3 - "${smoke_dir}/unknown.json" "${unknown_status}" <<'PY'
import json
import sys

with open(sys.argv[1]) as response:
    body = json.load(response)
if sys.argv[2] != '404' or body.get('error', {}).get('code') != 'model_not_found':
    raise SystemExit('FAIL: unknown model was not rejected: ' + json.dumps(body))
PY

python3 - "${model}" >"${smoke_dir}/request.json" <<'PY'
import json
import sys

json.dump({
    'model': sys.argv[1],
    'messages': [{'role': 'user', 'content': 'Say hello in one short sentence.'}],
    'temperature': 0,
    'max_tokens': 512,
    'stream': False,
}, sys.stdout)
PY

if ! curl --fail-with-body --silent --show-error --connect-timeout 5 --max-time 120 \
  "${endpoint}/v1/chat/completions" -H 'Content-Type: application/json' \
  --data-binary "@${smoke_dir}/request.json" -o "${smoke_dir}/response.json"; then
  cat "${smoke_dir}/response.json" >&2 2>/dev/null || true
  exit 1
fi

python3 - "${smoke_dir}/response.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as response:
    body = json.load(response)
choices = body.get('choices', [])
if body.get('error') or body.get('object') != 'chat.completion' or not choices:
    raise SystemExit('FAIL: invalid chat completion: ' + json.dumps(body))
message = choices[0].get('message', {})
if not (message.get('content') or message.get('reasoning_content') or message.get('reasoning')):
    raise SystemExit('FAIL: chat completion contained no generated text')
print('PASS: gateway model discovery, unknown-model rejection, and chat completion')
if message.get('content'):
    print(message['content'])
PY
