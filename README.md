# nv-ai-cluster

Snapshot-based H200/BCM inference infrastructure using AICR 1.3.0 and Argo CD.
Uses the standard built-in recipe, with no Dynamo platform or custom catalog.

## Folders

| Path | Purpose |
|---|---|
| `aicr/config.yaml` | Snapshot settings, existing-component exclusions, and Argo CD bundle options. |
| `aicr/snapshot.yaml` | Local cluster snapshot; ignored by Git. |
| `aicr/recipe.yaml` | Full standard recipe resolved from the snapshot. |
| `bootstrap/` | Argo CD child Application health configuration. |
| `manifests/` | Generated bundle for the additional components; includes the filtered recipe and checksums. |
| `manifests/NNN-*/` | Child Applications, Helm values, and any local chart templates. |

No `--data` directory is used, so there is no `manifests/data/` copy.

## Components

The standard recipe resolves 16 component references. Bundle options leave the
existing GPU Operator/NFD, gateways, Prometheus stack, and monitoring CRDs under
their current management. NKTP is excluded to preserve that monitoring setup;
the optional DRA eviction labeler is omitted by AICR.

The eight components in this bundle are:

| Component | Chart version |
|---|---|
| Nodewright Operator | v0.21.0 |
| BCM node customizations | Local chart from the recipe |
| cert-manager | v1.20.2 |
| Ephemeral storage metrics | 1.19.2 |
| KAI Scheduler | v0.16.9 |
| NVIDIA DRA driver | 0.5.1 |
| NVSentinel | v1.31.0 |
| Prometheus Adapter | 5.3.0 |

Review Nodewright's node tuning and NVSentinel's remediation settings before
deploying. Customizations target GPU nodes through `nvidia.com/gpu.present=true`.
The existing device plugin continues to advertise GPUs; whole-GPU DRA
advertisement stays disabled. The adapter uses the existing Prometheus service,
and NVSentinel is configured for the preinstalled host driver.

## Generate from a snapshot

Run from the repository root with the intended Kubernetes context selected:

```bash
kubectl config current-context
aicr snapshot --config aicr/config.yaml
aicr recipe --config aicr/config.yaml --service bcm --intent inference --nodes 2
aicr bundle --config aicr/config.yaml
```

The snapshot supplies H200 hardware and OS information. `--nodes 2` specifies
the GPU-node count rather than the total count of three nodes. AICR relaxes the
detected Ubuntu criterion because the built-in BCM inference recipe has no
OS-specific variant.

The committed Applications also include these manual adjustments after generation:

- Prefix the parent Git path, local chart paths, and child Git values paths with `manifests/`.
- Use Helm OCI registry namespaces without `oci://`, with the chart name in `chart`.

After those adjustments, refresh the bundle checksums and verify:

```bash
checksum_file=$(mktemp)
(cd manifests && find . -type f ! -name checksums.txt \
  -exec shasum -a 256 {} \;) > "$checksum_file"
mv "$checksum_file" manifests/checksums.txt
aicr verify ./manifests
```

GPU Operator exclusion uses AICR's supported but deprecated bundle-time toggle.
Keep `aicr/recipe.yaml` as the full platform baseline for validation: the filtered
bundle depends on the externally managed GPU stack and is not a standalone
GPU-allocation recipe. The snapshot preflight checks constraints; live readiness,
conformance, and model serving have not been validated.

## Bootstrap Argo CD

Commit and push `main` first. Argo CD must have access to this repository and
the chart sources. Review any existing child Application health customization
before merging the patch, and retain it in Argo CD's Helm values on upgrades.

```bash
cluster_context=kubernetes-admin@asalleh-h200-k8s
kubectl --context "$cluster_context" -n argocd get configmap argocd-cm -o yaml
kubectl --context "$cluster_context" -n argocd \
  patch configmap argocd-cm --type merge \
  --patch-file bootstrap/argocd-health-patch.yaml
kubectl --context "$cluster_context" apply -f manifests/app-of-apps.yaml
kubectl --context "$cluster_context" -n argocd get applications -w
```

Applying the parent starts automatic sync, pruning, and self-healing for the
eight components. Model serving is a separate deployment after the platform is healthy.
