# healthcheck-stack

Infraestructura local autosustentada para exponer API's públicas opensource desde tu propio equipo, sin necesidad de pagar servicios en la nube.

Este stack funciona sobre Docker en equipos ARM64 (como Mac M1/M2/M4), usando Cloudflare Tunnel para exponer servicios de manera segura y sin abrir puertos.

## Caracteristicas

- API healthcheck accesible en HTTPS desde `status.apirest.cl`
- Exposición de métricas Prometheus en `/metrics`
- Acceso a Grafana por `grafana.apirest.cl`
- MongoDB, Redis y MariaDB locales
- Monitoreo y dashboards sin depender de ningún proveedor externo
- Listo para escalar agregando más APIs con subdominios adicionales

## Estructura del stack

- `healthcheck-api`: API en NestJS con endpoints `/`, `/ping`, `/metrics`, `/status/*`
- `grafana`: interfaz visual de monitoreo
- `prometheus`: recolección de métricas de la API
- `cloudflared`: túnel hacia Cloudflare
- `mongo-db`, `redis`, `mariadb`: servicios internos compartidos

## Requisitos

- Docker + Docker Compose
- Cuenta en Cloudflare
- Dominio propio gestionado en Cloudflare (ej: apirest.cl)

## Instalación y configuración

1. Clonar el repositorio

2. Crear archivo `.env` en `healthcheck-stack/`:

   MYSQL_ROOT_PASSWORD=supersecret  
   MYSQL_DATABASE=healthcheck  
   GF_SECURITY_ADMIN_PASSWORD=admin

3. Crear un túnel en Cloudflare Zero Trust
   - Nombre sugerido: `apirest-ping-tunnel`
   - Elegir opción "Docker / Other device"
   - Copiar el token generado

4. Editar `docker-compose.yml` y reemplazar:

   TUNNEL_TOKEN=tu-token-aqui

5. Ejecutar:

   make stack

6. En Cloudflare Dashboard agregar public hostnames:

   - `status.apirest.cl` → http://healthcheck-api:3000
   - `grafana.apirest.cl` → http://grafana:3000

## Endpoints disponibles

- `https://status.apirest.cl/` → Resumen general de servicios
- `https://status.apirest.cl/ping` → Ping directo
- `https://status.apirest.cl/metrics` → Métricas Prometheus
- `https://status.apirest.cl/status/mongo`, `/status/db`, `/status/redis`, etc.
- `https://grafana.apirest.cl/` → Interfaz gráfica

## Acceso por defecto a Grafana

Usuario: admin  
Clave: admin  
(Se puede cambiar desde `.env` o desde la interfaz)

## Comandos de desarrollo

Este proyecto incluye un `Makefile` para facilitar operaciones comunes:

Comando          | Descripción
-----------------|----------------------------------------------
make stack       | Sincroniza .env, levanta servicios y muestra estado
make sync-env    | Copia `.env` raíz a `healthcheck-api/.env`
make up          | Build y levantamiento completo con Docker
make down        | Apaga contenedores y elimina volúmenes
make restart-api | Reinicia solo el servicio `healthcheck-api`
make status      | Muestra estado de contenedores importantes
make check       | Consulta el estado desde `status.apirest.cl`
make verify-env  | Verifica si `.env` y `healthcheck-api/.env` son idénticos
make clean       | Limpia volúmenes, redes y cachés de Docker

## Agregar nuevas APIs

1. Crear nueva carpeta `my-api/`
2. Definir servicio en `docker-compose.yml`
3. Agregar `public hostname` en Cloudflare para exponerla
4. Compartir recursos internos si es necesario (DB, Redis, etc)

## Contribuir

Este proyecto es opensource y busca entregar API's públicas sin costo.  
Si quieres aportar ideas, APIs o integraciones, bienvenido.
