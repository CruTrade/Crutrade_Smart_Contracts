# syntax=docker/dockerfile:1
FROM ghcr.io/foundry-rs/foundry:v1.2.1 AS foundry
FROM oven/bun:1.4.2 AS bun
FROM node:26.8.2-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates git curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=foundry /usr/local/bin/forge /usr/local/bin/cast /usr/local/bin/anvil /usr/local/bin/
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun
RUN ln -s /usr/local/bin/bun /usr/local/bin/bunx \
    && mkdir -p /app /data && chown node:node /app /data
WORKDIR /app
USER node

COPY --chown=node:node package.json bun.lock ./
# The committed lockfile omits two package.json TypeChain dependencies.
# Resolve those inside the image without rewriting the source lockfile.
RUN bun install --no-save
COPY --chown=node:node foundry.toml remappings.txt soldeer.lock ./
RUN forge soldeer install
COPY --chown=node:node src/ src/
COPY --chown=node:node script/ script/
COPY --chown=node:node test/ test/
COPY --chown=node:node index.ts tsconfig.json tsup.config.ts config.ts ./
# Download the pinned compiler and compile during the network-enabled build.
# Runtime deployment and tests then work without internet access.
RUN forge build --via-ir
COPY --chown=node:node types/ types/
COPY --chown=node:node docker/ docker/

EXPOSE 8545
CMD ["node", "docker/local-stack.mjs"]
