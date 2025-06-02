#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

LOG_FILE="/opt/stack-monitoring/backups/backup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

MAXSIZE=1048576  # 1 MB
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -gt "$MAXSIZE" ]; then
  echo "🧹 Truncating $LOG_FILE (larger than 1MB)"
  > "$LOG_FILE"
fi

# === Configuration ===
BACKUP_BASE="/opt/stack-monitoring/backups"
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
LOCAL_BACKUP="${BACKUP_BASE}/${TIMESTAMP}"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="Backups/system/stack-monitoring"
# --- Remote Backup Retention ---
NUM_REMOTE_BACKUPS_TO_KEEP=10 # Number of backups to keep on Google Drive
# --- Local Backup Retention ---
NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT=10 # How many local backups to keep (by count)
NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS=30  # Maximum age in days for local backups

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
# (rclone problem) sudo cp -r /opt/backups/* "${LOCAL_BACKUP}/backups/"
# (rclone problem) sudo chown -R rgdevment:rgdevment "${LOCAL_BACKUP}/backups/"
# add on - sudo visudo -f /etc/sudoers.d/backup
# rgdevment ALL=(ALL) NOPASSWD: /bin/cp, /bin/chown
sudo /bin/cp -r /opt/backups/* "${LOCAL_BACKUP}/backups/"
sudo /bin/chown -R rgdevment:rgdevment "${LOCAL_BACKUP}/backups/"
echo "✅ /opt/backups/ copied completely."

# === MariaDB ===
echo "📦 Dumping MariaDB from outside container..."
docker run --rm \
  --network internal-net \
  -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" \
  -v "${LOCAL_BACKUP}:/backup" \
  mariadb:10.6 \
  sh -c 'mysqldump -hmariadb -uroot --all-databases --flush-privileges --single-transaction --quick --lock-tables=false > /backup/mariadb.sql'

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
echo "🧹 Cleaning up old local backups..." # This line was already in English

# --- Cleanup by count ---
# Keeps the N most recent backups defined in NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT
if [ "${NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT}" -gt 0 ]; then
  echo "  🔎 Keeping the ${NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT} most recent local backups (by count)..."
  # List directories by date (newest first), skip the top N, and remove the rest.
  ls -1dt "${BACKUP_BASE}"/*/ 2>/dev/null | tail -n +$((NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT + 1)) | xargs -d '\n' rm -rf || true
else
  echo "  ℹ️ Local backup cleanup by count is disabled (NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT = ${NUM_LOCAL_BACKUPS_TO_KEEP_BY_COUNT})."
fi

# --- Cleanup by age ---
# Removes backups older than N days defined in NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS
if [ "${NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS}" -gt 0 ]; then
  echo "  📆 Removing local backups older than ${NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS} days..."
  find "${BACKUP_BASE}" -mindepth 1 -maxdepth 1 -type d -mtime +${NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS} -exec rm -rf {} \;
else
  echo "  ℹ️ Local backup cleanup by age is disabled (NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS = ${NUM_LOCAL_BACKUPS_TO_KEEP_BY_DAYS})."
fi


# === Upload to Google Drive using rclone ===
echo "☁️ Uploading to Google Drive (${GDRIVE_FOLDER})..."
rclone copy "${LOCAL_BACKUP}" "${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/${TIMESTAMP}" --quiet

if [ $? -ne 0 ]; then
  echo "❌ Error uploading to Google Drive. Check rclone config."
  exit 1
fi

echo "✅ Backup uploaded to cloud."

echo "🧹 Cleaning up old remote backups (keeping ${NUM_REMOTE_BACKUPS_TO_KEEP} most recent)..."
REMOTE_DIR="${GDRIVE_REMOTE}:${GDRIVE_FOLDER}"

mapfile -t dirs_to_delete < <(
  rclone lsf --dirs-only --format "p" "${REMOTE_DIR}" \
    | sort -r \
    | tail -n +$((NUM_REMOTE_BACKUPS_TO_KEEP + 1))
)

if [ ${#dirs_to_delete[@]} -gt 0 ]; then
  echo "🔍 Found ${#dirs_to_delete[@]} old remote backup(s) to delete:"
  for dir_to_delete in "${dirs_to_delete[@]}"; do
    # Make sure dir_to_delete is not empty or just "/"
    if [[ -n "$dir_to_delete" && "$dir_to_delete" != "/" ]]; then
      echo "  🔥 Removing ${REMOTE_DIR}/${dir_to_delete}"
      rclone purge "${REMOTE_DIR}/${dir_to_delete}" --quiet # Añadí --quiet para consistencia con el upload
    else
      echo "  ⚠️ Skipping invalid directory name: '${dir_to_delete}'"
    fi
  done
  echo "✅ Remote cleanup completed."
else
  echo "✅ No old remote backups to remove."
fi

echo "✅ Backup and cleanup completed successfully!"
