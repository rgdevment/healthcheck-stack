#!/bin/bash
set -euo pipefail

LOG_FILE="/opt/stack-monitoring/backups/backup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

MAXSIZE=1048576  # 1 MB
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -gt "$MAXSIZE" ]; then
  echo "🧹 Truncating $LOG_FILE (larger than 1MB)"
  > "$LOG_FILE"
fi

# === Configuration ===
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
LOCAL_BACKUP="/opt/stack-monitoring/backups/${TIMESTAMP}"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="Backups/system/stack-monitoring"

# === Secure .env loader ===
load_env() {
  local env_file="${1:-.env}"

  if [[ ! -f "$env_file" ]]; then
    echo "❌ Environment file '$env_file' not found."
    exit 1
  fi

  set -o allexport
  # shellcheck disable=SC1090
  source "$env_file"
  set +o allexport
}

# === Load .env before using any vars ===
load_env /opt/stack-monitoring/.env
: "${MYSQL_ROOT_PASSWORD:?❌ MYSQL_ROOT_PASSWORD is required but not set}"

echo "🔄 Starting backup: ${TIMESTAMP}"

# === Ensure containers are running ===
for SERVICE in mariadb redis grafana; do
  if ! docker inspect -f '{{.State.Running}}' "$SERVICE" 2>/dev/null | grep -q true; then
    echo "❌ Docker container $SERVICE is not running. Aborting."
    exit 1
  fi
done

# === Create local backup directory ===
mkdir -p "${LOCAL_BACKUP}"

# === Full /opt/backups/ directory ===
echo "📦 Backing up full /opt/backups/ (includes AdGuard, Jellyfin, etc.)..."
mkdir -p "${LOCAL_BACKUP}/backups"
sudo cp -r /opt/backups/* "${LOCAL_BACKUP}/backups/"
sudo chown -R rgdevment:rgdevment "${LOCAL_BACKUP}/backups/"
echo "✅ /opt/backups/ copied completely."

# === MariaDB ===
echo "📦 Dumping MariaDB from outside container..."
docker run --rm \
  --network internal-net \
  -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" \
  -v "${LOCAL_BACKUP}:/backup" \
  mariadb:10.6 \
  sh -c 'mysqldump -hmariadb -uroot --all-databases --single-transaction --quick --lock-tables=false > /backup/mariadb.sql'
echo "✅ MariaDB backup completed at ${LOCAL_BACKUP}"

# === Redis ===
echo "📦 Saving Redis snapshot..."
docker exec redis redis-cli save
docker cp redis:/data/dump.rdb "${LOCAL_BACKUP}/redis.rdb"

# === Grafana ===
echo "📦 Copying Grafana config..."
docker cp grafana:/var/lib/grafana "${LOCAL_BACKUP}/grafana"

# === Compress key backup modules ===
echo "📦 Compressing modular components (AdGuard, Jellyfin, Grafana)..."

# AdGuard
if [ -d "${LOCAL_BACKUP}/backups/adguardhome" ]; then
  tar -czf "${LOCAL_BACKUP}/adguardhome.tar.gz" -C "${LOCAL_BACKUP}/backups" adguardhome
  rm -rf "${LOCAL_BACKUP}/backups/adguardhome"
  echo "✅ AdGuard compressed."
fi

# Jellyfin
if [ -d "${LOCAL_BACKUP}/backups/jellyfin" ]; then
  tar -czf "${LOCAL_BACKUP}/jellyfin.tar.gz" -C "${LOCAL_BACKUP}/backups" jellyfin
  rm -rf "${LOCAL_BACKUP}/backups/jellyfin"
  echo "✅ Jellyfin compressed."
fi

# Grafana
if [ -d "${LOCAL_BACKUP}/grafana" ]; then
  tar -czf "${LOCAL_BACKUP}/grafana.tar.gz" -C "${LOCAL_BACKUP}" grafana
  rm -rf "${LOCAL_BACKUP}/grafana"
  echo "✅ Grafana compressed."
fi

echo "🎯 Compression completed."


# === Clean up local backups BEFORE upload ===
echo "🧹 Cleaning up old local backups..."
ls -1dt ./backups/*/ | tail -n +6 | xargs -d '\n' rm -rf || true
find ./backups -type d -mtime +30 -exec rm -rf {} \;

# === Upload to Google Drive using rclone ===
echo "☁️ Uploading to Google Drive (${GDRIVE_FOLDER})..."
rclone copy "${LOCAL_BACKUP}" "${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/${TIMESTAMP}" --quiet

if [ $? -ne 0 ]; then
  echo "❌ Error uploading to Google Drive. Check rclone config."
  exit 1
fi

echo "✅ Backup uploaded to cloud."

# === Cleanup old backups in Google Drive ===
echo "🧹 Cleaning up old remote backups (keeping 5 most recent)..."
REMOTE_DIR="${GDRIVE_REMOTE}:${GDRIVE_FOLDER}"
mapfile -t old_dirs < <(
  rclone lsd "$REMOTE_DIR" \
    | sort -k2 -r \
    | tail -n +6 \
    | awk '{print $NF}'
)

if [ ${#old_dirs[@]} -gt 0 ]; then
  for dir in "${old_dirs[@]}"; do
    echo "  🔥 Removing $REMOTE_DIR/$dir"
    rclone purge "$REMOTE_DIR/$dir"
  done
else
  echo "✅ No old remote backups to remove."
fi

echo "✅ Backup and cleanup completed successfully!"
