# Stack Monitoring

Este stack Dockerizado permite monitorear la infraestructura de tus servicios y APIs usando Prometheus, Grafana, Redis Exporter y otros componentes clave.

## 📦 Servicios incluidos

| Servicio       | Rol principal                                   |
| -------------- | ----------------------------------------------- |
| mariadb        | Base de datos relacional                        |
| redis          | Cache en memoria de alta velocidad              |
| redis-exporter | Exposición de métricas de Redis para Prometheus |
| prometheus     | Recolección y almacenamiento de métricas        |
| grafana        | Visualización de métricas                       |
| cloudflared    | Exposición segura mediante Cloudflare Tunnel    |

## 🧱 Estructura del proyecto

```
/opt/stack-monitoring/
├── docker-compose.yml
├── .env                         # Variables de entorno
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/         # Configuración de Prometheus como datasource
│   │   └── dashboards/          # Instrucciones de carga automática
│   └── exported-dashboards/     # Dashboards JSON autoload
├── prometheus/
│   └── prometheus.yml           # Configuración de scraping
├── redis/
│   └── redis.conf               # Configuración custom de Redis
├── backups/                     # Respaldos automáticos diarios
└── logs/                        # Logs opcionales por servicio
```

## 🚀 Primer uso

```bash
cd /opt/stack-monitoring
cp .env.example .env
make sync-env
make up
```

## 🔄 Comandos útiles

| Acción                  | Comando              |
| ----------------------- | -------------------- |
| Iniciar stack           | make up              |
| Detener stack           | make down            |
| Ver logs de API         | make logs            |
| Iniciar Adminer (MySQL) | make adminer         |
| Ver estado              | make status          |
| Restaurar desde backup  | ./scripts/restore.sh |

## 🛡️ Seguridad y monitoreo

- Redis corre en modo read-only (excepto /data) y con configuración personalizada.
- Grafana, Prometheus y Redis Exporter están aislados en red interna.
- Cloudflared permite acceso seguro al stack sin exponer puertos.

## 📊 Dashboards

Grafana se auto-configura con dashboards para:

- Redis (via Redis Exporter)
- Prometheus internals
- MariaDB (si usas mysqld-exporter más adelante)

Puedes encontrar los dashboards en `grafana/exported-dashboards/monitoring`.

## 📥 Respaldos

- Incluye scripts para realizar respaldos de MariaDB, Redis y Grafana
- Integración con Google Drive opcional vía rclone
- Restauración automática guiada desde backups locales o Drive

## 🧩 Requisitos

- Docker + Docker Compose
- rclone configurado si usas backup en Google Drive
