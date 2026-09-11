# syntax=docker/dockerfile:1
FROM ghcr.io/foundry-rs/foundry:v1.2.1 AS foundry
FROM oven/bun:latest

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=foundry /usr/local/bin/forge /usr/local/bin/cast /usr/local/bin/anvil /usr/local/bin/
RUN mkdir -p /app /data && chown bun:bun /app /data
WORKDIR /app
USER bun

COPY --chown=bun:bun package.json bun.lock ./
# The committed lockfile omits two package.json TypeChain dependencies.
# Resolve those inside the image without rewriting the source lockfile.
RUN bun install --no-save
COPY --chown=bun:bun foundry.toml remappings.txt soldeer.lock ./
RUN forge soldeer install
COPY --chown=bun:bun src/ src/
COPY --chown=bun:bun script/ script/
COPY --chown=bun:bun test/ test/
COPY --chown=bun:bun index.ts tsconfig.json tsup.config.ts config.ts ./
# Download the pinned compiler and compile during the network-enabled build.
# Runtime deployment and tests then work without internet access.
RUN forge build --via-ir
COPY --chown=bun:bun types/ types/
COPY --chown=bun:bun docker/ docker/

EXPOSE 8545
CMD ["bun", "docker/local-stack.ts"]
