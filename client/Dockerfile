# =============================================================================
# Stage 1: Install dependencies
# =============================================================================
FROM node:24-alpine AS deps

WORKDIR /app
COPY client/package.json client/package-lock.json ./
RUN --mount=type=cache,id=npm-client,target=/root/.npm \
    npm ci --prefer-offline

# =============================================================================
# Stage 2: Build Next.js (standalone output)
# =============================================================================
FROM node:24-alpine AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY client/ .

# NEXT_PUBLIC_* vars are baked at build time — pass via --build-arg in CI
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_APP_NAME

ENV NEXT_TELEMETRY_DISABLED=1
# Skip TS + ESLint during docker build — already checked in lint-client CI job
ENV DOCKER_BUILD=1

RUN --mount=type=cache,id=nextjs-client,target=/app/.next/cache \
    npm run build

# =============================================================================
# Stage 3: Minimal production runner
# =============================================================================
FROM node:24-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# Standalone output contains everything needed to run (no node_modules copy)
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
