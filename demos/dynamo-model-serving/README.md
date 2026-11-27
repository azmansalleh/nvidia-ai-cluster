# Dynamo model serving

Serve **Nemotron 3.5 Lightning NVFP4** through Dynamo with one H200 worker,
DSpark speculative decoding, and a KV-aware frontend.

| Setting | Value |
|---|---|
| Application / namespace | `demo-dynamo-model-serving` |
| Dynamo deployment | `dynamo-model-serving` |
| Target model | `nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4` |
| Draft model | `nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4-DSpark` |
| GPU | 1 H200 NVL |
| Worker resources | 2 CPU, 40 GiB RAM, 64 GiB ephemeral storage requested |
| Worker limits | 6 CPU, 48 GiB RAM, 96 GiB ephemeral storage |
| Request limits | 8 concurrent sequences, 8,192 tokens per sequence |

Requires the shared GPU Operator, NVIDIA runtime class, Dynamo Platform, Grove,
and KAI Scheduler to be healthy. It has no dependency on another demo, a shared
model PVC, or an external gateway. The two public model repositories currently
require no Hugging Face token. Outbound access to Hugging Face and NGC is required.

Model files download automatically into a worker-local, disk-backed `emptyDir`
cache (80 GiB maximum). The frontend has its own 2 GiB tokenizer cache. A
container restart can reuse its Pod's cache; a replacement Pod or disabling the
demo discards that cache. The target and draft weights total approximately
21.3 GiB; allow additional space for downloads, runtime images, and compilation.

## Run

Complete the [one-time demo bootstrap](../README.md). Set `enabled: "true"` in
[config.yaml](config.yaml), then commit and push to `main`.

```bash
kubectl --context kubernetes-admin@asalleh-h200-k8s -n argocd get application demo-dynamo-model-serving
kubectl --context kubernetes-admin@asalleh-h200-k8s -n demo-dynamo-model-serving get dgd,pods,svc
```

After the DGD appears, wait for readiness. The first start includes image and
model downloads and compilation:

```bash
kubectl --context kubernetes-admin@asalleh-h200-k8s -n demo-dynamo-model-serving \
  wait --for=condition=Ready dynamographdeployment/dynamo-model-serving --timeout=30m
bash demos/dynamo-model-serving/smoke-test.sh
```

The smoke test checks model discovery and a successful chat response, then closes
its temporary port-forward. For interactive requests, run:

```bash
kubectl --context kubernetes-admin@asalleh-h200-k8s -n demo-dynamo-model-serving \
  port-forward svc/dynamo-model-serving-frontend 8000:8000
```

In another terminal:

```bash
curl --fail-with-body --max-time 120 http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"nvidia/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-NVFP4","messages":[{"role":"user","content":"Explain GPU inference in two sentences."}],"temperature":0,"max_tokens":256,"stream":true}'
```

Set `enabled: "false"`, commit, and push to remove the demo and release its GPU.
Its empty namespace may remain; the platform continues running.

## Recipe adaptations

Based on the [upstream H200 DSpark KV-router recipe](https://github.com/ai-dynamo/dynamo/blob/b08b769c4b0a461303039d4c09efe33b684c5c57/recipes/nemotron-3.5-lightning/vllm/agg-h200-dspark-kv-router/deploy.yaml).

- Reduced four workers to one; lowered the 128 GiB memory request, concurrency
  from 512 to 8, and token batch from 32,768 to 8,192. Capped context at 8,192.
- Matched the cluster's `NVIDIA-H200-NVL` label and `nvidia` runtime class.
- Replaced the pre-populated shared PVC and offline mode with independent local
  caches and online downloads. Removed the placeholder image-pull secret.
- Reduced shared-memory capacity from 40 GiB to 8 GiB, managed by Dynamo.
- Kept the recipe's special `1.5.0-nemotron-3.5-lightning-dev.1` image, pinned by
  digest, and declared its runtime compatibility as `1.5.0`. The platform stays
  at 1.6.2. The generic 1.6.2 runtime is not substituted for this recipe image.
- Kept real DSpark acceptance and KV events; removed the unused synthetic
  benchmark configuration. With one worker, this does not demonstrate a
  routing advantage across replicas.

This is a reduced-capacity adaptation. Model readiness and inference must pass
on this cluster before treating it as a validated deployment.
