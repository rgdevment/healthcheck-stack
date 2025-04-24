# STAGE 1: Build NestJS App (instala todo para poder compilar)
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
RUN npx nest build

# STAGE 2: Runtime (Light but reasonable production)
FROM node:22-alpine AS runner

WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Env vars Node performance
ENV NODE_ENV=production

EXPOSE 3000
CMD ["node", "dist/main"]
