# 17 — Operations

Operations here means deploying the contract set, upgrading an implementation, applying on-chain
configuration and publishing the npm package. There is no server, no container, no scheduler and no CI
in this repository; everything is run by a developer from a workstation with Foundry, Bun and a funded
key.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Prerequisites

| Tool | Verified version | Used for |
| --- | --- | --- |
| Foundry (`forge`, `cast`, `anvil`) | 1.2.1-stable | build, test, deploy, inspect |
| Bun | 1.4.2 | every `script/*.ts` |
| Node / npm | 26.8.2 | `npx typechain` inside the type generation step |

Install dependencies with `forge soldeer install` (Solidity, into `dependencies/`) and `bun install`
(JavaScript, into `node_modules/`).

## Runbook: local deployment

```bash
npm run anvil                 # terminal 1
npm run deploy:local          # terminal 2
```

`deploy:local` deploys `MockUSDC`, then the full stack, using the first Anvil key. Addresses are
printed and recorded in `broadcast/deploy.s.sol/31337/run-latest.json`.

## Runbook: testnet or mainnet deployment

1. Put `PRIVATE_KEY` in `.env`. Confirm the address is funded on the target chain.
2. Review `script/roles-config.ts` and `script/payments-config.ts` for the target environment. These
   are literal address tables, not environment-driven.
3. Run `forge script script/deploy.s.sol --rpc-url <rpc> --private-key <key> --broadcast --via-ir`
   with `NETWORK` set to `fuji` or `mainnet`, plus the env vars listed in `docs/13-configuration.md`.
   `npm run deploy:mainnet` does this for mainnet; `npm run deploy:testnet` passes the literal `fuji`,
   which `script/deploy.ts` rejects as an unknown network, so use `NETWORK=fuji bun script/deploy.ts testnet`
   or invoke `forge script` directly.
4. Apply the post-deployment configuration that the script does not perform:
   `Payments.setFiatFeePercentage`, `Payments.setServiceFee` for `LIST`/`BUY`/`WITHDRAW`/`RENEW`,
   `Payments.setMembershipFees`, `Sales.setDurations`, `Sales.setSchedules`,
   `Whitelist.addToWhitelist`. See `docs/13-configuration.md` for why each is needed.
5. Regenerate the package: `bun script/create-deployments.ts && bun script/update-package.ts`, then
   commit `index.ts` and `deployments/`.

Deployments are recorded only in `broadcast/`, which is gitignored and which `npm run clean` deletes.
Back it up before cleaning, or the address history is lost.

## Runbook: upgrading an implementation

1. Compile: `forge build --via-ir`.
2. Diff the layout: `forge inspect <Contract> storage-layout` against the deployed version. No base
   contract has a `__gap`, so any inserted variable is a corruption.
3. Prefer `Upgrades.upgradeProxy` from `@openzeppelin/foundry-upgrades`, which validates the layout.
   `script/safe-upgrade-v1.5.0-oz-foundry.s.sol` is the worked example. The other upgrade scripts call
   `upgradeToAndCall` directly with no validation.
4. Broadcast with a key holding `UPGRADER`.
5. Verify on Snowtrace and re-check the state the upgrade was meant to change. The existing scripts
   read `name()` and `tokenURI(1..3)` before and after as a smoke test.

`script/run-custom-upgrade.sh` automates step 1 and 4 for the Fuji `Wrappers` proxy.
`script/run-fuji-upgrade.sh` is broken; it references two files that do not exist.

## Runbook: rotating a role

`Roles.grantRole(role, newAddress)` then `Roles.revokeRole(role, oldAddress)`, both from the
`DEFAULT_ADMIN_ROLE` holder. Granting also repoints `getPrimaryAddress(role)` to the new address; if
the order is reversed, call `setPrimaryAddress` afterwards to fix the index. For a contract role, grant
the role to the new proxy and, if it needs to move assets or pull funds, also call `grantDelegateRole`
and `revokeDelegateRole` on the old one.

## Runbook: emergency stop

Call `pause()` on the affected contract from a `PAUSER` key. `Sales`, `Payments`, `Wrappers`,
`Brands`, `Whitelist` and `Memberships` all honour it; `Wrappers` and `Brands` also freeze ERC-721
transfers. `Payments.send` remains callable while paused. `Roles` exposes `pause()` but no function in
it is `whenNotPaused`, so pausing it changes nothing.

## Runbook: publishing the package

`npm publish` triggers `prepublishOnly` -> `npm run build`. Because `tsup` runs before
`update-package.ts`, a single build bundles the previous `index.ts`. Run `npm run build` twice, or run
`bun script/update-package.ts` followed by `npx tsup`, before publishing. `npm run test-package`
validates the resulting tarball end to end.

## Debugging

| Symptom | First check |
| --- | --- |
| `NotAllowed(role, account)` | `Roles.hasRole(role, account)`; for a script, whether `PRIVATE_KEY` is the intended signer |
| `NotAllowedDelegate` | `Roles.hasDelegateRole(caller)` |
| `NotWhitelisted` | `Whitelist.isWhitelisted(wallet)` |
| `InvalidNonce` | `getNonce(wallet)` on the target contract, not on `Roles` |
| `InvalidSignature` | the domain name for that contract, and `getDomainSeparator()` |
| `SaleNotStarted` | `Sales.getNextScheduleTime()` and `getSale(id).start` |
| A script cannot find an address | `broadcast/deploy.s.sol/<chainId>/run-latest.json` exists for that chain |
| A script cannot find an ABI | `forge build` has been run and `out/<Name>.sol/<Name>.json` exists |

`cast call`, `cast send` and `cast logs` against a deployed proxy are the fastest way to confirm on-chain
state; the proxy address is the one to use, not the implementation.

## Not implemented

- No CI or CD. No `.github/`, no pipeline configuration anywhere in the repository.
- No Dockerfile, container image, systemd unit or hosting configuration.
- No monitoring, metrics, alerting or health checks.
- No structured logging. Scripts print to stdout with emoji prefixes.
- No contract verification step in the deploy path. Only `script/run-custom-upgrade.sh` passes
  `--verify`.
- No timelock, no upgrade queue, no rollback script. Rolling back means upgrading to the previous
  implementation address manually.
- No secret rotation tooling. `PRIVATE_KEY` is read from the environment; rotating it is a manual role
  grant and revoke as above.
- No persisted deployment history in git: `deployments/` and `broadcast/` are both gitignored, and
  `deployments/` does not exist in this checkout.

## Open questions / unverified

- `broadcast/` in this checkout contains only chain `31337`, so the mainnet and testnet addresses in
  `index.ts` cannot be re-derived here and their provenance is not recoverable from the repository.
- `script/init.ts` performs a different post-deployment setup (USDT rather than USDC, hardcoded
  addresses) and is not referenced by any npm script. Whether it is still the intended initializer is
  not determinable from the code.
