# -----------------------
# STAGE 1: Build NestJS App (full deps)
# -----------------------
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy dependency definitions and install deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy all source code and build
COPY . .
RUN pnpm run build

# -----------------------
# STAGE 2: Runtime (production minimal image)
# -----------------------
FROM node:22-alpine AS runner

# Use non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Install pnpm runtime only (for pnpm node_modules layout)
RUN npm install -g pnpm

# Copy only what is needed
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# Set permissions
RUN chown -R appuser:appgroup /app
USER appuser

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/main"]
