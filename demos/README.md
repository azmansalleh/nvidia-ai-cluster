# Demos

Independent workloads demo on the cluster. Each demo owns its deployment, configuration, and cache in a separate namespace. No demo requires another demo to be enabled. Available GPUs, CPU, memory, and storage are shared cluster capacity.


| Demo                                          | Namespace                   | GPU requirement        |
| --------------------------------------------- | --------------------------- | ---------------------- |
| [Dynamo model serving](dynamo-model-serving/) | `demo-dynamo-model-serving` | See demo prerequisites |


Set `enabled: "true"` in a demo's `config.yaml`, then commit and push to enable  
it. Set `enabled: "false"`, commit, and push to remove its Application and  
workloads and release its GPUs. Do not delete or edit generated Applications  
to toggle a demo: the ApplicationSet reconciles them from Git.