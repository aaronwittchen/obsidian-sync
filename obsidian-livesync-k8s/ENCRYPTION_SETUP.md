# Encryption Setup Guide

This guide explains the two types of encryption used in this setup:

## 1. Kubernetes Secret Encryption at Rest (Cluster-Level)

**What it encrypts:** Secrets stored in etcd (the Kubernetes database)

**Status:** This must be configured at the **cluster level** during or after cluster setup.

### How to Enable Secret Encryption at Rest

If your cluster doesn't already have Secret encryption enabled, you need to configure it in the kube-apiserver:

1. **Create an encryption configuration file** (`/etc/kubernetes/encryption-config.yaml`):

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <BASE64_ENCODED_32_BYTE_KEY>
      - identity: {}  # Fallback for unencrypted secrets
```

2. **Generate encryption key:**
```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY
```

3. **Update kube-apiserver manifest** (`/etc/kubernetes/manifests/kube-apiserver.yaml`):
   - Add: `--encryption-provider-config=/etc/kubernetes/encryption-config.yaml`
   - Mount the config file as a volume

4. **Restart kube-apiserver** (it will restart automatically)

5. **Verify encryption is working:**
```bash
kubectl get secrets -A -o json | jq '.items[0].data'
```

**Note:** This is a cluster-wide setting and affects ALL secrets. If your cluster already has this enabled, you're good to go!

## 2. Longhorn Volume Encryption (Application-Level)

**What it encrypts:** The actual CouchDB data volumes (PVCs)

**Status:** Configured in this YAML file ✅

### How It Works

- Uses Linux `dm_crypt` to encrypt volumes at the block level
- Encryption key is stored in a Kubernetes Secret
- All data written to the volume is automatically encrypted
- Backups remain encrypted

### Prerequisites

Ensure your nodes have:
- `dm_crypt` kernel module loaded
- `cryptsetup` utility installed

Check with:
```bash
lsmod | grep dm_crypt
which cryptsetup
```

### Setup Steps

1. **Generate encryption key:**
```bash
# Generate a secure 32-byte key
openssl rand -base64 32
```

2. **Update the Secret in `obsidian-livesync.yaml`:**
   - Replace `CRYPTO_KEY_VALUE` with your generated key
   - The key should be a plain string (not base64 encoded again)

3. **Deploy the configuration:**
```bash
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
```

### Verification

After deployment, verify encryption is active:

```bash
# Check StorageClass was created
kubectl get storageclass longhorn-encrypted

# Check PVCs are using encrypted storage
kubectl get pvc -n obsidian-livesync

# Check Longhorn volumes are encrypted (if Longhorn UI is available)
# Look for "Encrypted: true" in volume details
```

## Storage Class Comparison

### local-path
- ✅ Simple, lightweight
- ✅ Good for testing/dev
- ❌ No encryption support
- ❌ No replication
- ❌ Local storage only

### longhorn (Recommended for Production)
- ✅ Volume encryption support
- ✅ Replication and snapshots
- ✅ Production-ready
- ✅ Better data protection
- ✅ Can expand volumes
- ⚠️ Requires more resources

**Recommendation:** Use **Longhorn** for production deployments, especially when encryption is required.

## Security Layers

Your CouchDB setup has **multiple layers of encryption**:

1. **Kubernetes Secret Encryption** (if enabled): Protects credentials in etcd
2. **Longhorn Volume Encryption**: Protects data at rest on disk
3. **Obsidian LiveSync End-to-End Encryption**: Protects data in transit and at rest in CouchDB

This provides defense in depth for your sensitive notes!

