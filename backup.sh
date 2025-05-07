#!/bin/bash
set -euo pipefail

# === Configuration ===
TIMESTAMP=$(date +"%Y-%m-%d-%H%M")
LOCAL_BACKUP="./backups/${TIMESTAMP}"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER="Backups/system/stack-monitoring"

# === Secure .env loader ===
load_env() {
  local env_file="${1:-.env}"

  if [[ ! -f "$env_file" ]]; then
    echo "❌ Environment fileenv_file' not found."
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

# === Upload to Google Drive using rclone ===
echo "☁️ Uploading to Google Drive (${GDRIVE_FOLDER})..."
rclone copy "${LOCAL_BACKUP}" "${GDRIVE_REMOTE}:${GDRIVE_FOLDER}/${TIMESTAMP}" --quiet

# === Optional: Cleanup old local backups (15+ days) ===
find ./backups -type d -mtime +15 -exec rm -rf {} \;

echo "✅ Backup completed and uploaded!"
