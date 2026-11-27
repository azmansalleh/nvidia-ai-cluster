# nv-ai-cluster

Snapshot-based H200/BCM inference infrastructure using AICR 1.3.0 and Argo CD.
Uses the built-in recipe and Dynamo component definitions, tailored for this
existing cluster without a custom catalog.

## Folders

| Path | Purpose |
|---|---|
| `aicr/config.yaml` | Snapshot settings, existing-component exclusions, and Argo CD bundle options. |
| `aicr/snapshot.yaml` | Local cluster snapshot; ignored by Git. |
| `aicr/recipe.yaml` | Cluster recipe used for bundle generation and validation. |
| `bootstrap/` | Argo CD child Application health configuration. |
| `manifests/` | Generated bundle for the additional components; includes the filtered recipe and checksums. |
| `manifests/NNN-*/` | Child Applications, Helm values, and any local chart templates. |

No `--data` directory is used, so there is no `manifests/data/` copy.

## Components

The recipe contains 16 standard infrastructure references plus Grove and Dynamo. Excluded components
use `overrides.enabled: false`, so AICR skips their deployment and health checks.
The existing NFD, gateways, and Prometheus stack remain separately managed;
NKTP and the optional DRA eviction labeler are also disabled. GPU Operator stays
enabled in the recipe for validation, while the bundle settings exclude its
deployment because it is already managed separately.

The ten components in this bundle are:

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
| Grove | v0.1.0-alpha.13 |
| Dynamo Platform | 1.4.2 |

Review Nodewright's node tuning and NVSentinel's remediation settings before
deploying. Customizations target GPU nodes through `nvidia.com/gpu.present=true`.
The existing device plugin continues to advertise GPUs; whole-GPU DRA
advertisement stays disabled. The adapter uses the existing Prometheus service,
and NVSentinel and DRA are configured for the preinstalled host driver.
Dynamo uses the same Prometheus service on port 9090. Grove and Dynamo deploy
to `dynamo-system`, using the separately managed KAI Scheduler and Grove
controllers rather than installing duplicate subcharts.

## Generate from a snapshot

Run from the repository root with the intended Kubernetes context selected
and `yq` v4 installed:

```bash
kubectl config current-context
aicr snapshot --config aicr/config.yaml
aicr recipe --config aicr/config.yaml --service bcm --intent inference --nodes 2
yq -i '
  ["agentgateway", "agentgateway-crds", "dra-node-labeler",
   "kube-prometheus-stack", "nfd", "nktp", "prometheus-operator-crds"] as $excluded |
  (.componentRefs[] | select(.name as $name | $excluded | contains([$name])))
    .overrides.enabled = false
' aicr/recipe.yaml
dynamo_source=$(mktemp)
aicr recipe --service eks --accelerator h100 --os ubuntu \
  --intent inference --platform dynamo --nodes 2 --output "$dynamo_source"
DYNAMO_SOURCE="$dynamo_source" yq -i '
  .componentRefs += [load(strenv(DYNAMO_SOURCE)).componentRefs[] |
    select(.name == "grove" or .name == "dynamo-platform")] |
  .deploymentOrder += ["grove", "dynamo-platform"] |
  .criteria.platform = "dynamo"
' aicr/recipe.yaml
rm "$dynamo_source"
aicr bundle --config aicr/config.yaml
```

The snapshot supplies H200 hardware and OS information. `--nodes 2` specifies
the GPU-node count rather than the total count of three nodes. AICR relaxes the
detected Ubuntu criterion because the built-in BCM inference recipe has no
OS-specific variant.

AICR 1.3.0 has no H200/BCM/Dynamo leaf. The temporary source above supplies
only the two generic Grove/Dynamo component definitions from a supported leaf;
no EKS settings, H100 constraints, or benchmark thresholds are copied. The
maintained recipe remains `aicr/recipe.yaml`. This composition does not carry
AICR's validated H200/BCM/Dynamo matrix evidence.

The committed Applications also include these manual adjustments after generation:

- Prefix the parent Git path, local chart paths, and child Git values paths with `manifests/`.
- Use Helm OCI registry namespaces without `oci://`, with the chart name in `chart`.
- On Grove's Application, preserve controller-generated certificate data and
  webhook CA bundles using the rules below. Without these rules, self-healing
  reapplies the chart's empty certificate fields and causes repeated restarts.

```bash
yq -i '
  .spec.ignoreDifferences = [
    {"group": "", "kind": "Secret", "name": "grove-webhook-server-cert",
     "namespace": "dynamo-system", "jsonPointers": ["/data"]},
    {"group": "admissionregistration.k8s.io", "kind": "MutatingWebhookConfiguration",
     "name": "podcliqueset-defaulting-webhook",
     "jqPathExpressions": [".webhooks[]?.clientConfig.caBundle"]},
    {"group": "admissionregistration.k8s.io", "kind": "ValidatingWebhookConfiguration",
     "name": "clustertopology-validating-webhook",
     "jqPathExpressions": [".webhooks[]?.clientConfig.caBundle"]},
    {"group": "admissionregistration.k8s.io", "kind": "ValidatingWebhookConfiguration",
     "name": "podcliqueset-validating-webhook",
     "jqPathExpressions": [".webhooks[]?.clientConfig.caBundle"]}
  ] |
  .spec.syncPolicy.syncOptions =
    ((.spec.syncPolicy.syncOptions + ["RespectIgnoreDifferences=true"]) | unique)
' manifests/009-grove/application.yaml
```

After those adjustments, refresh the bundle checksums and verify:

```bash
checksum_file=$(mktemp)
(cd manifests && find . -type f ! -name checksums.txt \
  -exec shasum -a 256 {} \;) > "$checksum_file"
mv "$checksum_file" manifests/checksums.txt
aicr verify ./manifests
```

GPU Operator exclusion uses AICR's supported but deprecated bundle-time toggle.
Keep it enabled in `aicr/recipe.yaml` so validation can identify the existing
device plugin as the GPU allocator. `manifests/recipe.yaml` is an automatically
generated bundle inventory; use `aicr/recipe.yaml` for validation.

## Validate the deployed components

Once all Argo CD applications have finished syncing, refresh the snapshot and
run live deployment checks:

```bash
aicr snapshot --config aicr/config.yaml
aicr validate \
  --recipe aicr/recipe.yaml \
  --snapshot aicr/snapshot.yaml \
  --phase deployment \
  --fail-on-error \
  --output /tmp/aicr-deployment-report.json
```

The deployment phase checks operator health, expected resources (including
Grove and Dynamo), GPU Operator version, and `nvidia-smi` on both GPU nodes.
It does not check the separately managed NFD, gateways, or Prometheus
installation. Conformance and model serving have not been validated.

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
ten components. Model serving is a separate deployment after the platform is healthy.
