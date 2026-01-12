# Obsidian LiveSync Kubernetes Deployment

This directory contains the Kubernetes configuration for deploying CouchDB with encrypted storage for Obsidian LiveSync.

## Quick Start

1. **Set up credentials:**
   ```bash
   cd obsidian-livesync-k8s
   ./setup-credentials.sh
   ```
   This script will:
   - Prompt for CouchDB username, password, database name, and encryption passphrase
   - Generate a secure encryption key for Longhorn volumes
   - Update the YAML file with your credentials

2. **Deploy to Kubernetes:**
   ```bash
   kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
   ```

3. **Verify deployment:**
   ```bash
   kubectl get pods -n obsidian-livesync
   kubectl get pvc -n obsidian-livesync
   ```

## Storage Class: Longhorn (Recommended)

✅ **Use Longhorn** for production deployments:
- Supports encryption at rest
- Better data protection with replication
- Production-ready and stable
- Volume expansion support

❌ **local-path** is NOT recommended:
- No encryption support
- Local storage only
- Good only for testing/dev

## Encryption

This setup includes **two layers of encryption**:

1. **Kubernetes Secret Encryption at Rest** (if enabled at cluster level)
   - Encrypts Secrets stored in etcd
   - See `ENCRYPTION_SETUP.md` for cluster-level configuration

2. **Longhorn Volume Encryption**
   - Encrypts CouchDB data volumes at rest using `dm_crypt`
   - Configured in this YAML file
   - Uses a Kubernetes Secret to store the encryption key

3. **Obsidian LiveSync End-to-End Encryption**
   - Encrypts data in transit and at rest in CouchDB
   - Configured in Obsidian plugin settings

## Files

- `obsidian-livesync.yaml` - Main Kubernetes configuration
- `setup-credentials.sh` - Helper script for credential setup
- `ENCRYPTION_SETUP.md` - Detailed encryption documentation
- `README.md` - This file

## Prerequisites

- Kubernetes cluster (kubeadm, k3s, etc.)
- Longhorn storage provisioner installed
- `dm_crypt` kernel module available
- `cryptsetup` utility installed

## Troubleshooting

See `ENCRYPTION_SETUP.md` for encryption-specific troubleshooting.

For general deployment issues, check:
```bash
kubectl describe pod -n obsidian-livesync
kubectl logs -n obsidian-livesync deployment/couchdb
kubectl get pvc -n obsidian-livesync
```

