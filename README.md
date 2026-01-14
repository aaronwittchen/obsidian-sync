# Obsidian LiveSync on Kubernetes

Self-hosted sync for Obsidian using CouchDB, deployed with Kustomize.

## Overview

This deployment provides:
- **CouchDB 3.5** - Database backend for Obsidian LiveSync
- **Persistent Storage** - Data survives pod restarts
- **Gateway API routing** - Access via Istio
- **SOPS encryption** - Secrets encrypted with age

## Connection Details

| Setting | Value |
|---------|-------|
| URI | `http://obsidian.k8s.local` or `http://192.168.68.120` |
| Username | `admin` |
| Password | `changeme` |
| Database | `obsidian` |

**Important:** Use `http://` not `https://`

## Quick Start

### 1. Encrypt your secrets

Edit `base/secrets.yaml` with your credentials, then encrypt:

```bash
cd base
sops -e -i secrets.yaml
```

### 2. Deploy via ArgoCD

The application is deployed via ArgoCD from `overlays/longhorn`.

Or apply manually (requires KSOPS):
```bash
kubectl apply -k overlays/longhorn
```

### 3. Configure CouchDB

#### Option A: Quick setup via curl

```bash
# Configure all settings at once
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/chttpd/require_valid_user -d '"true"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/chttpd_auth/require_valid_user -d '"true"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/httpd/WWW-Authenticate -d '"Basic realm=\"couchdb\""'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/httpd/enable_cors -d '"true"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/chttpd/enable_cors -d '"true"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/chttpd/max_http_request_size -d '"4294967296"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/couchdb/max_document_size -d '"50000000"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/cors/credentials -d '"true"'
curl -X PUT http://admin:changeme@obsidian.k8s.local/_node/_local/_config/cors/origins -d '"app://obsidian.md,capacitor://localhost,http://localhost"'

# Create database
curl -X PUT http://admin:changeme@obsidian.k8s.local/obsidian
```

#### Option B: Manual setup via Web UI

1. Open http://obsidian.k8s.local/_utils
2. Login with `admin` / `changeme`
3. **Setup** (wrench icon) → Configure Single Node → enter credentials → Configure Node
4. **Databases** → Create Database → name: `obsidian` (non-partitioned)
5. **Configuration** → Add each option from the table below

| Section | Name | Value |
|---------|------|-------|
| `chttpd` | `require_valid_user` | `true` |
| `chttpd_auth` | `require_valid_user` | `true` |
| `httpd` | `WWW-Authenticate` | `Basic realm="couchdb"` |
| `httpd` | `enable_cors` | `true` |
| `chttpd` | `enable_cors` | `true` |
| `chttpd` | `max_http_request_size` | `4294967296` |
| `couchdb` | `max_document_size` | `50000000` |
| `cors` | `credentials` | `true` |
| `cors` | `origins` | `app://obsidian.md,capacitor://localhost,http://localhost` |

## Obsidian Client Setup

### Install the plugin

1. Open Obsidian
2. **Settings** → **Community plugins** → **Browse**
3. Search "Self-hosted LiveSync" by vrtmrz
4. **Install** → **Enable**

### Configure the plugin

1. **Settings** → **Self-hosted LiveSync** (in left sidebar)

2. Click the **satellite icon** (4th button) and enter:
   - **Remote Type**: `CouchDB`
   - **URI**: `http://obsidian.k8s.local` or `http://192.168.68.120`
   - **Username**: `admin`
   - **Password**: `changeme`
   - **Database**: `obsidian`

3. Click **Test** → should say "Connected to obsidian successfully"

4. Click **Check** → all items should have checkmarks

5. **(Recommended)** Enable **End-to-end Encryption**:
   - Scroll down to "End-to-end Encryption"
   - Toggle ON
   - Enter a passphrase (use the SAME passphrase on ALL devices!)
   - Click "Just apply"

6. Click the **refresh icon** (5th button):
   - Set **Sync mode**: `LiveSync`

7. Click **Apply Settings**

### First sync on additional devices

On your second/third machine, after configuring the plugin with the same settings:

1. Go to plugin settings
2. Click **Rebuild everything** → **Fetch remote**
3. This pulls all existing notes from the server

### Windows without Pi-hole DNS

If your Windows machine can't resolve `obsidian.k8s.local`:

**Option A: Edit hosts file**
1. Open Notepad as Administrator
2. Edit `C:\Windows\System32\drivers\etc\hosts`
3. Add: `192.168.68.120 obsidian.k8s.local`

**Option B: Use IP directly**
- Set URI to `http://192.168.68.120`

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
│   ├── longhorn/               # Longhorn storage
│   │   └── kustomization.yaml
│   └── local-path/             # Local path storage
│       └── kustomization.yaml
└── .sops.yaml                  # SOPS configuration
```

## DNS Setup

Add to your DNS (e.g., Pi-hole):

```
obsidian.k8s.local -> 192.168.68.120
```

## Secrets Management

Secrets are encrypted using SOPS with age. To edit:

```bash
# Edit encrypted secrets
sops base/secrets.yaml

# Re-encrypt if needed
sops -e -i base/secrets.yaml
```

## Useful Commands

```bash
# Check deployment status
kubectl get pods -n obsidian-livesync

# View logs
kubectl logs -n obsidian-livesync deployment/couchdb

# Port-forward for local access
kubectl port-forward -n obsidian-livesync svc/couchdb 5984:5984

# Check ArgoCD app status
kubectl get application obsidian-sync -n argocd
```

## Troubleshooting

### "Could not connect" error
- Make sure you're using `http://` not `https://`
- Verify the URI is correct and reachable

### Certificate errors
- Use `http://` instead of `https://`
- CouchDB runs on plain HTTP

### Notes not syncing
- Check credentials match on all devices
- Verify encryption passphrase is identical on all devices
- Click "Rebuild everything" → "Fetch remote" to force sync

### Pod pending / PVC issues
- Check storage class exists: `kubectl get storageclass`
- Delete PVCs and let ArgoCD recreate: `kubectl delete pvc -n obsidian-livesync --all`
