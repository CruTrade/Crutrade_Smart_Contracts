# 10 — The TypeScript package

The repository publishes `@crutrade/contracts` (version 1.5.0 in `package.json`), a zero-logic package
carrying the ABIs, the deployed proxy addresses per network and TypeChain bindings. Consumers import it
instead of copying artifacts. Everything it ships is generated from the Foundry build output by
scripts in `script/`.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Exports

`index.ts` (generated) exports:

| Export | Shape |
| --- | --- |
| `abis` | `{ Roles, Brands, Wrappers, Whitelist, Payments, Sales, Memberships, USDCApprovalProxy }`, each `as const` |
| `addresses` | `{ mainnet: {...}, testnet: {...} }`, values typed as viem `Address` |
| `getContract(name, network)` | `{ address, abi }` for one contract on one network |
| default | `{ abis, addresses, getContract }` |

`package.json` maps the root entry to `dist/index.js` (CJS) and `dist/index.mjs` (ESM) with types from
`dist/index.d.ts`, and exposes a `./types` subpath pointing directly at `types/index.ts`. `files`
publishes `dist`, `deployments` and `types`. `viem` is declared `external` in `tsup.config.ts`, so it
is a peer requirement at runtime.

`types/index.ts` re-exports a typed contract interface and a `__factory` per contract, generated for
`ethers` v6 by TypeChain.

Usage matching the current export shape:

```ts
import { getContract, addresses } from '@crutrade/contracts';
import { Sales__factory } from '@crutrade/contracts/types';

const sales = getContract('Sales', 'testnet'); // { address, abi }
const typed = Sales__factory.connect(addresses.testnet.Sales, signer);
```

## Build pipeline

`npm run build` chains five steps:

| Step | Script | Writes |
| --- | --- | --- |
| 1 | `forge build --via-ir` | `out/`, `cache/` |
| 2 | `tsup` | `dist/` (CJS, ESM, d.ts) from `index.ts` |
| 3 | `script/generate-types.ts` | `types/` |
| 4 | `script/create-deployments.ts` | `deployments/{mainnet,testnet}/latest.json`, `deployments/index.json` |
| 5 | `script/update-package.ts` | `index.ts` |

The order is unusual: `tsup` bundles `index.ts` at step 2, but step 5 regenerates `index.ts`
afterwards. A single `npm run build` therefore produces a `dist/` built from the *previous* `index.ts`.
Running the build twice, or publishing through `prepublishOnly` after a prior build, masks this.

`script/generate-types.ts` copies each ABI from `out/<Name>.sol/<Name>.json` into a temporary
`temp-abi/` directory, runs `npx typechain --target ethers-v6 --out-dir types temp-abi/*.json`, then
removes the temporary directory.

`script/update-package.ts` inlines every ABI as JSON into a template string and writes `index.ts`,
which is why that file is roughly 142 KB.

## Address resolution

`script/create-deployments.ts` reads `broadcast/deploy.s.sol/<chainId>/run-latest.json` (43114 for
mainnet, 43113 for testnet), builds an implementation-to-proxy map from every `ERC1967Proxy` creation
by looking at the proxy's first constructor argument, then maps each known implementation name to its
proxy. Addresses already present in `deployments/<network>/latest.json` take precedence over the
derived ones. Anything unresolved becomes the zero address.

`USDCApprovalProxy` on mainnet is currently the zero address in `index.ts`, consistent with a mainnet
broadcast that predates that contract.

## Package self-test

`npm run test-package` (`script/test-package.ts`) builds, runs `npm pack`, installs the tarball into a
scratch directory under `/tmp`, then runs a runtime check over all eight contracts and a TypeScript
compilation that imports every `__factory`. It cleans up afterwards. It shells out to `npm run build`,
so it rewrites `index.ts` and `types/`.

## Open questions / unverified

- The root `config.ts` is a separate, older accessor that loads ABIs from `../contracts/out` and
  imports a `./logging/logger` module that does not exist in this repository. It is not part of the
  published `files` list and is the cause of the `npx tsc --noEmit` failure.
- `package.json` declares a `typechain` field pointing at `types/index.ts`; that key is not part of the
  npm schema and no tool in this repository reads it.
