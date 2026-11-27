# Dynamo model serving

Serves **Nemotron 3.5 Lightning NVFP4** on one H200 GPU using Dynamo and vLLM.
Exposes an OpenAI-compatible API with DSpark speculative decoding and a
KV-aware frontend.

Runs independently in the `demo-dynamo-model-serving` namespace.

The main Kubernetes resource is **`DynamoGraphDeployment`**:

| Resource | Purpose |
|---|---|
| `DynamoGraphDeployment` | Defines the frontend and one GPU worker, managed by the Dynamo Operator. |
| `ConfigMap` | Holds the DSpark speculative decoding settings. |
| `Service` | Exposes the frontend API inside the cluster. |
| `emptyDir` volumes | Cache model files locally for the lifetime of each Pod. |
