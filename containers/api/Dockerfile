# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json tsconfig.json ./
RUN npm ci

COPY src/ ./src/
RUN npm run build

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Create non-root user
RUN addgroup -S sandbox && adduser -S sandbox -G sandbox

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist ./dist

# Temp directory for code files
RUN mkdir -p /tmp/sandbox && chown sandbox:sandbox /tmp/sandbox

USER sandbox

EXPOSE 3000

CMD ["node", "dist/index.js"]
