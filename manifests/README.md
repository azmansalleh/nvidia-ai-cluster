# Argo CD Deployment Bundle

Bundler Version: 1.3.0
Recipe Version: 1.3.0

## Overview

This bundle contains Argo CD Application manifests for deploying NVIDIA AI Cluster Runtime components using the App of Apps pattern.

## Components

The following components are included in deployment order:

| Component | Type | Version | Sync Wave | Namespace |
|-----------|------|---------|-----------|-----------|
| nodewright-operator | Helm | v0.21.0 | 1 | nodewright |
| nodewright-customizations | Local chart | - | 5 | nodewright |
| cert-manager | Helm | 1.20.2 | 1 | cert-manager |
| k8s-ephemeral-storage-metrics | Helm | 1.19.2 | 1 | monitoring |
| kai-scheduler | Helm | v0.16.9 | 1 | kai-scheduler |
| nvidia-dra-driver-gpu | Helm | 0.5.1 | 1 | nvidia-dra-driver |
| nvsentinel | Helm | v1.31.0 | 5 | nvsentinel |
| prometheus-adapter | Helm | 5.3.0 | 1 | monitoring |
| grove | Helm | v0.1.0-alpha.13 | 1 | dynamo-system |
| dynamo-platform | Helm | 1.4.2 | 5 | dynamo-system |
| workload-map | Helm | 0.3.0 | 1 | karta-system |

## Before You Upgrade

Upgrading an existing installation? The components below need action before
this bundle is applied over them. [UPGRADING.md](UPGRADING.md) has the steps
for the `argocd` deployer. A fresh install can skip this.

| Component | Verdict | Applies when upgrading from |
|-----------|---------|-----------------------------|
| nodewright-operator | manual | `<0.18.0` |
| nvsentinel | manual | `>=1.28.0 <1.31.0` |
| grove | manual | `>=0.1.0-alpha.12 <0.1.0-alpha.13` |

## Prerequisites

- Kubernetes cluster with Argo CD installed
- Argo CD CLI (`argocd`) configured
- Git repository for storing these manifests
- kubectl configured with cluster access

## Deployment Steps

### 1. Prepare Git Repository

Push this bundle to your GitOps repository:

```bash
cd <bundle-directory>
git init
git add .
git commit -m "Add NVIDIA AI Cluster Runtime manifests"
git remote add origin YOUR_REPO_URL
git push -u origin main
```

### 2. Update Repository URL

`repoURL` is baked into both `app-of-apps.yaml` *and* every per-component
`NNN-<component>/application.yaml` (path-based child Applications inherit
the bundle's repo URL — Argo CD does not propagate the parent's `repoURL`
to children). Update all of them in one pass:

```bash
# Update repoURL across the parent and every per-component application.yaml
find . -name 'application.yaml' -o -name 'app-of-apps.yaml' \
  | xargs sed -i 's|https://github.com/YOUR-ORG/YOUR-REPO.git|YOUR_ACTUAL_REPO_URL|g'
```

To avoid the rewrite, regenerate the bundle with `--repo` so the URL is
populated at bundle time:

```bash
aicr bundle --deployer argocd --repo YOUR_ACTUAL_REPO_URL ...
```

### 3. Apply App of Apps

```bash
kubectl apply -f app-of-apps.yaml
```

### 4. Monitor Deployment

```bash
# Watch application sync status
argocd app list

# Get detailed status for a specific application
argocd app get cluster

# Watch sync progress
argocd app sync cluster --watch
```

## Directory Structure

Each `NNN-<component>/` folder is one of two kinds, distinguished by the
presence of `Chart.yaml`. KindUpstreamHelm folders (no `Chart.yaml`) carry
just `values.yaml` + `application.yaml` — the Application is multi-source
(upstream Helm repo + your git repo for values). KindLocalHelm folders
(`Chart.yaml` + `templates/`) carry the wrapped chart bytes plus a
path-based single-source `application.yaml`.

```text
<bundle-directory>/
├── app-of-apps.yaml           # Parent application
├── README.md                  # This file
├── 001-nodewright-operator/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 002-nodewright-customizations/
│   ├── Chart.yaml             # Wrapped local chart
│   ├── templates/             # Rendered manifests
│   ├── values.yaml            # Static values
│   └── application.yaml       # Path-based Application (sync-wave: 5)
├── 003-cert-manager/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 004-k8s-ephemeral-storage-metrics/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 005-kai-scheduler/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 006-nvidia-dra-driver-gpu/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 007-nvsentinel/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 5)
├── 008-prometheus-adapter/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 009-grove/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
├── 010-dynamo-platform/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 5)
├── 011-workload-map/
│   ├── values.yaml            # Static values (multi-source helm.valueFiles)
│   └── application.yaml       # Multi-source Application (sync-wave: 1)
```

`--dynamic` is not supported with `--deployer argocd` — use `--deployer
argocd-helm` for install-time values. The helm-deployer files
(`install.sh`, `upstream.env`, `cluster-values.yaml`) are intentionally
omitted; Argo's repo-server never consumes them.

## Sync Waves

Components are deployed in order using Argo CD sync-waves:
- **Wave 1**: nodewright-operator
- **Wave 5**: nodewright-customizations
- **Wave 1**: cert-manager
- **Wave 1**: k8s-ephemeral-storage-metrics
- **Wave 1**: kai-scheduler
- **Wave 1**: nvidia-dra-driver-gpu
- **Wave 5**: nvsentinel
- **Wave 1**: prometheus-adapter
- **Wave 1**: grove
- **Wave 5**: dynamo-platform
- **Wave 1**: workload-map

## Customization

### Modifying Values

Edit the `values.yaml` file in each Helm component directory to customize the deployment.

### Changing Deployment Order

Modify the `sync-wave` annotation in each `application.yaml` to change deployment order.

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get <app-name>

# Force sync
argocd app sync <app-name> --force

# View application logs
argocd app logs <app-name>
```

### Resource Conflicts

If resources already exist, you may need to adopt them:

```bash
argocd app sync <app-name> --replace
```

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
