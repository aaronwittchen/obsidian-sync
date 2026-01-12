# Fixing Longhorn Encryption Setup

## Current Issue

The StorageClass `longhorn-encrypted` was created with incorrect parameters, and Kubernetes doesn't allow updating StorageClass parameters. The PVCs were also created before the encryption secret was properly configured.

## Solution Steps

**1. Delete the existing StorageClass:**
```bash
kubectl delete storageclass longhorn-encrypted
```

**2. Delete the existing PVCs (they'll be recreated with proper encryption):**
```bash
kubectl delete pvc couchdb-data couchdb-config -n obsidian-livesync
```

**3. Delete the deployment (it will be recreated):**
```bash
kubectl delete deployment couchdb -n obsidian-livesync
```

**4. Wait for PVCs to be fully deleted:**
```bash
kubectl get pvc -n obsidian-livesync
# Wait until both PVCs are gone
```

**5. Verify the encryption secret exists in longhorn-system:**
```bash
kubectl get secret couchdb-encryption-key -n longhorn-system
```

If it doesn't exist or has wrong value, create/update it:
```bash
ENCRYPTION_KEY="pQYLet07/Ob/q5eLZlDZJQmddBrTyGpzzizIlAOggys="  # Your key from setup-credentials.sh

kubectl create secret generic couchdb-encryption-key \
  --from-literal=CRYPTO_KEY_VALUE="$ENCRYPTION_KEY" \
  --from-literal=CRYPTO_KEY_PROVIDER="secret" \
  --from-literal=CRYPTO_KEY_CIPHER="aes-xts-plain64" \
  --from-literal=CRYPTO_KEY_HASH="sha256" \
  --from-literal=CRYPTO_KEY_SIZE="256" \
  --from-literal=CRYPTO_PBKDF="argon2i" \
  -n longhorn-system \
  --dry-run=client -o yaml | kubectl apply -f -
```

**6. Create the StorageClass with correct encryption parameters:**
```bash
kubectl apply -f longhorn-encryption.yaml
```

**7. Apply the main configuration (this will recreate PVCs and deployment):**
```bash
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
```

**8. Wait for PVCs to bind:**
```bash
kubectl wait --for=condition=Bound pvc/couchdb-data pvc/couchdb-config -n obsidian-livesync --timeout=120s
```

**9. Check pod status:**
```bash
kubectl get pods -n obsidian-livesync
kubectl describe pod -n obsidian-livesync -l app=couchdb
```

## Quick Fix (All Steps Combined)

```bash
# 1. Delete existing resources
kubectl delete storageclass longhorn-encrypted --ignore-not-found=true
kubectl delete deployment couchdb -n obsidian-livesync --ignore-not-found=true
kubectl delete pvc couchdb-data couchdb-config -n obsidian-livesync --ignore-not-found=true

# 2. Wait a moment for cleanup
sleep 5

# 3. Verify/update encryption secret (use your actual key)
ENCRYPTION_KEY="pQYLet07/Ob/q5eLZlDZJQmddBrTyGpzzizIlAOggys="
kubectl create secret generic couchdb-encryption-key \
  --from-literal=CRYPTO_KEY_VALUE="$ENCRYPTION_KEY" \
  --from-literal=CRYPTO_KEY_PROVIDER="secret" \
  --from-literal=CRYPTO_KEY_CIPHER="aes-xts-plain64" \
  --from-literal=CRYPTO_KEY_HASH="sha256" \
  --from-literal=CRYPTO_KEY_SIZE="256" \
  --from-literal=CRYPTO_PBKDF="argon2i" \
  -n longhorn-system \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Create StorageClass
kubectl apply -f longhorn-encryption.yaml

# 5. Apply main config
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync

# 6. Wait for PVCs
kubectl wait --for=condition=Bound pvc/couchdb-data pvc/couchdb-config -n obsidian-livesync --timeout=120s

# 7. Check status
kubectl get pods -n obsidian-livesync
```

## Verification

After completing the steps, verify encryption is working:

```bash
# Check StorageClass
kubectl get storageclass longhorn-encrypted -o yaml | grep encrypted

# Check PVCs are bound
kubectl get pvc -n obsidian-livesync

# Check pod is running
kubectl get pods -n obsidian-livesync

# Check pod logs for errors
kubectl logs -n obsidian-livesync deployment/couchdb
```

If you see "missing passphrase for encrypted volume" errors, the secret might not be accessible. Check:
```bash
kubectl get secret couchdb-encryption-key -n longhorn-system -o yaml
```

