# Demos

Independent workloads on the shared AICR platform. Each demo owns its
Dynamo deployment, configuration, and cache in a separate namespace. No demo
requires another demo to be enabled. Available GPUs, CPU, memory, and storage
are shared cluster capacity.

| Demo | Namespace | GPU requirement |
|---|---|---|
| [Dynamo model serving](dynamo-model-serving/) | `demo-dynamo-model-serving` | See demo prerequisites |

After committing and pushing these files to `main`, apply the ApplicationSet
once from the repository root:

```bash
kubectl --context kubernetes-admin@asalleh-h200-k8s apply -f argocd/demos-applicationset.yaml
```

Reapply this file when changing the ApplicationSet itself.

Set `enabled: "true"` in a demo's `config.yaml`, then commit and push to enable
it. Set `enabled: "false"`, commit, and push to remove its Application and
workloads and release its GPUs. Do not delete or edit generated Applications
to toggle a demo: the ApplicationSet reconciles them from Git.

The ApplicationSet polls Git; changes may take a few minutes. To request an
immediate generator refresh after a push:

```bash
kubectl --context kubernetes-admin@asalleh-h200-k8s -n argocd annotate applicationset demos \
  argocd.argoproj.io/application-set-refresh=true --overwrite
```

The platform Application `cluster` has a separate lifecycle. Demo Applications
deploy workload resources only. Benchmarks and checkpoint actions run explicitly.
