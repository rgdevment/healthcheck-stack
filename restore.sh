#!/bin/bash
set -euo pipefail

# === CONFIG ===
BACKUP_LOCAL="./backups"
REMOTE_NAME="gdrive"
REMOTE_PATH="Backups/system/apirest-health"
MYSQL_USER="root"
CONTAINER_DB="mariadb"
CONTAINER_REDIS="redis"
CONTAINER_GRAFANA="grafana"

echo "🌐 Select source:"
select SOURCE in "Local" "Google Drive"; do
  if [[ -n "$SOURCE" ]]; then
    break
  fi
done

if [[ "$SOURCE" == "Local" ]]; then
  echo "📁 Local backups:"
  select BACKUP_FOLDER in $(ls -1 "$BACKUP_LOCAL"); do
    if [[ -n "$BACKUP_FOLDER" ]]; then break; fi
  done
  FULL_PATH="${BACKUP_LOCAL}/${BACKUP_FOLDER}"

else
  echo "☁️ Fetching backups from Google Drive..."
  OPTIONS=$(rclone lsd "${REMOTE_NAME}:${REMOTE_PATH}" --max-depth 1 | awk '{print $NF}')
  select BACKUP_FOLDER in $OPTIONS; do
    if [[ -n "$BACKUP_FOLDER" ]]; then break; fi
  done
  FULL_PATH="${BACKUP_LOCAL}/${BACKUP_FOLDER}"
  echo "⬇️ Downloading $BACKUP_FOLDER from Drive..."
  mkdir -p "$FULL_PATH"
  rclone copy "${REMOTE_NAME}:${REMOTE_PATH}/${BACKUP_FOLDER}" "$FULL_PATH" --progress
fi

echo "🔄 Restoring from: $FULL_PATH"

# === MariaDB ===
if [[ -f "$FULL_PATH/mariadb.sql" ]]; then
  echo "📦 Restoring MariaDB..."
  cat "$FULL_PATH/mariadb.sql" | docker exec -i "$CONTAINER_DB" sh -c "mysql -u$MYSQL_USER -p\"\$MYSQL_ROOT_PASSWORD\""
else
  echo "⚠️  No mariadb.sql found"
fi

# === Redis ===
if [[ -f "$FULL_PATH/redis.rdb" ]]; then
  echo "📦 Restoring Redis..."
  docker cp "$FULL_PATH/redis.rdb" "$CONTAINER_REDIS":/data/dump.rdb
  docker restart "$CONTAINER_REDIS"
else
  echo "⚠️  No redis.rdb found"
fi

# === Grafana ===
if [[ -d "$FULL_PATH/grafana" ]]; then
  echo "📦 Restoring Grafana..."
  docker exec "$CONTAINER_GRAFANA" sh -c "mv /var/lib/grafana /var/lib/grafana.bak_$(date +%s) || true"
  docker cp "$FULL_PATH/grafana" "$CONTAINER_GRAFANA":/var/lib/grafana
  docker restart "$CONTAINER_GRAFANA"
else
  echo "⚠️  No grafana folder found"
fi

echo "✅ Restore complete."
