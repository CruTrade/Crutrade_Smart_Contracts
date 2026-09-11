# CruTrade Smart Contracts

Solidity contracts for the CruTrade marketplace on Avalanche: physical luxury goods are represented
by wrapper NFTs, listed through `Sales`, and paid for through `Payments`. The repository also builds
`@crutrade/contracts`, containing ABIs, network addresses and ethers v6 TypeChain bindings.

This repository contains **contracts and CLI tools**. It does not include a frontend, backend relayer,
database or metadata server. The commands below start the complete on-chain stack. The Foundry tests
provide marketplace fixtures and signed transaction examples.

## Quick start with Docker

Requires Git and Docker with Compose v2 or later. From an existing checkout, skip the clone step.

```bash
git clone git@github.com:CruTrade/Crutrade_Smart_Contracts.git
cd Crutrade_Smart_Contracts
docker compose build --pull
docker compose up -d --wait
docker compose logs local
```

The clone command requires GitHub SSH access. The first image build downloads the toolchain,
dependencies and Solidity compiler and compiles the contracts; subsequent builds reuse Docker layers.
No host Foundry, Bun, Node or `.env` is required.

When the service becomes healthy:

- Anvil is available at **http://127.0.0.1:8545**, chain ID **31337**.
- `MockUSDC`, eight implementations and eight ERC1967 proxies have been deployed automatically.
- Contract roles and delegation flags are configured. The first public Anvil account is the admin
  and also holds `OPERATIONAL`; real signing keys are not used.
- Logs contain the **proxy addresses**. The named volume contains `anvil.json`, `deployment.json`
  and `broadcast.json`. Use proxies, not implementation addresses, for application calls.

```bash
# Read the local address manifest and check the chain.
docker compose exec local bun -p 'require("/data/deployment.json")'
docker compose exec local cast chain-id --rpc-url http://127.0.0.1:8545

# Run Foundry and Docker startup regression tests in a disposable, offline container.
docker compose run --rm test

# Inspect startup problems, stop, or restart with the saved state.
docker compose logs --tail 100 local
docker compose down
docker compose up -d --wait
```

State survives `down` and container recreation. Startup verifies the saved proxy addresses and reuses
the deployment. It fails on inconsistent state instead of silently deploying a second stack.
Source changes require `docker compose build`; existing proxies still use their deployed code.
For a fresh deployment of changed contracts, explicitly reset the local volume:

```bash
# Destructive: deletes this Compose project's local chain and deployment records.
docker compose down --volumes
docker compose up --build -d --wait
```

If port 8545 is occupied, prefix the startup command with `CRUTRADE_RPC_PORT=18545`; the host RPC
then uses port 18545. Containers still use 8545. Only loopback is published, the runtime network is
internal, and the test service has no network. The Docker build context is allowlisted by
`.dockerignore`: no host `.env`, Git history, dependency caches, home directory or Docker socket is
copied or mounted. The state volume contains local development data only.

## Native development setup

Use this path when editing contracts frequently. Run all commands from the repository root.
Install Foundry (`forge`, `cast`, `anvil`) and the latest stable Bun first. The Dockerfile pins Foundry
**1.2.1** and uses **`oven/bun:latest`**, with no Node.js runtime. `docker compose build --pull`
refreshes the Bun base image. Solidity is pinned to **0.8.30** and targets Cancun with `via_ir = true`.

```bash
forge --version
bun --version

forge soldeer install
bun install --no-save

forge build --via-ir
forge test
bunx --bun --no-install tsc --noEmit
```

Solidity dependencies go into `dependencies/`; JavaScript dependencies go into `node_modules/`.
The committed Bun lockfile omits two TypeChain dependencies listed in `package.json`. `--no-save`
installs the missing dependencies without rewriting that lockfile; Docker uses the same workaround.
Those missing entries are resolved from package ranges, so dependency installation is not fully
reproducible until the lockfile is reconciled in a separate change.
The initial compile can take longer; later builds reuse `cache/`. Tests need neither `.env` nor Anvil.

The native verification on 2026-09-11 returned **115 passing tests**. TypeScript currently fails with
three existing diagnostics: the missing `./logging/logger` import in `config.ts:4` and two
unknown-error accesses in `script/init.ts:129`. The older [debt inventory](docs/19-tech-debt.md)
records a fourth diagnostic in `fetch-wrapper-events.ts`; it was not reproduced with the installed
dependencies. This working tree already had changes to `bun.lock` and `remappings.txt`.

Use focused tests while developing:

```bash
forge test --match-test test_ListingFlow -vv
forge test --match-test test_CompleteEcosystemFlow -vv
forge test --match-test test_PurchaseFlow -vvv
```

For native deployment, leave `bun run anvil` running in terminal 1, then run `bun run deploy:local`
in terminal 2. It uses the local configuration tables and public Anvil key, and records transactions
in `broadcast/deploy.s.sol/31337/run-latest.json`. Native Anvil is ephemeral with this command.
Do not run native Anvil on the same port as the Docker stack.

## From deployment to a marketplace transaction

Deployment creates brand 1 and contract relationships. It does **not** seed users, whitelist entries,
wrapper items or listings. `test_CompleteEcosystemFlow` and `setUp()` in
[test/Crutrade.t.sol](test/Crutrade.t.sol) demonstrate the whole lifecycle; these tests use their own
in-memory chain and do not populate the running Docker or native Anvil instance.

To reproduce a sale on your local chain:

1. Use an `OPERATIONAL` account to whitelist seller and buyer, then import a wrapper with a non-zero
   collection and input `active = false`. Import sets the stored wrapper to active.
2. Fund the payer with the mock token and approve the **Payments proxy**. The payer is the user for
   crypto settlement or the `FIAT` role's primary address for fiat settlement.
3. Set intended fees, durations and schedules from an `OWNER` account. The seed schedule is
   Saturday at 15:30 UTC; purchases must wait until the listing's stored `start` timestamp.
4. Build the exact EIP-712 payload from [ModifiersBase.sol](src/abstracts/ModifiersBase.sol): Sales
   proxy address, chain ID `31337`, domain name `Crutrade Sales`, version `1`, and `getNonce(user)`.
   Have the user sign, then submit `Sales.list` or `Sales.buy` from an `OPERATIONAL` account.
5. Check the sale, NFT ownership and token balances. See [core flows](docs/04-core-flows.md) and
   [payment calculations](docs/07-payments-fees.md) for call order and fee semantics.

Current implementation details that affect setup:

| Setting | Actual behavior |
| --- | --- |
| Fiat surcharge | Starts at zero because `Payments.initialize` assigns the parameter to itself; apply `setFiatFeePercentage` afterwards. |
| Membership fees | Deployment ignores the supplied JSON and seeds tier 0 at 600/400 bps and tier 1 at 100/100 bps; apply `setMembershipFees` for intended values. |
| Service fees | Zero until an owner calls `setServiceFee` for the hashed `LIST`, `BUY`, `WITHDRAW`, `RENEW` keys. |
| Mock token units | `MockUSDC` inherits 18 decimals but deployment registers it as 6; choose raw amounts explicitly. The test fixture uses separate mocks. |
| Settlement signature | Sales payloads do not sign `erc20`; fiat settlement is selected by `erc20 == address(0)`, independently of signed `isFiat`. |

An expired listing must be renewed before it can be withdrawn during a live window. Exporting a
wrapper does not burn it. Account for both constraints in any local UI or relayer.

## Use the npm package

In a consuming application:

```bash
npm install @crutrade/contracts viem
```

This example reads a real view function on Fuji:

```typescript
import { getContract } from '@crutrade/contracts';
import { createPublicClient, http, zeroAddress } from 'viem';
import { avalancheFuji } from 'viem/chains';

const client = createPublicClient({
  chain: avalancheFuji,
  transport: http('https://api.avax-test.network/ext/bc/C/rpc'),
});
const sales = getContract('Sales', 'testnet');
if (sales.address === zeroAddress) throw new Error('Sales address is not configured');

const nextDrop = await client.readContract({
  address: sales.address,
  abi: sales.abi,
  functionName: 'getNextScheduleTime',
});
console.log(nextDrop);
```

Exports are `abis`, `addresses`, `getContract(name, network)` and a default object containing all
three. The helper supports **`mainnet` and `testnet` only**. For Anvil, use `abis.Sales` with the
proxy address from your local manifest and an Anvil client. There is no `addresses.local` export.
Check that remote addresses have deployed code before use; the checked-in mainnet
`USDCApprovalProxy` address is currently zero.

Ethers v6 TypeChain sources are exposed at `@crutrade/contracts/types`. This subpath points to
TypeScript rather than compiled JavaScript; consumers need a toolchain that handles those sources.
See [package documentation](docs/10-typescript-package.md).

## Build the package

The local stack and tests need only Bun and Foundry. The existing package release scripts still
invoke npm/npx internally and require Node/npm; they are not part of Docker startup.

For a local bundle of the existing checked-in `index.ts`, run `bunx --no-install tsup` after dependency
installation. To regenerate ABIs, bindings and addresses for a release, first restore and verify the
intended remote deployment records in `broadcast/deploy.s.sol/{43113,43114}/run-latest.json` and/or
`deployments/{testnet,mainnet}/latest.json`. Existing deployment JSON values override broadcast-derived
addresses. Then run generation in dependency order:

```bash
forge build --via-ir
bun run generate-types
bun run create-deployments
bun run update-package
bunx --no-install tsup
```

Review generated changes: missing deployment records become **zero addresses**, and missing ABI
artifacts become empty arrays. Local chain `31337` records are not consumed by the package generator.

`npm run build` currently runs `tsup` **before** regenerating `index.ts`, so its bundle can be stale.
`npm publish` invokes that build through `prepublishOnly`; complete and verify ordered generation
before publishing. `npm run test-package` builds, packs and installs in a temporary directory; it
regenerates files and requires npm access. Docker startup does not run these package-writing steps.

`npm run clean` deletes `dist/`, `out/`, `cache/` **and `broadcast/`**. Both `broadcast/` and
`deployments/` are gitignored: back up deployment records separately before cleaning.

## Remote deployment constraints

Docker Compose is a local development stack. Remote deployment needs a funded signer, verified chain
and reviewed role/payment configuration. Keep real keys outside tracked files; `.env.example`
contains legacy variables and is not a complete deployment recipe.

- **Fuji routing is inconsistent.** `npm run deploy:testnet` passes `fuji`, which `deploy.ts` rejects.
  Passing `testnet` forwards `NETWORK=testnet`, which `deploy.s.sol` treats as local.
  `NETWORK=fuji bun script/deploy.ts testnet` does not fix this: the CLI argument wins and the child
  environment is overwritten. Direct Foundry invocation requires `NETWORK=fuji` and the required
  environment values listed in [configuration](docs/13-configuration.md).
- **The deployer must be the initial admin.** The Solidity script assigns `DEFAULT_ADMIN_ROLE` to
  `OWNER`, then grants contract roles from the broadcasting signer. Those addresses must match for
  that step to succeed. The mainnet configuration names a multisig as `OWNER`; an EOA signing key
  cannot execute those grants as the multisig. No multisig handoff workflow is implemented.
- **Role tables are not fully applied.** The script grants its six user roles to `OWNER`, even when
  the TypeScript tables specify separate fiat, pauser or upgrader accounts.

See [operations](docs/17-operations.md), with the routing correction above. Existing upgrade scripts
target hardcoded Fuji proxies and some reference missing files. Read [technical debt](docs/19-tech-debt.md)
and verify the deployed storage layout before choosing an upgrade path.

## Contributor and agent workflow

Read [AGENTS.md](AGENTS.md) before editing; scoped rules also live in [.claude/rules](.claude/rules).

1. Inspect `git status --short` and preserve unrelated user changes.
2. Read the relevant [documentation chapter](docs/README.md) and the actual implementation.
   Chapters record a verification commit; they are not proof of current deployment state.
3. Keep external access control in `src/<Name>.sol`, business logic in `src/abstracts/<Name>Base.sol`,
   shared structs in `src/interfaces/`, and Solidity pinned to `0.8.30`.
4. Never hand-edit `index.ts`, `types/`, build/deploy artifacts, dependencies or lockfiles. Do not
   access real `.env` secrets or change deployed proxy address constants. Preserve deployed storage:
   bases have no gaps; append new state to the most-derived contract and verify layout compatibility.
5. Update `CHANGELOG.md` under `[Unreleased]` and relevant docs. Run focused tests while iterating,
   then `forge test` and `npx tsc --noEmit`; ABI changes also require `forge build --via-ir`.
   Report existing failures separately from new ones.
6. Before every commit and push, invoke the `skeptic` subagent and wait for its verdict as required
   by workspace rules. Resolve `FAIL`; obtain explicit confirmation for `CONDITIONAL`.
   Use Conventional Commits and keep each commit to one logical change.

Do not run whole-repository `forge fmt`: most Solidity files differ from its formatting. There is
currently no CI or linter gate. Linux validation uses disposable Docker containers with sanitized
inputs, never OrbStack Machines; use `--network none` when checks do not require networking.

## Repository map

| Path | Purpose |
| --- | --- |
| `src/Roles.sol` | Roles, primary addresses, delegation and payment-token registry |
| `src/Sales.sol`, `src/Payments.sol` | Listing lifecycle, scheduling and settlement |
| `src/Wrappers.sol`, `src/Brands.sol` | Item NFTs and soulbound brand NFTs |
| `src/Whitelist.sol`, `src/Memberships.sol` | Participant allow-list and fee tiers |
| `src/USDCApprovalProxy.sol` | Permissionless ERC-2612 permit forwarding |
| `src/abstracts/`, `src/interfaces/` | Shared implementation and cross-contract types |
| `test/Crutrade.t.sol` | Ecosystem fixtures, signature examples and tests |
| `script/` | Deployment, configuration, upgrades and package generation |
| `docker/local-stack.ts`, `compose.yaml` | Local startup, persistence and offline test service |
| `index.ts`, `types/`, `dist/` | Generated package source, bindings and build output |

All eight production contracts use ERC1967 UUPS proxies. Most peers are resolved through `Roles`;
`USDCApprovalProxy` separately stores its token and Payments addresses. Sales operations require a
relayer and user signatures; ordinary wrapper ERC-721 transfers and permit forwarding have different
access rules.

Continue with [architecture](docs/02-architecture.md), [roles](docs/05-roles-access-control.md),
[API reference](docs/11-api-reference.md), [security](docs/15-security.md),
[testing](docs/16-testing.md) and the [complete documentation index](docs/README.md).
