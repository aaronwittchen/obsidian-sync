# Obsidian LiveSync on Kubernetes

Self-hosted sync for Obsidian using CouchDB, deployed with Kustomize.

## Overview

This deployment provides:
- **CouchDB 3.5** - Database backend for Obsidian LiveSync
- **Persistent Storage** - Data survives pod restarts
- **Gateway API routing** - HTTPS access via Istio
- **SOPS encryption** - Secrets encrypted with age

## Quick Start

### 1. Encrypt your secrets

Edit `base/secrets.yaml` with your credentials, then encrypt:

```bash
cd base
sops -e -i secrets.yaml
```

### 2. Deploy with Longhorn storage (recommended)

```bash
kubectl apply -k overlays/longhorn
```

Or with local-path storage:

```bash
kubectl apply -k overlays/local-path
```

### 3. Configure CouchDB

Port-forward to access the CouchDB admin interface:

```bash
kubectl port-forward -n obsidian-livesync svc/couchdb 5984:5984
```

Then open http://localhost:5984/_utils and:

1. Login with your credentials
2. Click Setup > Configure Single Node
3. Create a database (e.g., `obsidian`)
4. Add the required CouchDB configuration (see Configuration section)

### 4. Connect Obsidian

1. Install the "Self-hosted LiveSync" plugin in Obsidian
2. Configure with:
   - URI: `https://obsidian.k8s.local` (or your configured hostname)
   - Username/Password: Your CouchDB credentials
   - Database: The database you created

## Structure

```
obsidian-sync/
├── base/
│   ├── kustomization.yaml      # Base kustomization
│   ├── namespace.yaml          # obsidian-livesync namespace
│   ├── service-accounts.yaml   # ServiceAccount for couchdb
│   ├── pvcs.yaml               # PersistentVolumeClaims
│   ├── deployment.yaml         # CouchDB Deployment + Service
│   ├── httproute.yaml          # Gateway API HTTPRoute
│   ├── secrets.yaml            # SOPS-encrypted credentials
│   └── secret-generator.yaml   # KSOPS generator
├── overlays/
│   ├── longhorn/               # Longhorn encrypted storage
│   │   └── kustomization.yaml
│   └── local-path/             # Local path storage
│       └── kustomization.yaml
└── .sops.yaml                  # SOPS configuration
```

## CouchDB Configuration

After deployment, add these settings in CouchDB Configuration:

| Section       | Name                    | Value                                                      |
|---------------|-------------------------|-----------------------------------------------------------|
| `chttpd`      | `require_valid_user`    | `true`                                                    |
| `chttpd_auth` | `require_valid_user`    | `true`                                                    |
| `httpd`       | `WWW-Authenticate`      | `Basic realm="couchdb"`                                   |
| `httpd`       | `enable_cors`           | `true`                                                    |
| `chttpd`      | `enable_cors`           | `true`                                                    |
| `chttpd`      | `max_http_request_size` | `4294967296`                                              |
| `couchdb`     | `max_document_size`     | `50000000`                                                |
| `cors`        | `credentials`           | `true`                                                    |
| `cors`        | `origins`               | `app://obsidian.md,capacitor://localhost,http://localhost`|

## Secrets Management

Secrets are encrypted using SOPS with age. To edit:

```bash
# Edit encrypted secrets
sops base/secrets.yaml

# Re-encrypt if needed
sops -e -i base/secrets.yaml
```

## DNS Setup

Add to your DNS (e.g., Pi-hole):

```
obsidian.k8s.local -> <cluster-ip>
```

## Useful Commands

```bash
# Check deployment status
kubectl get pods -n obsidian-livesync

# View logs
kubectl logs -n obsidian-livesync deployment/couchdb

# Port-forward for local access
kubectl port-forward -n obsidian-livesync svc/couchdb 5984:5984

# Delete deployment
kubectl delete -k overlays/longhorn
```
