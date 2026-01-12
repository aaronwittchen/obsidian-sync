#!/bin/bash
# Helper script to generate base64-encoded credentials for CouchDB
# Usage: ./setup-credentials.sh

set -e

echo "=========================================="
echo "CouchDB Credentials Setup Helper"
echo "=========================================="
echo ""

# Function to generate base64 encoded value
encode_base64() {
    echo -n "$1" | base64 -w 0
}

# Function to generate encryption key for Longhorn volumes
# Returns a plain string (not base64 encoded, as stringData handles that)
generate_encryption_key() {
    openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64
}

# Prompt for credentials
echo "Please enter your CouchDB credentials:"
echo ""
read -p "CouchDB Username: " COUCHDB_USERNAME
read -sp "CouchDB Password: " COUCHDB_PASSWORD
echo ""
read -p "Database Name (e.g., obsidiandb): " DATABASE_NAME
read -sp "Encryption Passphrase (for Obsidian LiveSync): " ENCRYPTION_PASSPHRASE
echo ""
echo ""

# Generate encryption key for Longhorn volumes (plain string, not base64)
ENCRYPTION_KEY=$(generate_encryption_key)

# Encode credentials for Kubernetes Secret (data field requires base64)
ENCODED_USERNAME=$(encode_base64 "$COUCHDB_USERNAME")
ENCODED_PASSWORD=$(encode_base64 "$COUCHDB_PASSWORD")

echo "=========================================="
echo "Generated Values (save these securely!):"
echo "=========================================="
echo ""
echo "CouchDB Username: $COUCHDB_USERNAME"
echo "CouchDB Password: [HIDDEN]"
echo "Database Name: $DATABASE_NAME"
echo "Encryption Passphrase: [HIDDEN]"
echo ""
echo "Base64 Encoded Username: $ENCODED_USERNAME"
echo "Base64 Encoded Password: $ENCODED_PASSWORD"
echo "Volume Encryption Key: $ENCRYPTION_KEY"
echo "  (This will be stored in stringData, so no base64 encoding needed)"
echo ""

# Update YAML file
YAML_FILE="obsidian-livesync.yaml"

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: $YAML_FILE not found in current directory"
    exit 1
fi

echo "Updating $YAML_FILE with your credentials..."
echo ""

# Backup original file
cp "$YAML_FILE" "${YAML_FILE}.backup"
echo "Backup created: ${YAML_FILE}.backup"

# Update username in Secret
sed -i "s/username:.*/username: $ENCODED_USERNAME  # Base64-encoded username/" "$YAML_FILE"

# Update password in Secret
sed -i "s/password:.*/password: $ENCODED_PASSWORD  # Base64-encoded password/" "$YAML_FILE"

# Update encryption key in both files
# Use a different delimiter (|) for sed to avoid issues with / in the key
# Escape special characters that could break sed (but preserve /)
ESCAPED_KEY=$(echo "$ENCRYPTION_KEY" | sed 's/[[\.*^$()+?{|]/\\&/g')
# Use | as delimiter instead of / to avoid issues with / characters in base64 strings
sed -i "s|CRYPTO_KEY_VALUE:.*|CRYPTO_KEY_VALUE: \"$ESCAPED_KEY\"  # 32-byte encryption key for Longhorn volumes|" "$YAML_FILE"
# Also update the longhorn-encryption.yaml file if it exists
if [ -f "longhorn-encryption.yaml" ]; then
    sed -i "s|CRYPTO_KEY_VALUE:.*|CRYPTO_KEY_VALUE: \"$ESCAPED_KEY\"  # 32-byte encryption key for Longhorn volumes|" "longhorn-encryption.yaml"
fi

echo "✅ Credentials updated in $YAML_FILE"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Review the updated $YAML_FILE file"
echo "2. Save your credentials securely (password manager recommended)"
echo "3. Deploy to Kubernetes:"
echo "   kubectl apply -f $YAML_FILE -n obsidian-livesync"
echo ""
echo "Your credentials have been saved to:"
echo "  - Username: $COUCHDB_USERNAME"
echo "  - Database: $DATABASE_NAME"
echo "  - Encryption passphrase: [saved]"
echo ""
echo "⚠️  IMPORTANT: Keep your encryption passphrase safe!"
echo "   You'll need it on ALL devices using Obsidian LiveSync."
echo ""

