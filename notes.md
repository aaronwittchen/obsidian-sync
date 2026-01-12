# Obsidian LiveSync on Kubernetes

## Overview

This guide will help you set up Obsidian LiveSync with CouchDB on your Kubernetes cluster running on an Arch Linux laptop. The setup provides instant, self-hosted sync for your Obsidian notes across all devices.

kubeadmin

## Architecture

The setup consists of:

1. **CouchDB database** - Stores encrypted copies of your notes
2. **Persistent storage** - Keeps your data safe across pod restarts
3. **Service** - Makes CouchDB accessible within your network
4. **Optional Ingress** - For HTTPS access (needed for mobile devices)



## Step 1: Prepare Your Kubernetes Environment

### Check your cluster is running:

```bash
kubectl cluster-info
kubectl get nodes
```

### Create a namespace for organization:

```bash
kubectl create namespace obsidian-livesync
```

### Set this namespace as default (optional):

```bash
kubectl config set-context --current --namespace=obsidian-livesync
```

---

## Step 2: Create Storage for CouchDB

CouchDB needs persistent storage to keep your notes safe.

### Check available storage classes:

```bash
kubectl get storageclass
```

You should see something like `local-path`, `standard`, or similar. Note the name - you'll need it.

### Create the storage claim:

You'll create a file that requests storage space. This is called a PersistentVolumeClaim (PVC).

**What it does:** Reserves 10GB of disk space for CouchDB data.

---

## Step 3: Deploy CouchDB

CouchDB is the database that will store your notes.

### Important: Set your credentials

You need to choose:

- **Username**: e.g., `obsidian_user`
- **Password**: Choose a strong password
- **Database name**: e.g., `obsidiandb`

**Write these down - you'll need them later!**

### What the deployment does:

1. **Runs CouchDB 3.3.3** in a container
2. **Sets admin credentials** via environment variables
3. **Mounts persistent storage** so data survives restarts
4. **Exposes port 5984** for the web interface and API
5. **Includes health checks** to ensure it's running properly

---

## Step 4: Apply the Configuration

### Save all three YAML sections to a file:

Create a file called `obsidian-livesync.yaml` with all the Kubernetes configurations (PVC, Deployment, Service).

### Apply it to your cluster:

```bash
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
```

### Verify everything is running:

```bash
# Check if pod is running
kubectl get pods -n obsidian-livesync

# Check if service is created
kubectl get services -n obsidian-livesync

# Check persistent storage
kubectl get pvc -n obsidian-livesync
```

Wait until the pod status shows `Running` and `READY` shows `1/1`.

---

## Step 5: Access CouchDB Web Interface

### Find the service IP:

```bash
kubectl get service couchdb-service -n obsidian-livesync
```

Look for the `CLUSTER-IP` column.

### Access from your laptop:

Since your Kubernetes cluster is on your laptop, you have two options:

**Option A - Port Forward (Recommended for testing):**

```bash
kubectl port-forward service/couchdb-service 5984:5984 -n obsidian-livesync
```

Now open: `http://localhost:5984/_utils`

**Option B - Use NodePort (Better for network access):**

If you used NodePort in the Service, find the assigned port:

```bash
kubectl get service couchdb-service -n obsidian-livesync
```

Look for the port mapping like `5984:XXXXX/TCP`. Access using `http://YOUR_LAPTOP_IP:XXXXX/_utils`

To find your laptop's IP:

```bash
ip addr show | grep "inet "
```

---

## Step 6: Configure CouchDB (First Time Setup)

### Login to CouchDB:

1. Open the web interface: `http://localhost:5984/_utils` (or your NodePort URL)
2. Click **"Login"** in the top right
3. Enter the username and password you set in Step 3

### Enable Single Node Mode:

1. Click the **wrench icon** (Setup) on the left sidebar
2. Click **"Configure a Single Node"**
3. Enter your admin credentials again
4. Leave host as `127.0.0.1` and port as `5984`
5. Click **"Configure Node"**

### Verify Installation:

1. Click **"Verify"** in the left sidebar
2. Click **"Verify Installation"**
3. You should see: `Success! Your CouchDB installation is working. Time to Relax.`
4. All 6 items should have green checkmarks

---

## Step 7: Create Your Database

### Create the database:

1. Click **"Databases"** in the left sidebar
2. Click **"Create Database"** (top right)
3. Enter database name: `obsidiandb` (or whatever you chose)
4. Select **"Non-partitioned - recommended for most workloads"**
5. Click **"Create"**

**Tip:** If multiple people will use this, create separate databases like `obsidiandb_john`, `obsidiandb_jane`

---

## Step 8: Configure CouchDB Settings

### Add security and performance settings:

1. Click **"Configuration"** in the left sidebar
2. Click **"+ Add Option"** for each of these 9 entries:

| Section       | Name                    | Value                                                      |
| ------------- | ----------------------- | ---------------------------------------------------------- |
| `chttpd`      | `require_valid_user`    | `true`                                                     |
| `chttpd_auth` | `require_valid_user`    | `true`                                                     |
| `httpd`       | `WWW-Authenticate`      | `Basic realm="couchdb"`                                    |
| `httpd`       | `enable_cors`           | `true`                                                     |
| `chttpd`      | `enable_cors`           | `true`                                                     |
| `chttpd`      | `max_http_request_size` | `4294967296`                                               |
| `couchdb`     | `max_document_size`     | `50000000`                                                 |
| `cors`        | `credentials`           | `true`                                                     |
| `cors`        | `origins`               | `app://obsidian.md,capacitor://localhost,http://localhost` |

**What these do:**

- Enables authentication (security)
- Enables CORS (allows mobile apps to connect)
- Increases size limits (for attachments/images)

---

## Step 9: Set Up Obsidian Desktop Client

### Install Obsidian:

Download from: https://obsidian.md/download

### Create a new vault:

1. Click **"Create new vault"**
2. Name it whatever you like (e.g., `Vault`)
3. Choose location (e.g., `~/Documents/Obsidian`)
4. Click **"Create"**

### Install LiveSync plugin:

1. Click the **settings gear icon** (bottom left)
2. Go to **"Community plugins"**
3. Click **"Turn on community plugins"**
4. Click **"Browse"**
5. Search for: `Self-hosted LiveSync`
6. Install the plugin by **vrtmrz**
7. Click **"Enable"**

---

## Step 10: Configure LiveSync Plugin

### Open plugin settings:

1. In Obsidian settings, find **"Self-hosted LiveSync"** in the left sidebar
2. You'll see 8 icon buttons at the top

### Configure connection (Satellite icon 🛰️ - 4th button):

1. Click the **satellite icon**
2. Set **Remote Type**: `CouchDB`
3. Enter **URI**: `http://YOUR_LAPTOP_IP:5984` (or `http://localhost:5984` if port-forwarding)
4. Enter **Username**: The one you set in Step 3
5. Enter **Password**: The one you set in Step 3
6. Enter **Database name**: `obsidiandb` (or what you created)
7. Click **"Test"** - Should say: `Connected to obsidiandb successfully`
8. Click **"Check"** - All items should have purple checkmarks
9. Click **"Apply Settings"**

### Enable encryption (STRONGLY RECOMMENDED):

1. Scroll down to **"End-to-end encryption"**
2. Toggle it **ON**
3. Enter a **passphrase** (remember this - you'll need it on ALL devices!)
4. Click **"Just apply"** (red button)

### Set sync mode (Refresh icon 🔄 - 5th button):

1. Click the **refresh icon**
2. Set **Sync mode**: `LiveSync`
3. Close settings

### Verify it's working:

Look at the top right of your note - you should see **"Sync: zZz"** meaning it's in standby mode.

---

## Step 11: Set Up Other Devices

### For each additional device:

1. Install Obsidian app
2. Create/open vault with **same name**
3. Install LiveSync plugin (same steps as above)
4. Configure with **same settings**:
   - Same CouchDB URL
   - Same username/password
   - Same database name
   - **SAME ENCRYPTION PASSPHRASE** (critical!)
5. Select **LiveSync** mode

**Important for mobile devices:** You'll need HTTPS access (see Step 12).

---

## Step 12: Optional - HTTPS Access for Mobile

Mobile apps require HTTPS. You have two options:

### Option A: Use a VPN (Most Secure)

Install WireGuard on your laptop and mobile devices. This keeps everything private and doesn't expose CouchDB to the internet.

**Pros:** Most secure, no public exposure
**Cons:** Must be connected to VPN to sync

### Option B: Use Reverse Proxy with Let's Encrypt

Set up an Ingress controller in Kubernetes with cert-manager for automatic HTTPS certificates.

**Pros:** Works anywhere with internet
**Cons:** More complex setup, exposes service to internet

---

## Troubleshooting

### Pod won't start:

```bash
# Check pod status
kubectl describe pod -n obsidian-livesync

# View logs
kubectl logs -f deployment/couchdb -n obsidian-livesync
```

### Can't access CouchDB:

```bash
# Verify service is running
kubectl get endpoints -n obsidian-livesync

# Test connection from within cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Then inside the pod:
wget -O- http://couchdb-service:5984
```

### Storage issues:

```bash
# Check if PVC is bound
kubectl get pvc -n obsidian-livesync

# Check available storage
kubectl describe pvc couchdb-data -n obsidian-livesync
```

### Sync not working:

1. Check credentials match exactly on all devices
2. Verify encryption passphrase is identical
3. Test CouchDB connection with "Test" button
4. Check CouchDB logs for errors

---

## Maintenance

### View CouchDB logs:

```bash
kubectl logs -f deployment/couchdb -n obsidian-livesync
```

### Backup your data:

```bash
# Get the pod name
kubectl get pods -n obsidian-livesync

# Copy data out
kubectl cp obsidian-livesync/PODNAME:/opt/couchdb/data ./couchdb-backup
```

### Update CouchDB version:

Edit the deployment YAML and change the image version, then:

```bash
kubectl apply -f obsidian-livesync.yaml -n obsidian-livesync
```

---

## Tips

1. **Test sync**: Create a note on one device, verify it appears on another
2. **Monitor health**: Use `kubectl get pods` regularly to ensure pod is healthy
3. **Set resource limits**: Add memory/CPU limits to prevent laptop slowdown
4. **Regular backups**: Schedule periodic backups of CouchDB data
5. **Use encryption**: Always enable end-to-end encryption for privacy

---

## What Next?

Once everything is working:

1. Explore Obsidian's features (templates, daily notes, graph view)
2. Install other community plugins to enhance functionality
3. Set up automated backups using Kubernetes CronJobs
4. Consider setting up monitoring (Prometheus/Grafana)

---

## Resources

- **Obsidian:** https://obsidian.md
- **LiveSync Plugin:** https://github.com/vrtmrz/obsidian-livesync
- **CouchDB Docs:** https://docs.couchdb.org
- **Kubernetes Docs:** https://kubernetes.io/docs

---

**Congratulations!** You now have a self-hosted, encrypted, instant-sync note-taking system running on your own hardware.

Great question! Let me explain how CouchDB and local files work together in this setup:

## How It Works

**Obsidian always uses local files** - that's the foundation of how Obsidian works. Your notes are stored as `.md` (markdown) files in a folder on each device.

**CouchDB acts as a "sync middleman"** - it doesn't replace your local files, it helps keep them synchronized across devices.

## The Sync Process

Here's what happens when you type in Obsidian:

1. **You type on Device A** → Changes are saved to your local `.md` file
2. **LiveSync plugin detects the change** → It reads the updated file
3. **Plugin sends changes to CouchDB** → Stores an encrypted copy in the database
4. **Device B's LiveSync plugin notices** → "Hey, there's an update in CouchDB!"
5. **Device B downloads the changes** → Updates its local `.md` file
6. **You see the changes on Device B** → Reading from the local file

## Why Not Just Sync Files Directly?

You might wonder: "Why not use something like Syncthing to sync the `.md` files directly?"

**CouchDB + LiveSync offers:**

- **Character-by-character sync** - See changes as you type (like Google Docs)
- **Conflict resolution** - Handles when you edit the same file on two devices
- **Revision history** - Built into CouchDB's architecture
- **Partial sync** - Only sends what changed, not entire files
- **Mobile-friendly** - Works better than file sync on iOS
- **Offline editing** - Edit without connection, syncs when reconnected

## What CouchDB Stores

CouchDB doesn't store your files as files. Instead, it stores:

- **Document revisions** - Each change you make
- **Metadata** - File names, modification times, etc.
- **Encrypted content** - Your actual note content (if encryption enabled)
- **Sync state** - What's been synced to which device

## The Local Files Never Go Away

**Important:** Your vault folder with all your `.md` files remains on each device. If:

- CouchDB goes down → You can still read/write notes locally
- Internet connection lost → Everything still works locally
- You uninstall LiveSync → Your files are still there

CouchDB is purely a synchronization layer, not the primary storage.

## Think of it like this:

- **Without CouchDB:** Each device has its own isolated copy of notes
- **With CouchDB:** Each device still has its own copy, but they talk to each other through CouchDB to stay in sync

Yes, **images work with LiveSync**, but there are some important details to know:

## How Images Are Handled

### Images Sync Just Like Text

When you add an image to an Obsidian note:

1. **Image file is stored locally** in your vault folder (usually in an `attachments` or `assets` folder)
2. **LiveSync detects the new file** and syncs it to CouchDB
3. **Other devices download the image** from CouchDB
4. **Image appears in your note** on all devices

### What Gets Synced

LiveSync syncs:

- ✅ **PNG, JPG, JPEG** images
- ✅ **GIF** images
- ✅ **SVG** files
- ✅ **PDF** files (if you embed them)
- ✅ **Audio files** (mp3, wav, etc.)
- ✅ **Video files** (though this can be slow)
- ✅ Any other attachments you add

## Important Considerations

### File Size Limits

Remember in Step 8 of the guide, we set:

- `max_document_size`: `50000000` (50MB per file)
- `max_http_request_size`: `4294967296` (4GB total request)

**This means:**

- Individual images up to 50MB will sync
- Larger files won't sync and may cause errors

### Performance Impact

**Large images can slow things down:**

- Initial sync takes longer with many/large images
- Mobile data usage increases significantly
- CouchDB storage grows quickly
- Battery drain on mobile devices increases

### Best Practices for Images

1. **Compress images before adding them**

   - Use tools to reduce file size
   - Aim for under 1-2MB per image when possible

2. **Use appropriate image formats**

   - JPG for photos (smaller file size)
   - PNG for screenshots with text (better quality)

3. **Be mindful on mobile**

   - Large image syncs can eat mobile data
   - Consider syncing only on WiFi

4. **Monitor your CouchDB storage**
   - Images accumulate quickly
   - The 10GB storage in the guide may fill up if you have many images

## Configuration for Better Image Handling

You can adjust LiveSync settings:

### In Obsidian LiveSync Settings:

1. **File size limit** - Set maximum file size to sync
2. **Sync on save only** - Prevent constant syncing of large files
3. **Exclude patterns** - Skip syncing certain folders (like a `large-files` folder)

### Example: Skip Large Files

In LiveSync settings, you can add patterns to exclude:

```
large-files/**
videos/**
*.mp4
*.mov
```

## Alternative Approach for Many Images

If you have **lots of images** or **very large files**, consider:

### Option 1: Separate Image Storage

- Keep images in a cloud service (Nextcloud, etc.)
- Link to them in Obsidian notes
- Only sync the markdown files with LiveSync

### Option 2: Increase CouchDB Storage

Change the PersistentVolumeClaim size:

```yaml
resources:
  requests:
    storage: 50Gi # Instead of 10Gi
```

### Option 3: Use Obsidian's Built-in Sync

For vaults with many large images, Obsidian's official sync ($4/month) is optimized for this and might be worth it.

## Testing Image Sync

Try this to test:

1. **Add a small image** (under 1MB) to a note on Device A
2. **Wait a few seconds**
3. **Check Device B** - the image should appear
4. **Check CouchDB web interface** - you'll see the file listed in the database

## TL;DR

**Yes, images sync**, but:

- Keep them reasonably sized (under 5MB ideally)
- Be aware of storage and bandwidth usage
- You can exclude large files if needed
- Everything syncs through CouchDB just like text

Does this answer your question about images? Would you like tips on managing image-heavy vaults?

Yes, **it works seamlessly even when devices go offline!** This is one of the best features of LiveSync. Let me explain how it handles different scenarios:

## Offline/Online Scenarios

### Scenario 1: Both Devices Online

**What happens:**

- You type on Device A → Syncs to CouchDB instantly
- Device B sees the update → Downloads it immediately
- **Result:** Near-instant sync (like Google Docs)

### Scenario 2: Device A Offline, Device B Online

**What happens:**

- You edit notes on Device A (offline) → Changes saved locally only
- Device B is online → Continues to work normally with its current data
- Device A comes back online → Automatically syncs all changes to CouchDB
- Device B detects updates → Downloads the changes
- **Result:** Both devices sync up automatically when Device A reconnects

### Scenario 3: Device B Offline, Device A Online

**What happens:**

- You edit on Device A → Syncs to CouchDB immediately
- Device B is offline → Keeps working with local files, doesn't know about changes yet
- Device B comes back online → Automatically checks CouchDB for updates
- Device B downloads all missed changes
- **Result:** Device B catches up automatically

### Scenario 4: Both Devices Offline

**What happens:**

- You edit on Device A → Saved locally
- You edit on Device B → Saved locally (different notes or same notes)
- Both come back online → Both sync their changes to CouchDB
- LiveSync detects conflicts (if any) → Handles them automatically
- **Result:** All changes preserved, conflicts resolved

## Conflict Resolution

### What if you edit the same note on both devices while offline?

LiveSync handles this intelligently:

1. **No conflict (different parts of note):**

   - LiveSync merges the changes automatically
   - Both edits are preserved

2. **Conflict (same paragraph edited):**

   - LiveSync creates both versions
   - You'll see conflict markers in the note
   - You manually choose which version to keep

3. **Conflict handling options:**
   - **Automatic merge** (default) - Tries to combine changes
   - **Keep newer** - Uses the most recent edit
   - **Manual resolution** - Shows you both versions

## Real-World Examples

### Example 1: Commute Usage

**Morning:**

- Edit notes on laptop at home (online) → Syncs to CouchDB
- Leave home, open phone on subway (offline) → Still has yesterday's notes
- Arrive at coffee shop (WiFi) → Phone syncs, gets all morning edits

### Example 2: Travel

**Day 1:**

- Add notes on laptop before flight → Syncs to CouchDB
- On airplane (offline) → Edit notes on tablet using local copies
- After landing (online) → Tablet syncs all airplane edits

**Day 2:**

- Edit same note on phone at hotel → Syncs to CouchDB
- Open laptop later → Gets phone edits automatically

### Example 3: Power Outage

- Your laptop (with CouchDB) loses power → CouchDB goes offline
- You edit notes on phone → Saved locally on phone
- Laptop comes back online → Phone syncs when it next connects
- **Important:** CouchDB can be down, devices still work!

## How It Knows What to Sync

LiveSync tracks:

- **Revision numbers** - Each change gets a version number
- **Timestamps** - When each edit was made
- **Device ID** - Which device made the change
- **Sync state** - What's been synced and what hasn't

When a device comes online, it:

1. Asks CouchDB: "What's changed since I was last online?"
2. Downloads only the new/changed content
3. Uploads its own changes that CouchDB doesn't have
4. Merges everything together

## Sync Indicators in Obsidian

You'll see different status messages:

- **"Sync: zZz"** - Standby, everything synced
- **"Sync: ↑"** - Uploading changes to CouchDB
- **"Sync: ↓"** - Downloading changes from CouchDB
- **"Sync: ⚠️"** - Conflict detected or error
- **"Sync: ✗"** - Can't connect to CouchDB (offline is fine)

## Best Practices for Offline/Online Usage

### 1. Don't worry about sync order

- Devices can come online in any order
- Everything will sync up eventually

### 2. Give it a moment after reconnecting

- When coming back online, wait 5-10 seconds
- Let the initial sync complete before editing

### 3. Check for conflicts after long offline periods

- If you edited the same note on multiple offline devices
- Look for conflict markers in your notes

### 4. Mobile data considerations

- Large syncs might use mobile data
- Configure LiveSync to "WiFi only" if needed

## What About CouchDB Being Offline?

**Here's the key point:** Your laptop with CouchDB can be completely off, and your other devices still work!

**Scenario:**

- Laptop (CouchDB host) is shut down
- Edit notes on phone → Saved locally
- Edit notes on tablet → Saved locally
- Turn laptop back on → Both devices sync when they connect

**The sync just waits patiently until CouchDB is available again.**

## Technical Details

### How LiveSync Handles Offline Mode

1. **Continuous monitoring** - Checks connection every few seconds
2. **Queue system** - Stores unsent changes in a queue
3. **Automatic retry** - Tries to sync when connection restored
4. **Smart batching** - Groups multiple changes together for efficiency

### Data Safety

- **Local-first architecture** - Your data is always on your device
- **No data loss** - Even if CouchDB fails, your local files are safe
- **Revision history** - CouchDB keeps old versions (configurable)

## TL;DR

**Yes, it works perfectly with offline/online situations:**

✅ Edit offline, syncs when you reconnect  
✅ Devices can be offline independently  
✅ No specific order required  
✅ Automatic conflict resolution  
✅ CouchDB can be offline too  
✅ Local files always work  
✅ No data loss

**It's designed exactly for this use case** - that's why it's better than simple file syncing for Obsidian!

Does this address your concerns about offline/online functionality?
