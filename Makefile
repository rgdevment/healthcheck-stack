# === Global Variables ===
ENV_FILE = .env
ENV_EXAMPLE = .env.example
STACK_NAME = internal-net
SHARED_LIBS_DIR = shared-libs

# === MYSQL EXPORTER FILES ===
init-secrets:
	@echo "🔐 Generando archivos de configuración reales desde variables .env..."
	@set -a && source .env && set +a && \
	envsubst '$$MYSQL_EXPORTER_PASSWORD' < mariadb/init/01-exporter-user.sql.example > mariadb/init/01-exporter-user.sql && \
	envsubst '$$MYSQL_EXPORTER_PASSWORD' < mariadb/mysqld_exporter.cnf.example > mariadb/mysqld_exporter.cnf
	@echo "✅ Archivos reales generados con variables sustituidas."

# === ENVIRONMENT ===
sync-env:
	@echo "📦 Syncing environment..."
	@test -f $(ENV_FILE) || (echo "⚠️  $(ENV_FILE) not found, creating from example"; cp $(ENV_EXAMPLE) $(ENV_FILE))
	@echo "✅ Environment ready."

verify-env:
	@echo "🔍 Comparing .env and .env.example..."
	@cmp --silent $(ENV_FILE) $(ENV_EXAMPLE) && echo "✅ No differences" || echo "❌ Files differ"

# === SHARED LIBRARIES ===
shared-libs:
	@echo "📦 Compiling shared libraries under $(SHARED_LIBS_DIR)/ ..."
	@for lib in $$(find $(SHARED_LIBS_DIR) -mindepth 1 -maxdepth 1 -type d); do \
		echo "🔧 Building $$lib..."; \
		cd $$lib && pnpm install --frozen-lockfile && pnpm run build && cd - >/dev/null; \
	done
	@echo "✅ Shared libraries compiled successfully!"

# === DOCKER INFRASTRUCTURE ===
ensure-network:
	docker network inspect $(STACK_NAME) >/dev/null 2>&1 || docker network create $(STACK_NAME)

up:
	@echo "🚀 Starting infrastructure stack..."
	docker compose up -d --build

down:
	@echo "💥 Stopping infrastructure stack and removing volumes..."
	docker compose down -v

restart-db:
	@echo "🔄 Restarting MariaDB only..."
	docker compose restart mariadb

clean:
	@echo "🧹 Cleaning Docker system..."
	docker system prune -af --volumes

logs:
	docker compose logs -f

status:
	@echo "📋 Docker container status:"
	docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "mariadb|redis|grafana|prometheus|cloudflared" || true

# === Adminer (uso opcional de emergencia) ===
adminer:
	@echo "🚀 Levantando Adminer en background (http://localhost:8080)..."
	docker compose up -d adminer
	@echo "✅ Adminer disponible en red interna, puerto 8080 (según tu red o túnel Cloudflare)"

down-adminer:
	@echo "🛑 Deteniendo y eliminando Adminer..."
	docker compose stop adminer
	docker compose rm -f adminer
	@echo "✅ Adminer detenido y eliminado"

# === COMPOSITE TARGETS ===
stack:
	@$(MAKE) sync-env
	@$(MAKE) init-secrets
	@$(MAKE) ensure-network
	@$(MAKE) up
	@$(MAKE) status

restart-stack:
	@echo "♻️  Restarting stack..."
	@$(MAKE) down
	@$(MAKE) up
	@$(MAKE) status

.PHONY: sync-env verify-env shared-libs ensure-network up down restart-db clean logs status adminer adminer-down stack restart-stack
