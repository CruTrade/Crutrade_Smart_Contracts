.DEFAULT_GOAL := help
.NOTPARALLEL:

COMPOSE ?= docker compose

.PHONY: help build up start down restart logs status addresses test typecheck config reset

help:
	@printf '%s\n' \
	  'CruTrade local development' \
	  '  make up         Build with latest Bun and start the local stack' \
	  '  make start      Start the existing image and preserve saved state' \
	  '  make build      Build the image, refreshing base images' \
	  '  make down       Stop containers; preserve local state' \
	  '  make restart    Recreate containers using the existing image and saved state' \
	  '  make logs       Follow local stack logs (Ctrl-C to stop following)' \
	  '  make status     Show service status' \
	  '  make addresses  Print the deployed proxy address manifest' \
	  '  make test       Build and run offline Solidity and TypeScript lifecycle tests' \
	  '  make typecheck  Build and typecheck with Bun (known baseline errors remain)' \
	  '  make config     Validate Compose configuration' \
	  '  make reset      DELETE the local chain and deployment volume for this project' \
	  'Set CRUTRADE_RPC_PORT=18545 to override the host RPC port.'

build:
	$(COMPOSE) build --pull local

up: build
	$(COMPOSE) up -d --wait

start:
	$(COMPOSE) up -d --wait --no-build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d --wait --no-build

logs:
	$(COMPOSE) logs --follow --tail 100 local

status:
	$(COMPOSE) ps

addresses:
	$(COMPOSE) exec -T local bun -p 'require("/data/deployment.json")'

test: build
	$(COMPOSE) run --rm test

typecheck: build
	$(COMPOSE) run --rm test bunx --bun --no-install tsc --noEmit

config:
	$(COMPOSE) config --quiet

reset:
	$(COMPOSE) down --volumes
