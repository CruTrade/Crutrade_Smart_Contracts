---
paths:
  - "script/**"
---

# Rules for `script/**`

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

Two kinds of files live here: Foundry scripts (`*.s.sol`, run with `forge script`) and Bun CLI scripts
(`*.ts`, run with `bun script/<file>.ts`). Shell wrappers (`*.sh`) chain the two.

## Conventions

- Write new Bun scripts with a `#!/usr/bin/env bun` header and a `main().catch(...)` that calls
  `process.exit(1)`. Roughly half the existing files follow this; `script/deploy.ts` does neither and
  uses top-level `process.exit(1)` instead. Whatever the shape, a failure must exit non-zero, because
  the deploy pipeline chains on the exit code.
- Network selection comes from `process.env.NETWORK` or `process.argv[2]`. Canonical names are
  `local` (31337), `testnet`/`fuji` (43113) and `mainnet` (43114). `script/network-config.ts` is the
  shared source of truth; prefer importing `getNetworkConfig` over adding another inline chain map.
- Contract addresses are resolved from `broadcast/deploy.s.sol/<chainId>/run-latest.json` or from
  `deployments/<network>/latest.json`. ABIs come from `out/<Name>.sol/<Name>.json`, so `forge build`
  must have run first.
- Signing keys come from `process.env.PRIVATE_KEY` only. Never hardcode a key other than the well-known
  public Anvil keys that are already present for local runs.
- Configuration constants that differ per environment belong in `script/roles-config.ts`,
  `script/payments-config.ts` or `script/network-config.ts`, not inline in a command script.

## Writes to the repo

`script/update-package.ts`, `script/generate-types.ts` and `script/create-deployments.ts` overwrite
tracked files (`index.ts`, `types/**`, `deployments/**`). Run them only as part of `npm run build`
or when deliberately regenerating the package.

## Known broken references

Do not treat these as working entry points; either fix them or leave them alone:

- `script/run-fuji-upgrade.sh` calls `script/fuji-storage-fix.s.sol` and `script/verify-fuji-fix.ts`,
  neither of which exists.
- `script/run-custom-upgrade.sh` points at `script/verify-v1.5.0-upgrade.ts`, which does not exist. It
  only prints it in a closing "Next Steps" message, so the wrapper itself still succeeds.
- `script/config.ts` imports `../config`, which imports a missing `./logging/logger`, and references
  contracts (`CruToken`, `CruClub`, `Vesting`, `Presale`, `Drops`, `Referrals`) that are not in `src/`.
- `script/generate-artifacts.sh` appends bytecode after the ABI in the same file, producing invalid JSON.

## Mainnet actions

`configure-schedules.ts`, `configure-usdc-proxy.ts` and `set-wrapper-base-uri.ts` send real
transactions when `NETWORK=mainnet` or `production`. Never invoke them without an explicit request.
