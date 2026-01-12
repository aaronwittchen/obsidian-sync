kubeadm

  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```
[onion@archlinux ~]$   kubectl cluster-info
  kubectl get nodes
Kubernetes control plane is running at https://192.168.2.207:6443
CoreDNS is running at https://192.168.2.207:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
NAME        STATUS   ROLES           AGE     VERSION
archlinux   Ready    control-plane   4d15h   v1.34.2

  ```bash
  kubectl get storageclass
  ```
[onion@archlinux ~]$   kubectl get storageclass
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  23h
longhorn               driver.longhorn.io      Delete          Immediate              true                   4d14h
longhorn-static        driver.longhorn.io      Delete          Immediate              true                   44m
[onion@archlinux ~]$




- [] **Choose your credentials** (write these down securely!)

  - [ ] CouchDB Username: `_________________`
  - [ ] CouchDB Password: `_________________`
  - [ ] Database Name: `_________________`
  - [ ] Encryption Passphrase: `_________________`

- [] **Download/create the YAML file**

  - [ ] Save the `obsidian-livesync.yaml` file to `~/obsidian-livesync-k8s/`

- [] **Edit the YAML file with your credentials**
  ```bash
  nano obsidian-livesync.yaml
  ```
  - [ ] Replace `eW91cl91c2VybmFtZQ==` with your base64-encoded username
    - Generate: `echo -n 'your_username' | base64`
  - [ ] Replace `eW91cl9wYXNzd29yZA==` with your base64-encoded password
    - Generate: `echo -n 'your_password' | base64`
  - [ ] Replace `REPLACE_WITH_SECURE_ENCRYPTION_KEY` in the `couchdb-encryption-key` Secret
    - Generate: `openssl rand -base64 32`
    - This key encrypts your CouchDB volumes at rest
  - [ ] Storage class is already set to `longhorn-encrypted` (encrypted Longhorn volumes)
  - [ ] Save and exit (Ctrl+X, Y, Enter)

- [] **Verify encryption prerequisites** (for Longhorn volume encryption)
  ```bash
  # Check dm_crypt kernel module is available
  lsmod | grep dm_crypt
  
  # Check cryptsetup is installed
  which cryptsetup
  ```
  - Expected: `dm_crypt` module loaded, `cryptsetup` command found
  - If missing, install: `sudo pacman -S cryptsetup` (on Arch Linux)

- [] **Storage Class Choice:**
  - ✅ **Use Longhorn** (recommended for production)
    - Supports encryption at rest
    - Better data protection with replication
    - Production-ready
  - ❌ **local-path** is NOT recommended
    - No encryption support
    - Local storage only
    - Good only for testing/dev

Deploy CouchDB to Kubernetes

- [ ] **Create the namespace**

  ```bash
  kubectl create namespace obsidian-livesync
  ```

- [ ] **Apply the YAML configuration**

  ```bash
  kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
  ```

- [ ] **Wait for pod to be ready** (may take 1-2 minutes)

  ```bash
  watch kubectl get pods -n obsidian-livesync
  ```

  - Expected: `couchdb-XXXXX` shows `1/1` under READY and `Running` under STATUS
  - Press Ctrl+C to exit watch

- [ ] **Verify all resources are created**

  ```bash
  # Check pods
  kubectl get pods -n obsidian-livesync

  # Check service
  kubectl get services -n obsidian-livesync

  # Check persistent volumes
  kubectl get pvc -n obsidian-livesync
  ```

  - Expected: All show as running/bound

- [ ] **Check pod logs for any errors**
  ```bash
  kubectl logs -n obsidian-livesync deployment/couchdb
  ```
  - Expected: No major errors, should see CouchDB startup messages

chmod +x setup-credentials.sh
Run ./setup-credentials.sh to set your credentials

==========================================
CouchDB Credentials Setup Helper
==========================================

Please enter your CouchDB credentials:

CouchDB Username: admin
CouchDB Password:
Database Name (e.g., obsidiandb): obsidiandb
Encryption Passphrase (for Obsidian LiveSync):

==========================================
Generated Values (save these securely!):
==========================================

CouchDB Username: admin
CouchDB Password: [HIDDEN]
Database Name: obsidiandb
Encryption Passphrase: [HIDDEN]

Base64 Encoded Username: YWRtaW4=
Base64 Encoded Password: YWRtaW4=
Volume Encryption Key: pQYLet07/Ob/q5eLZlDZJQmddBrTyGpzzizIlAOggys=
  (This will be stored in stringData, so no base64 encoding needed)

Updating obsidian-livesync.yaml with your credentials...

Backup created: obsidian-livesync.yaml.backup
✅ Credentials updated in obsidian-livesync.yaml

==========================================
Next Steps:
==========================================
1. Review the updated obsidian-livesync.yaml file
2. Save your credentials securely (password manager recommended)
3. Deploy to Kubernetes:
   kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync

Your credentials have been saved to:
  - Username: admin
  - Database: obsidiandb
  - Encryption passphrase: [saved]

⚠️  IMPORTANT: Keep your encryption passphrase safe!
   You'll need it on ALL devices using Obsidian LiveSync.



# Extract the key that the script generated and printed
ENCRYPTION_KEY="pQYLet07/Ob/q5eLZlDZJQmddBrTyGpzzizIlAOggys="

# Create the secret directly in the correct namespace
kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -

kubectl -n longhorn-system create secret generic couchdb-encryption-key \
  --from-literal=CRYPTO_KEY_VALUE="$ENCRYPTION_KEY" \
  --from-literal=CRYPTO_KEY_PROVIDER="secret" \
  --from-literal=CRYPTO_KEY_CIPHER="aes-xts-plain64" \
  --from-literal=CRYPTO_KEY_HASH="sha256" \
  --from-literal=CRYPTO_KEY_SIZE="256" \
  --from-literal=CRYPTO_PBKDF="argon2i" \
  --dry-run=client -o yaml | kubectl apply -f -




Verify prerequisites: lsmod | grep dm_crypt and which cryptsetup
Deploy: kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync


# 1. Delete the StorageClass (can't update parameters, must recreate)
kubectl delete storageclass longhorn-encrypted

# 2. Delete the deployment and PVCs (will be recreated with proper encryption)
kubectl delete deployment couchdb -n obsidian-livesync
kubectl delete pvc couchdb-data couchdb-config -n obsidian-livesync

# 3. Wait for cleanup
sleep 5

# 4. Recreate StorageClass (skip the Secret part since you already created it)
kubectl apply -f longhorn-encryption.yaml

# 5. Recreate everything else
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync

# 6. Wait for PVCs to bind
kubectl wait --for=condition=Bound pvc/couchdb-data pvc/couchdb-config -n obsidian-livesync --timeout=120s

# 7. Check status
kubectl get pods -n obsidian-livesync


# CouchDB Deployment Issue & Fix

## The Problem

CouchDB pod was stuck in `0/1 Running` state (not ready) with readiness probe failures.

**Root causes (in order encountered):**

1. **HTTP probe timeout via Calico overlay network** - The kubelet couldn't reach the pod's Calico IP (`192.168.x.x`) from outside due to networking misconfiguration
2. **Missing CNI (Container Network Interface)** - Your cluster had no CNI installed at all, so pod-to-pod communication was impossible
3. **Flannel CIDR mismatch** - Flannel was configured with `10.244.0.0/16` but your cluster used `192.168.0.0/24`

## The Fix

**Step 1:** Changed readiness/liveness probes from `httpGet` to `exec` using localhost
```yaml
readinessProbe:
  exec:
    command:
      - /bin/sh
      - -c
      - curl -f http://127.0.0.1:5984/_up
```
This bypassed the Calico overlay network issue temporarily.

**Step 2:** Installed Flannel CNI
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

**Step 3:** Fixed Flannel's network CIDR to match your cluster
```bash
kubectl get configmap kube-flannel-cfg -n kube-flannel -o yaml | \
  sed 's/"Network": "10.244.0.0\/16"/"Network": "192.168.0.0\/16"/' | \
  kubectl apply -f -

kubectl rollout restart daemonset/kube-flannel-ds -n kube-flannel
```

## Result

✅ Pod now `1/1 Ready`  
✅ CouchDB responding to health checks  
✅ Database created and syncing ready


### Step 4: Access CouchDB Web Interface

- [ ] **Set up port forwarding**

  ```bash
  kubectl port-forward service/couchdb-service 5984:5984 -n obsidian-livesync
  ```

  - Keep this terminal window open
  - Note: You'll need to run this each time you want to access CouchDB

- [ ] **Open CouchDB web interface**

  - [ ] Open browser and go to: `http://localhost:5984/_utils`
  - Expected: CouchDB Fauxton interface loads

- [ ] **Login to CouchDB**
  - [ ] Click "Login" in top right
  - [ ] Enter your username and password
  - Expected: Successfully logged in, see your username in top right


make sure user is admin
### Step 5: Configure CouchDB (Initial Setup)

- [ ] **Expand the left sidebar**

  - [ ] Click the `<->` icon on top left to show full menu

- [ ] **Configure as Single Node**

  - [ ] Click "Setup" in left menu
  - [ ] Click "Configure a Single Node"
  - [ ] Enter admin credentials in "Specify your Admin credentials":
    - Username: (your username)
    - Password: (your password)
  - [ ] Leave "Bind address" as `0.0.0.0`
  - [ ] Leave "Port" as `5984`
  - [ ] Click "Configure Node"
  - Expected: Success message appears

- [ ] **Verify Installation**
  - [ ] Click "Verify" in left menu
  - [ ] Click "Verify Installation" button
  - Expected: Green banner saying "Success! Your CouchDB installation is working. Time to Relax."
  - Expected: 6 green checkmarks in the table

### Step 6: Create Database

- [ ] **Create the database**
  - [ ] Click "Databases" in left menu
  - [ ] Click "Create Database" (top right)
  - [ ] Enter database name: (your chosen database name like obsidiandb)
  - [ ] Select "Non-partitioned - recommended for most workloads"
  - [ ] Click "Create"
  - Expected: Redirected to new database page


kubectl port-forward -n obsidian-livesync svc/couchdb-service 5984:5984 &
sleep 2
curl -u admin:admin http://localhost:5984/

[onion@archlinux obsidian-livesync-k8s]$ kubectl port-forward -n obsidian-livesync svc/couchdb-service 5984:5984 &
sleep 2
curl -u admin:admin http://localhost:5984/
[1] 1955636
Forwarding from 127.0.0.1:5984 -> 5984
Forwarding from [::1]:5984 -> 5984
Handling connection for 5984
{"couchdb":"Welcome","version":"3.5.1","git_sha":"44f6a43d8","uuid":"6cff20e1836d287110f198f8b39e7d6c","features":["access-ready","partitioned","pluggable-storage-engines","reshard","scheduler"],"vendor":{"name":"The Apache Software Foundation"}}
[onion@archlinux obsidian-livesync-k8s]$

curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/chttpd/require_valid_user -d '"true"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/chttpd_auth/require_valid_user -d '"true"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/httpd/WWW-Authenticate -d '"Basic realm=\"couchdb\""'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/httpd/enable_cors -d '"true"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/chttpd/enable_cors -d '"true"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/chttpd/max_http_request_size -d '"4294967296"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/couchdb/max_document_size -d '"50000000"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/cors/credentials -d '"true"'
curl -X PUT http://admin:admin@localhost:5984/_node/nonode@nohost/_config/cors/origins -d '"app://obsidian.md,capacitor://localhost,http://localhost"'

# Verify all configs were added
curl http://admin:admin@localhost:5984/_node/nonode@nohost/_config



### Step 7: Configure CouchDB Settings

- [ ] **Add all configuration options**

  - [ ] Click "Configuration" in left menu
  - [ ] For each of the following, click "+ Add Option" and enter:

- [ ] **Config 1:**

  - Section: `chttpd`
  - Name: `require_valid_user`
  - Value: `true`

- [ ] **Config 2:**

  - Section: `chttpd_auth`
  - Name: `require_valid_user`
  - Value: `true`

- [ ] **Config 3:**

  - Section: `httpd`
  - Name: `WWW-Authenticate`
  - Value: `Basic realm="couchdb"`

- [ ] **Config 4:**

  - Section: `httpd`
  - Name: `enable_cors`
  - Value: `true`

- [ ] **Config 5:**

  - Section: `chttpd`
  - Name: `enable_cors`
  - Value: `true`

- [ ] **Config 6:**

  - Section: `chttpd`
  - Name: `max_http_request_size`
  - Value: `4294967296`

- [ ] **Config 7:**

  - Section: `couchdb`
  - Name: `max_document_size`
  - Value: `50000000`

- [ ] **Config 8:**

  - Section: `cors`
  - Name: `credentials`
  - Value: `true`

- [ ] **Config 9:**

  - Section: `cors`
  - Name: `origins`
  - Value: `app://obsidian.md,capacitor://localhost,http://localhost`

- [ ] **Verify all 9 configs were added**
  - Scroll through Configuration page and confirm all entries exist

---

### Step 8: Install Obsidian on Test Machine

- [ ] **Download Obsidian**

  - [ ] Go to https://obsidian.md/download
  - [ ] Download the Linux version (AppImage or .deb)

- [ ] **Install Obsidian**

  ```bash
  # For AppImage
  chmod +x Obsidian-*.AppImage
  ./Obsidian-*.AppImage

  # OR for .deb
  sudo dpkg -i obsidian_*.deb
  ```

- [ ] **Launch Obsidian**
  - Expected: Obsidian welcome screen appears

---




kubectl patch deployment couchdb -n obsidian-livesync --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}
]'

kubectl rollout restart deployment/couchdb -n obsidian-livesync

kubectl get pods -n obsidian-livesync




### Step 9: Create Vault and Configure LiveSync

- [ ] **Create new vault**

  - [ ] Click "Create new vault"
  - [ ] Vault name: (e.g., `TestVault`)
  - [ ] Location: Click "Browse" and select `~/Documents/ObsidianTest`
  - [ ] Click "Create"
  - Expected: Obsidian opens with empty vault

- [ ] **Enable Community Plugins**

  - [ ] Click settings icon (⚙️) bottom left
  - [ ] Click "Community plugins" in left sidebar
  - [ ] Click "Turn on community plugins"
  - [ ] Read the warning, click confirm

- [ ] **Install Self-hosted LiveSync plugin**
  - [ ] Click "Browse" button next to "Community plugins"
  - [ ] Search for: `Self-hosted LiveSync`
  - [ ] Click "Install"
  - [ ] Wait for installation to complete
  - [ ] Click "Enable"
  - Expected: Plugin is now active


kubectl port-forward svc/couchdb-service 5984:5984 -n obsidian-livesync --address=0.0.0.0 &
```

This exposes port 5984 on all interfaces of your Linux server. Then from your PC, try:
```
http://192.168.2.207:5984


---

### Step 10: Configure LiveSync Connection
manual setup in obsidian
- [ ] **Open LiveSync settings**

  - [ ] In Obsidian settings, find "Self-hosted LiveSync" in left sidebar
  - [ ] You'll see 8 icon buttons at the top

- [ ] **Configure remote connection (🛰️ 4th button)**
  - [ ] Click the satellite icon (🛰️)
  - [ ] Set "Remote Type": `CouchDB`
  - [ ] URI: `http://localhost:5984`
  - [ ] Username: (your CouchDB username)
  - [ ] Password: (your CouchDB password)
  - [ ] Database name: (your database name)
- [ ] **Test connection**
  - [ ] Click "Test" button
  - Expected: "Connected to [database] successfully"
- [ ] **Check database configuration**

  - [ ] Click "Check" button
  - Expected: Purple checkmarks next to all items
  - If any item has a "Fix" button, click it

- [ ] **Apply settings**
  - [ ] Click "Apply" button next to "Apply Settings"

---

### Step 11: Enable Encryption

- [ ] **Enable end-to-end encryption**
  - [ ] Scroll down to "End-to-end encryption" section
  - [ ] Toggle it ON
  - [ ] Enter your encryption passphrase (the one you wrote down)
  - [ ] Click "Just apply" (red button)
  - Expected: Encryption enabled message

---

### Step 12: Set Sync Mode

- [ ] **Configure sync mode (🔄 5th button)**

  - [ ] Click the refresh icon (🔄)
  - [ ] Set "Sync mode": `LiveSync`
  - Expected: Dropdown changes to LiveSync

- [ ] **Close settings**

  - [ ] Click X to close settings

- [ ] **Verify sync is working**
  - [ ] Look at top right of Obsidian window
  - Expected: See "Sync: zZz" (standby mode)

---

### Step 13: Test Basic Functionality

- [ ] **Create a test note**
  - [ ] Create new note (Ctrl+N)
  - [ ] Name it "Test Note 1"
  - [ ] Type some text: "This is a test note created on [date/time]"
- [ ] **Verify sync indicator changes**

  - Expected: See "Sync: ↑" briefly, then back to "Sync: zZz"

- [ ] **Check CouchDB for the note**

  - [ ] Go back to browser: `http://localhost:5984/_utils`
  - [ ] Click "Databases" → click your database name
  - [ ] Click "Table" view
  - Expected: See documents with encrypted content

- [ ] **Create a test note with an image**
  - [ ] Create new note "Test Note 2"
  - [ ] Drag a small image (under 1MB) into the note
  - Expected: Image appears in note
  - Expected: Sync indicator shows activity
  - [ ] Check image synced to CouchDB
  - Expected: Additional document for the image file

---

### Step 14: Set Up Second Device for Sync Testing

**Choose your second device:**

- [ ] Option A: Use your phone (need HTTPS - skip for now, test on same machine first)
- [ ] Option B: Create second vault on same test machine
- [ ] Option C: Use another laptop on same network

**For Option B (Second Vault on Same Machine):**

- [ ] **Create second vault in Obsidian**

  - [ ] In Obsidian, click vault switcher (left of settings)
  - [ ] Click "Open another vault"
  - [ ] Click "Create new vault"
  - [ ] Name: `TestVault2`
  - [ ] Location: `~/Documents/ObsidianTest2`
  - [ ] Click "Create"

- [ ] **Install and configure LiveSync on second vault**

  - [ ] Repeat Steps 9-12 exactly
  - [ ] Use SAME credentials
  - [ ] Use SAME database name
  - [ ] Use SAME encryption passphrase
  - [ ] Set to LiveSync mode

- [ ] **Wait for initial sync**
  - Expected: After a moment, "Test Note 1" and "Test Note 2" appear in second vault

---

### Step 15: Test Sync Between Devices

- [ ] **Test real-time sync**

  - [ ] In Vault 1: Edit "Test Note 1", add text
  - [ ] Switch to Vault 2
  - Expected: New text appears within seconds

- [ ] **Test reverse sync**

  - [ ] In Vault 2: Create "Test Note 3"
  - [ ] Switch to Vault 1
  - Expected: "Test Note 3" appears

- [ ] **Test image sync**
  - [ ] In Vault 1: Add image to "Test Note 3"
  - [ ] Switch to Vault 2
  - Expected: Image appears in "Test Note 3"

---

### Step 16: Test Offline Scenarios

- [ ] **Test Vault 1 offline**

  - [ ] Stop port forwarding (Ctrl+C in terminal running kubectl port-forward)
  - [ ] In Vault 1: Create "Offline Note 1", add content
  - Expected: Note saves locally, sync shows error/offline
  - [ ] Restart port forwarding: `kubectl port-forward service/couchdb-service 5984:5984 -n obsidian-livesync`
  - Expected: After 5-10 seconds, "Sync: zZz" returns
  - [ ] Check Vault 2
  - Expected: "Offline Note 1" appears

- [ ] **Test editing same note offline**
  - [ ] Stop port forwarding again
  - [ ] Vault 1: Edit "Test Note 1", add "EDIT FROM VAULT 1" at bottom
  - [ ] Vault 2: Edit "Test Note 1", add "EDIT FROM VAULT 2" at bottom
  - [ ] Restart port forwarding
  - [ ] Wait for sync to complete on both
  - [ ] Check "Test Note 1" on both vaults
  - Expected: May see conflict markers, or both edits merged

---

### Step 17: Test Failure Scenarios

- [ ] **Test CouchDB pod restart**

  - [ ] Delete the pod:
    ```bash
    kubectl delete pod -n obsidian-livesync -l app=couchdb
    ```
  - [ ] Watch it recreate:
    ```bash
    watch kubectl get pods -n obsidian-livesync
    ```
  - Expected: New pod starts, becomes Ready
  - [ ] Try creating a note in Obsidian
  - Expected: After pod is ready, sync resumes

- [ ] **Test with network disconnected** (if on laptop with WiFi)
  - [ ] Disconnect WiFi
  - [ ] Create "Network Test Note" in Vault 1
  - Expected: Saves locally, sync shows offline
  - [ ] Reconnect WiFi
  - Expected: Sync resumes automatically

---

### Step 18: Verify Everything Works

- [ ] **Check all test notes exist in both vaults**

  - [ ] Test Note 1
  - [ ] Test Note 2
  - [ ] Test Note 3
  - [ ] Offline Note 1
  - [ ] Network Test Note

- [ ] **Check images display correctly**

- [ ] **Check CouchDB logs for errors**

  ```bash
  kubectl logs -n obsidian-livesync deployment/couchdb | tail -50
  ```

  - Expected: No major errors

- [ ] **Document your test results**
  - Note any issues encountered
  - Verify all sync scenarios work

---

## Phase 2: Production Deployment

### Step 19: Prepare Production Environment

- [x] **Arch Linux Homeserver Setup** (Bare Metal)

  Your production environment:
  - **Kubernetes Cluster**: kubeadm (single-node)
  - **CNI**: Calico (network policies, enterprise standard)
  - **Ingress**: Nginx Ingress Controller
  - **Storage**: Longhorn (persistent volumes)
  - **Cert Manager**: Automatic TLS
  - **MetalLB**: LoadBalancer for bare metal
  - **GitLab**: Outside K8s (Docker Compose) - watched by Flux for GitOps

- [ ] **Verify cluster is running**
  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```

- [ ] **Verify Longhorn storage class is available**
  ```bash
  kubectl get storageclass
  ```
  - Expected: `longhorn` storage class should be listed

---

### Step 20: Backup Test Data (Optional)

**If you want to keep test notes:**

- [ ] **Get the CouchDB pod name**

  ```bash
  kubectl get pods -n obsidian-livesync
  ```

  - Note the pod name

- [ ] **Backup CouchDB data**
  ```bash
  kubectl cp obsidian-livesync/POD_NAME:/opt/couchdb/data ~/obsidian-couchdb-backup
  ```

---

### Step 21: Deploy to Production

- [ ] **Copy YAML file to Arch Linux homeserver**

  ```bash
  scp ~/obsidian-livesync-k8s/obsidian-livesync.yaml homeserver:~/ 
  ```

  - Or recreate it on homeserver
  - Ensure `storageClassName: longhorn` is set for production

- [ ] **On Arch Linux homeserver, apply configuration**

  ```bash
  kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
  ```

  - Note: With Flux watching GitLab, you may want to commit this to GitLab and let Flux manage it

- [ ] **Wait for pod to be ready**

  ```bash
  watch kubectl get pods -n obsidian-livesync
  ```

- [ ] **Verify deployment**
  ```bash
  kubectl get all -n obsidian-livesync
  ```

---

### Step 22: Restore Data (Optional)

**If you backed up data:**

- [ ] **Copy backup to server laptop**

  ```bash
  scp -r ~/obsidian-couchdb-backup server-laptop:~/
  ```

- [ ] **Get new pod name**

  ```bash
  kubectl get pods -n obsidian-livesync
  ```

- [ ] **Copy data into pod**

  ```bash
  kubectl cp ~/obsidian-couchdb-backup obsidian-livesync/NEW_POD_NAME:/opt/couchdb/data
  ```

- [ ] **Restart pod**
  ```bash
  kubectl delete pod -n obsidian-livesync POD_NAME
  ```

---

### Step 23: Configure Production Access

- [ ] **Find Arch Linux homeserver IP address**

  ```bash
  ip addr show | grep "inet "
  ```

  - Note the IP address (e.g., 192.168.1.100)

- [ ] **Test access to CouchDB**

  - On homeserver:
    ```bash
    curl http://localhost:5984
    ```
  - From another device on network:
    ```bash
    curl http://HOMESERVER_IP:30984
    ```
  - Expected: JSON response from CouchDB
  - Note: With MetalLB, you could also use a LoadBalancer service type instead of NodePort

- [ ] **Configure through web interface**
  - [ ] Open browser to: `http://HOMESERVER_IP:30984/_utils`
  - [ ] Complete Steps 5-7 again (configure CouchDB)
  - [ ] Alternative: If using Ingress + Cert Manager, access via HTTPS URL

---

### Step 24: Update All Devices

**For each device (test laptop, phone, tablet, etc):**

- [ ] **Update LiveSync settings**

  - [ ] Open Obsidian → Settings → Self-hosted LiveSync
  - [ ] Click satellite icon (🛰️)
  - [ ] Change URI to: `http://HOMESERVER_IP:30984` (or HTTPS URL if using Ingress + Cert Manager)
  - [ ] Keep same username, password, database name
  - [ ] Click "Test"
  - Expected: "Connected successfully"
  - [ ] Click "Apply"

- [ ] **Verify sync works**
  - [ ] Create a test note
  - Expected: Syncs to other devices

---

### Step 25: Set Up HTTPS for Mobile (Optional but Recommended)

**Choose one option:**

- [ ] **Option A: Set up Tailscale/WireGuard VPN**

  - Easier, more secure
  - All devices connect via VPN
  - CouchDB stays on local network

- [ ] **Option B: Set up Ingress with Let's Encrypt** (Recommended for your setup)
  - You already have Nginx Ingress Controller and Cert Manager installed
  - Create an Ingress resource for CouchDB with TLS
  - Works from anywhere
  - Requires domain name (or use MetalLB with external IP)

---

### Step 26: Final Verification

- [ ] **Test sync on all devices**

  - [ ] Create note on Device 1
  - [ ] Verify appears on Device 2
  - [ ] Edit on Device 2
  - [ ] Verify changes on Device 1

- [ ] **Test offline/online scenarios**

  - [ ] Disconnect one device
  - [ ] Make edits
  - [ ] Reconnect
  - Expected: Syncs automatically

- [ ] **Monitor for 24 hours**
  - [ ] Check pod status occasionally:
    ```bash
    kubectl get pods -n obsidian-livesync
    ```
  - [ ] Check logs for errors:
    ```bash
    kubectl logs -n obsidian-livesync deployment/couchdb | tail -50
    ```

---

### Step 27: Set Up Backups

- [ ] **Create backup script**

  ```bash
  nano ~/backup-obsidian.sh
  ```

  ```bash
  #!/bin/bash
  DATE=$(date +%Y%m%d_%H%M%S)
  POD=$(kubectl get pod -n obsidian-livesync -l app=couchdb -o jsonpath='{.items[0].metadata.name}')
  kubectl cp obsidian-livesync/$POD:/opt/couchdb/data ~/obsidian-backups/backup_$DATE

  # Keep only last 7 backups
  cd ~/obsidian-backups
  ls -t | tail -n +8 | xargs rm -rf
  ```

- [ ] **Make it executable**

  ```bash
  chmod +x ~/backup-obsidian.sh
  ```

- [ ] **Set up cron job** (optional)

  ```bash
  crontab -e
  ```

  Add line:

  ```
  0 2 * * * ~/backup-obsidian.sh
  ```

  - This runs backup daily at 2 AM

- [ ] **Test backup script**
  ```bash
  ~/backup-obsidian.sh
  ls ~/obsidian-backups/
  ```
  - Expected: See backup folder created

---

### Step 28: Monitor and Maintain

- [ ] **Set up monitoring** (optional)

  - [ ] Install k9s for easy cluster monitoring:
    ```bash
    curl -sS https://webinstall.dev/k9s | bash
    ```
  - [ ] Run k9s:
    ```bash
    k9s
    ```
  - Navigate with arrow keys, press `0` to see all namespaces

- [ ] **Check disk usage periodically**

  ```bash
  kubectl exec -n obsidian-livesync deployment/couchdb -- df -h /opt/couchdb/data
  ```

- [ ] **Check logs weekly**
  ```bash
  kubectl logs -n obsidian-livesync deployment/couchdb --tail=100
  ```

---

## Troubleshooting Checklist

**If sync isn't working:**

- [ ] Verify pod is running: `kubectl get pods -n obsidian-livesync`
- [ ] Check pod logs: `kubectl logs -n obsidian-livesync deployment/couchdb`
- [ ] Test CouchDB connection: `curl http://SERVER_IP:30984`
- [ ] Verify credentials match exactly on all devices
- [ ] Verify encryption passphrase is identical on all devices
- [ ] Check firewall isn't blocking port 30984

**If pod won't start:**

- [ ] Check pod description: `kubectl describe pod -n obsidian-livesync`
- [ ] Verify PVC is bound: `kubectl get pvc -n obsidian-livesync`
- [ ] Check available disk space on server

**If conflicts occur frequently:**

- [ ] Wait 5-10 seconds after reconnecting before editing
- [ ] Avoid editing same note simultaneously on multiple devices
- [ ] Check sync mode is set to "LiveSync" on all devices

---

## Completion Checklist

- [ ] ✅ Kubernetes cluster running on test machine
- [ ] ✅ CouchDB deployed and configured on test
- [ ] ✅ Obsidian installed and configured on test machine
- [ ] ✅ LiveSync working between two vaults
- [ ] ✅ Offline scenarios tested successfully
- [ ] ✅ Failure scenarios tested successfully
- [ ] ✅ Production cluster set up on server laptop
- [ ] ✅ CouchDB deployed to production
- [ ] ✅ All devices updated with production URL
- [ ] ✅ Sync working on all devices
- [ ] ✅ HTTPS/VPN configured for mobile (if needed)
- [ ] ✅ Backup system in place
- [ ] ✅ 24-hour stability test passed

---

**Congratulations! You have a fully functional self-hosted Obsidian sync system!**

## Next Steps

- [ ] Explore Obsidian plugins (Templates, Daily Notes, Graph View)
- [ ] Set up automated health checks
- [ ] Consider adding monitoring (Prometheus/Grafana)
- [ ] Join the Obsidian community for tips and tricks
