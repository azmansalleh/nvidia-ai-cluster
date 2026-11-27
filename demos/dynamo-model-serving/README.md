# Dynamo model serving

Serves **Nemotron 3.5 Lightning NVFP4** on one H200 using Dynamo and vLLM,
with DSpark speculative decoding and KV-aware routing.
Runs independently in `demo-dynamo-model-serving`.

| Kubernetes resource | Purpose |
|---|---|
| `DynamoGraphDeployment` | Runs the frontend and one GPU worker. |
| `AgentgatewayModel` | Publishes `nemotron` through the shared `/v1` API. |
| `ConfigMap` | Holds DSpark settings. |
| `emptyDir` | Caches model files for the lifetime of each Pod. |

`GET /v1/models` lists registered models. Send `"model": "nemotron"` to
`POST /v1/chat/completions`; agentgateway translates it to the full model ID
and forwards it to this demo's Dynamo frontend.

Requires agentgateway **v1.7.0** and the shared [gateway configuration](../../argocd/README.md).
Run `./demos/dynamo-model-serving/smoke-test.sh` to check discovery, model selection,
and inference through agentgateway.
