# 13 — Configuration

Configuration arrives from three places: environment variables read by the Bun scripts and by
`forge script`, TypeScript constant tables under `script/`, and on-chain values written after
deployment. This chapter lists every key with the file and line that reads it.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Environment variables

| Name | Type | Default | Required | Read at | Affects |
| --- | --- | --- | --- | --- | --- |
| `PRIVATE_KEY` | hex key | none | yes, except local | `script/deploy.ts:39`, `script/init.ts:49`, `script/network-config.ts:33`, `script/configure-usdc-proxy.ts:417`, `script/set-wrapper-base-uri.ts:141`, `script/deploy.s.sol:106` | signer for every transaction |
| `NETWORK` | `local` \| `testnet` \| `fuji` \| `mainnet` | `local` | no | `script/deploy.ts:52`, `script/deploy.s.sol:81`, `script/configure-schedules.ts:73`, `script/network-config.ts:72` | chain, RPC, config tables |
| `NODE_ENV` | `dev` or other | none | no | `script/init.ts:9`, `script/config.ts:4`, `config.ts:8` | testnet vs mainnet in the legacy scripts |
| `TESTNET_RPC` | URL | Fuji public RPC | no | `script/network-config.ts:31`, `script/configure-schedules.ts:58` | Fuji endpoint |
| `MAINNET_RPC` | URL | Avalanche public RPC | no | `script/network-config.ts:45`, `script/configure-usdc-proxy.ts:141`, `script/set-wrapper-base-uri.ts:8` | mainnet endpoint |
| `FUJI_RPC` | URL | Fuji public RPC | no | `script/configure-usdc-proxy.ts:148`, `script/set-wrapper-base-uri.ts:10`, `script/run-fuji-upgrade.sh`, `script/run-custom-upgrade.sh` | Fuji endpoint for the upgrade and config tools |
| `RPC`, `RPC_DEV` | URL | none | yes for `init.ts` | `script/init.ts:11`, `config.ts:9` | endpoint for the legacy initializer |

Set by `script/deploy.ts` and consumed by `script/deploy.s.sol` through `vm.env*`:

| Name | Source | Read at | Affects |
| --- | --- | --- | --- |
| `USDC_ADDRESS` | network table in `deploy.ts` | passed through, not read by `deploy.s.sol` | — |
| `OWNER` | `roles-config.ts` | `deploy.s.sol:178,247` | admin of `Roles`, first brand owner |
| `OPERATIONAL_1`, `OPERATIONAL_2` | `roles-config.ts` | `deploy.s.sol:248,249` | relayer hot wallets |
| `TREASURY`, `FIAT`, `PAUSER`, `UPGRADER` | `roles-config.ts` via `generateEnvVars` | not read by `deploy.s.sol` | all six user roles go to `OWNER` at deploy time |
| `TREASURY_ADDRESS` | `payments-config.ts`, overridden by the roles treasury | `deploy.s.sol:198` | `Payments` treasury fee wallet |
| `FIAT_FEE_PERCENTAGE` | `payments-config.ts` | `deploy.s.sol:199` | passed to `Payments.initialize`, which then fails to store it |
| `MEMBERSHIP_FEES` | `payments-config.ts` as JSON | `deploy.s.sol:200` | read but discarded by `_parseMembershipFees` |

`generateEnvVars` also emits `EMERGENCY_ADMIN`, `GOVERNANCE`, `PARTNER_1`, `PARTNER_2`, `LISTER`,
`BUYER`, `RENEWER` and `WITHDRAWER` when the corresponding optional fields are set. No Solidity code
reads any of them.

`.env.example` additionally documents `PRIVATE_KEY_FIAT`, `PRIVATE_KEY_TEST`, `PRIV_KEY_MINTER`,
`PRIV_KEY_RELAYER`, `PRIV_KEY_WHITELIST` and `PAYMENTS_CONTRACT`. None of these names is read anywhere
in the current code.

## Foundry configuration (`foundry.toml`)

| Key | Value | Effect |
| --- | --- | --- |
| `solc` | `0.8.30` | pinned, `auto_detect_solc = false` |
| `evm_version` | `cancun` | target EVM |
| `optimizer` / `optimizer-runs` | `true` / `200` | |
| `via_ir` | `true` | required; bytecode differs without it |
| `ffi` | `true` | Foundry scripts may shell out |
| `libs` | `lib`, `dependencies`, `node_modules` | soldeer output plus npm |
| `build_info`, `extra_output` | `true`, `["storageLayout"]` | needed by the OpenZeppelin upgrade validator |
| `fs_permissions` | read-write `./deployments`, read `./out` | file access for scripts |

Remappings (`remappings.txt`) point `@openzeppelin/contracts` and `@openzeppelin/contracts-upgradeable`
at the soldeer output in `dependencies/`, `@openzeppelin/foundry-upgrades` at `node_modules/`, and
`forge-std` at `dependencies/forge-std-1.9.7/src/`.

## TypeScript configuration tables

### `script/network-config.ts`

| Network | Chain id | USDC |
| --- | --- | --- |
| `local` | 31337 | none (MockUSDC deployed at runtime) |
| `testnet` / `fuji` | 43113 | `0x5425890298aed601595a70AB815c96711a31Bc65` |
| `mainnet` | 43114 | `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E` |

### `script/roles-config.ts`

Role-to-address tables per environment, plus validators. Every address is a literal in the file; there
is no environment-variable override despite the doc comments claiming one.

| Environment | Owner | Operational 1 / 2 | Treasury | Fiat |
| --- | --- | --- | --- | --- |
| local | Anvil #1 | Anvil #1 / `0x5Ad6…92eC` | Anvil #1 | Anvil #1 |
| testnet | `0x45a0…8cfb` | `0x5Ad6…92eC` / `0xe812…8085` | owner | operational 1 |
| mainnet | multisig `0xE8c2…45E9` | `0xd67E…9A56` / `0x4E19…b912` | multisig | operational 2 |

`checkSecurityIssues` warns when fewer than three unique addresses are used, when the owner holds more
than four roles, or when no emergency admin is set. Warnings do not block a deployment.

### `script/payments-config.ts`

Fiat surcharge and membership tiers per environment; see `docs/07-payments-fees.md` for the values.

## On-chain configuration after deployment

These are not set by any script and must be applied manually:

| Setting | Function | Why |
| --- | --- | --- |
| Service fees for `LIST`, `BUY`, `WITHDRAW`, `RENEW` | `Payments.setServiceFee` | never configured at deploy |
| Fiat fee percentage | `Payments.setFiatFeePercentage` | the initializer's assignment is a no-op |
| Membership tiers | `Payments.setMembershipFees` | the deploy script hardcodes different values |
| Sale durations beyond id 0 | `Sales.setDurations` | only `_durations[0] = 56 days` is seeded |
| Drop schedules | `Sales.setSchedules` | only the seed Saturday 15:30 UTC entry exists |
| Whitelist entries | `Whitelist.addToWhitelist` | empty at deploy |
| Additional brands | `Brands.register` | only brand 1 is created |

## Open questions / unverified

- `.env.example` contains a `PAYMENTS_CONTRACT` address that matches no address in `index.ts` and is
  read by no code. Its provenance is unknown.
- `script/roles-config.ts` documents that mainnet addresses come from environment variables, but the
  implementation uses hardcoded constants. The comment is stale.
