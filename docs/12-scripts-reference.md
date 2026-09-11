# 12 — Scripts reference

All operational tooling lives in `script/`. Foundry scripts (`*.s.sol`) are run with `forge script`;
CLI tools (`*.ts`) are run with Bun. Several of them send real transactions when pointed at mainnet.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## npm scripts (`package.json`)

| Script | Command | Effect |
| --- | --- | --- |
| `build` | `forge build --via-ir && tsup && generate-types && create-deployments && update-package` | full package build; rewrites `index.ts`, `types/`, `deployments/` |
| `test` | `forge test` | Foundry suite |
| `test-package` | `bun script/test-package.ts` | packs and installs the package into `/tmp`, then smoke-tests it |
| `clean` | `rm -rf dist out cache broadcast` | discards build output **and the broadcast history** |
| `anvil` | `anvil --host 127.0.0.1 --port 8545 --chain-id 31337` | local chain |
| `deploy:local` / `deploy:testnet` / `deploy:mainnet` | `bun script/deploy.ts <network>` | full ecosystem deployment |
| `generate-types`, `create-deployments`, `update-package` | individual build steps | each overwrites tracked files |
| `prepublishOnly` | `npm run build` | runs on `npm publish` |

## Deployment

### `script/deploy.ts`

Entry point for all three networks. Reads the network from `argv[2]` or `NETWORK` (default `local`),
loads `script/roles-config.ts` and `script/payments-config.ts`, overrides the payments treasury with
the roles treasury, validates both configurations, prints them with any security warnings, then runs:

```
forge script script/deploy.s.sol --rpc-url <rpc> --private-key <key> --broadcast --via-ir
```

with `NETWORK`, `USDC_ADDRESS`, the roles env vars and the payments env vars injected. It exits 1 on an
unknown network, a missing `PRIVATE_KEY`, or a failed validation.

Note that this file carries its own chain map (`local`, `testnet`, `mainnet`) that does not include
`fuji`, while `npm run deploy:testnet` passes `fuji`. The literal argument `fuji` therefore falls
through to "Unknown network" in `deploy.ts`, even though `deploy.s.sol` understands it.

### `script/deploy.s.sol` — `CrutradeDeploy`

`run()` branches on `NETWORK`: `mainnet` uses mainnet USDC, `fuji` uses Fuji USDC, anything else
deploys `MockUSDC` and uses the first Anvil key. The sequence is described in
`docs/02-architecture.md`. Required env: `PRIVATE_KEY` (non-local), `OWNER`, `OPERATIONAL_1`,
`OPERATIONAL_2`, `TREASURY_ADDRESS`, `FIAT_FEE_PERCENTAGE`, `MEMBERSHIP_FEES`.

`_parseMembershipFees` ignores the `MEMBERSHIP_FEES` JSON it is handed and returns a hardcoded pair
(tier 0 at 600/400 bps, tier 1 at 100/100 bps). Membership fees configured in
`script/payments-config.ts` do not reach the chain; set them afterwards with `setMembershipFees`.

### `script/init.ts`

A post-deployment initializer that reads `deployments/<network>/latest.json` and, using hardcoded admin
and operational addresses, grants the six user roles, registers USDT as a payment token with 6 decimals,
sets it as the default fiat token, and registers one brand. Network comes from `NODE_ENV === 'dev'`,
and RPC from `RPC_DEV` or `RPC`.

This script is not wired into any npm script and its USDT addresses differ from the USDC addresses used
by `deploy.ts`. Treat it as legacy unless verified against the target deployment.

## Upgrades

| Script | Mechanism | Target |
| --- | --- | --- |
| `script/safe-upgrade-v1.5.0-oz-foundry.s.sol` | `Upgrades.upgradeProxy` from `@openzeppelin/foundry-upgrades`, with layout validation | Fuji `Wrappers` proxy `0x75D8…09aa` |
| `script/safe-upgrade-v1.5.0-custom.s.sol` | manual `upgradeToAndCall`, no validation | same |
| `script/safe-upgrade-v1.5.0.s.sol` | manual `upgradeToAndCall`, no validation | same |
| `script/fuji-upgrade.s.sol` | deploy implementation, `upgradeToAndCall`, then `setHttpsBaseURI` | same |

All four hardcode the Fuji proxy address and the base URI
`https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/`. Prefer the OpenZeppelin variant: it is the
only one that validates the storage layout.

`script/run-custom-upgrade.sh` wraps the custom variant (`forge clean`, `forge build --skip test`,
`forge script … --broadcast --verify`) and requires `PRIVATE_KEY` and `FUJI_RPC` in `.env`.
`script/run-fuji-upgrade.sh` is broken: it invokes `script/fuji-storage-fix.s.sol` and
`script/verify-fuji-fix.ts`, neither of which exists.

## Configuration tools

### `script/configure-schedules.ts`

```
bun run script/configure-schedules.ts read
bun run script/configure-schedules.ts write            # default mode
bun run script/configure-schedules.ts delete <id> [id…]
NETWORK=mainnet bun run script/configure-schedules.ts read
```

Reads, writes or deactivates `Sales` schedules. Per-network schedule definitions and a timezone table
(GMT-8 through GMT+9) live at the top of the file; times are converted to UTC before being written.
Delete mode prints the current schedules and asks for interactive confirmation.

### `script/configure-usdc-proxy.ts`

```
bun script/configure-usdc-proxy.ts <production|staging|testnet> <action> [args]
```

Actions: `deploy`, `set-usdc <address>`, `set-payments <address>`, `get-config`,
`permit-usdc <owner> <spender> <value> <deadline> <v> <r> <s>`,
`permit-payments <owner> <value> <deadline> <v> <r> <s>`, `get-allowance <owner> <spender>`.
`approve-usdc` and `approve-payments` are recognized and rejected with guidance, because the contract
no longer exposes approve functions. Requires `PRIVATE_KEY`. The address tables at the top of the file
(`USDC_PROXY_ADDRESSES`, `PAYMENTS_ADDRESSES`) are empty, so address resolution falls back to the
Foundry broadcast file.

### `script/set-wrapper-base-uri.ts`

```
bun script/set-wrapper-base-uri.ts <production|staging|testnet> [newBaseURI]
```

Calls `Wrappers.setHttpsBaseURI`. Without an explicit URI it uses the per-environment default from the
file. Requires `PRIVATE_KEY` holding `OWNER`; it decodes the `NotAllowed` selector and explains the
missing role on failure.

### `script/configure-roles.ts` and `script/configure-payments.ts`

Read-only demonstrations. They print and validate the configurations from `roles-config.ts` and
`payments-config.ts` for every environment, including deliberately invalid examples. They send no
transactions.

## Utilities

### `script/fetch-wrapper-events.ts`

```
bun run script/fetch-wrapper-events.ts [fromBlock] [toBlock] [eventTypes…]
```

Queries Avalanche mainnet for `Import`, `Export`, `MarketplaceTransfer`, `BatchTransfer` and `Transfer`
logs from the `Wrappers` contract and prints them. Loads the ABI from `out/Wrappers.sol/Wrappers.json`,
so `forge build` must have run. The contract address is a module constant marked `TODO` in the source.

### `script/generate-artifacts.sh`

Writes `dist/<Contract>.json` by running `forge inspect` for seven contracts. It appends bytecode,
deployed bytecode and method identifiers after the ABI in the same file, which produces invalid JSON.
Nothing in `package.json` calls it.

## Shared configuration modules

| File | Exports |
| --- | --- |
| `script/network-config.ts` | `NETWORK_CONFIGS`, `getNetworkConfig`, `getNetwork`, `validateNetworkConfig` |
| `script/roles-config.ts` | per-environment `RoleConfig`, validation, `checkSecurityIssues`, `generateEnvVars` |
| `script/payments-config.ts` | per-environment `PaymentsConfig`, validation, printing |
| `script/config.ts` | legacy role/contract table; imports the broken root `config.ts` |

## Open questions / unverified

- `script/network-config.ts` exports a clean network abstraction but only `configure-usdc-proxy.ts`-era
  code paths use it; `deploy.ts` and `configure-schedules.ts` each carry their own chain map.
- `script/config.ts` lists a `roles` entry whose `hex` value is an ASCII string padded to 32 bytes
  rather than a `keccak256` hash, and references six contracts that do not exist in `src/`.
