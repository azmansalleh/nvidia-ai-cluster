# nv-ai-cluster

BCM-managed NVIDIA H200 Kubernetes cluster for Dynamo inference.
Configuration generated with AICR 1.3.0 and reconciled by Argo CD.

- **Cluster:** `asalleh-h200-k8s`
- **Nodes:** 1 control-plane node and 2 GPU workers
- **Storage:** `local-path` on the shared BCM filesystem; Snapshot requests a 10 GiB RWX volume

## Inventory

| Component | Chart version | Namespace |
|---|---|---|
| Nodewright Operator | v0.21.0 | `nodewright` |
| BCM node customizations | Local chart | `nodewright` |
| cert-manager | v1.20.2 | `cert-manager` |
| Ephemeral storage metrics | 1.19.2 | `monitoring` |
| KAI Scheduler | v0.17.1 | `kai-scheduler` |
| NVIDIA DRA driver | 0.5.1 | `nvidia-dra-driver` |
| NVSentinel | v1.31.0 | `nvsentinel` |
| Prometheus Adapter | 5.3.0 | `monitoring` |
| Grove | v0.1.0-alpha.14 | `dynamo-system` |
| Dynamo Platform | 1.6.2 | `dynamo-system` |
| Workload-Map (Karta) | 0.3.0 | `karta-system` |
| Snapshot | 0.3.0 | `snapshot` |

GPU Operator, Node Feature Discovery, Prometheus, and gateways are managed separately.

[Demo use cases](demos/README.md).
