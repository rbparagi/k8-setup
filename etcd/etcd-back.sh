#!/bin/bash

# === CONFIGURATION ===
BACKUP_DIR="/opt/etcd-backups"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
SNAPSHOT_FILE="$BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db"
S3_BUCKET="s3://your-etcd-backup-bucket"
AWS_PROFILE="default"  # Change if needed

echo "📁 Creating backup directory if not exists..."
mkdir -p "$BACKUP_DIR"

# === DETECT ETCD ENDPOINTS ===
echo "📡 Fetching control plane internal IPs..."
MASTER_IPS=$(kubectl get nodes -l node-role.kubernetes.io/control-plane= -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
ENDPOINTS=$(echo $MASTER_IPS | sed 's/ /:2379,https:\/\//g')
ENDPOINTS="https://$ENDPOINTS:2379"
echo "🔗 Using ETCD endpoints: $ENDPOINTS"

# === SNAPSHOT ===
echo "💾 Taking ETCD snapshot..."
ETCDCTL_API=3 etcdctl \
  --endpoints="$ENDPOINTS" \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save "$SNAPSHOT_FILE"

if [ $? -ne 0 ]; then
  echo "❌ Snapshot creation failed!"
  exit 1
else
  echo "✅ Snapshot saved at: $SNAPSHOT_FILE"
fi

# === VERIFICATION ===
echo "🔍 Verifying snapshot integrity..."
ETCDCTL_API=3 etcdctl snapshot status "$SNAPSHOT_FILE" --write-out=table

# === UPLOAD TO S3 ===
echo "☁️ Uploading snapshot to S3 bucket: $S3_BUCKET"
aws s3 cp "$SNAPSHOT_FILE" "$S3_BUCKET/" --profile "$AWS_PROFILE"

if [ $? -eq 0 ]; then
  echo "✅ Snapshot uploaded to S3"
else
  echo "❌ S3 upload failed"
fi
