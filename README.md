# healthcheck-stack

Infraestructura local autosustentada para exponer API's publicas opensource desde tu propio equipo, sin necesidad de pagar servicios en la nube.

Este stack funciona sobre Docker en equipos ARM64 (como Mac M1/M2/M4), usando Cloudflare Tunnel para exponer servicios de manera segura y sin abrir puertos.

## Caracteristicas

- API healthcheck accesible en HTTPS desde `status.apirest.cl`
- Exposicion de metricas Prometheus en `/metrics`
- Acceso a Grafana por `grafana.apirest.cl`
- MongoDB, Redis y MariaDB locales
- Monitoreo y dashboards sin depender de ningun proveedor externo
- Listo para escalar agregando más API's con subdominios adicionales

## Estructura del stack

- `healthcheck-api`: API en NestJS con endpoints `/`, `/ping`, `/metrics`, `/status/*`
- `grafana`: interfaz visual de monitoreo
- `prometheus`: recolección de metricas de la API
- `cloudflared`: tunel hacia Cloudflare
- `mongo-db`, `redis`, `mariadb`: servicios internos compartidos

## Requisitos

- Docker + Docker Compose
- Cuenta en Cloudflare
- Dominio propio gestionado en Cloudflare (ej: apirest.cl)

## Instalacion y configuracion

1. Clona el repositorio

2. Crea archivo `.env` en `healthcheck-stack/`:

   MYSQL_ROOT_PASSWORD=supersecret  
   MYSQL_DATABASE=healthcheck  
   GF_SECURITY_ADMIN_PASSWORD=admin

3. Crea un tunel en Cloudflare Zero Trust
    - Nombre sugerido: `apirest-ping-tunnel`
    - Elige opcion "Docker / Other device"
    - Copia el token generado

4. Edita `docker-compose.yml` y reemplaza:

   TUNNEL_TOKEN=tu-token-aqui

5. Ejecuta:

   docker-compose up -d --build

6. En Cloudflare Dashboard agrega public hostnames:

    - `status.apirest.cl` -> http://healthcheck-api:3000
    - `grafana.apirest.cl` -> http://grafana:3000

## Endpoints disponibles

- `https://status.apirest.cl/` → Respuesta de ping
- `https://status.apirest.cl/metrics` → Metricas Prometheus
- `https://status.apirest.cl/status/mongo`, `/status/db`, `/status/redis`...
- `https://grafana.apirest.cl/` → Interfaz grafica

## Acceso por defecto a Grafana

Usuario: admin  
Clave: admin

(Se puede cambiar desde `.env` o interfaz)

## Agregar nuevas APIs

1. Crear nueva carpeta `my-api/`
2. Definir servicio en `docker-compose.yml`
3. Agregar `public hostname` en Cloudflare para exponerla
4. Compartir recursos internos si es necesario (DB, Redis, etc)

## Estado actual

- Mongo y MariaDB no se conectan aún (ver /status/mongo y /status/db)
- Pendiente: depuración de variables de entorno para estas conexiones

## Contribuir

Este proyecto es opensource y busca entregar API's públicas sin costo.  
Si quieres aportar ideas, API's o integraciones, bienvenido.

## Licencia

MIT - Rodrigo Hidalgo / rgdevment
