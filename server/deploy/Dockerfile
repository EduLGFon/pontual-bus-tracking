# Pontual API container. Build from the repository root:
#   docker build -f server/deploy/Dockerfile -t pontual-api .
# Runtime configuration is environment-only; no secret enters the image.
# See DECISIONS.md D101 and docs/runbooks/docker.md.

# Build stage: cache the exact locked dependency graph and build the
# static data bundle from the source of truth in data/.
FROM denoland/deno:2.9.8 AS build

WORKDIR /app
ENV DENO_DIR=/deno-dir

COPY server/deno.json server/deno.lock ./server/
COPY server/src ./server/src
RUN cd server && deno cache --frozen-lockfile src/main.ts

COPY tools/deno.json ./tools/deno.json
COPY tools/data ./tools/data
COPY tools/route ./tools/route
COPY data ./data
RUN cd tools && deno task data-build

# Runtime stage. The official image already provides a non-root deno user
# and tini as PID 1 for signal handling.
FROM denoland/deno:2.9.8 AS runtime

WORKDIR /app/server

# The cache is read-only at runtime; --cached-only in start:container
# prevents a network fetch if a dependency is ever missing.
COPY --from=build --chown=deno:deno /deno-dir /deno-dir
COPY --from=build --chown=deno:deno /app/server /app/server
COPY --from=build --chown=deno:deno /app/build /app/build

# Container-safe defaults. APP_ENV, DATABASE_URL, ALLOWED_ORIGINS,
# TRUST_CLOUDFLARE, LOG_LEVEL and LEARNING_PRIVACY_MODE come from the
# environment; HOST must be 0.0.0.0 inside the container and is published
# on the host loopback only by compose.
ENV DENO_DIR=/deno-dir \
    HOST=0.0.0.0 \
    PORT=8080 \
    DATA_DIR=/app/build \
    METRICS_PORT=127.0.0.1:9091

USER deno
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD ["deno", "eval", "--quiet", "--no-config", "--allow-net=127.0.0.1:8080", "const r = await fetch('http://127.0.0.1:8080/v1/health'); if (!r.ok) Deno.exit(1);"]

# The base image entrypoint maps deno subcommands; start:container pins
# the runtime permission set (no write, run, ffi or sys access).
CMD ["task", "start:container"]
