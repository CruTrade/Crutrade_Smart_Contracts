# crutrade-contracts

CruTrade Smart Contracts Package - ABIs and Addresses for easy integration.

## Installation

```bash
npm install @crutrade/contracts viem
```

## Quick Start

```javascript
const { getContract } = require("@crutrade/contracts");

// Get contract config
const sales = getContract("Sales", "testnet");
console.log("Sales address:", sales.address);

// Use with viem
const {
  createPublicClient,
  http,
  getContract: viemGetContract,
} = require("viem");
const { avalancheFuji } = require("viem/chains");

const client = createPublicClient({
  chain: avalancheFuji,
  transport: http("https://api.avax-test.network/ext/bc/C/rpc"),
});

const contract = viemGetContract({
  address: sales.address,
  abi: sales.abi,
  client,
});

// Call contract functions
const result = await contract.read.someFunction();
```

## Available Contracts

| Contract            | Description                          |
| ------------------- | ------------------------------------ |
| `Roles`             | Access control and permissions       |
| `Brands`            | Brand registration and management    |
| `Wrappers`          | NFT wrapping functionality           |
| `Whitelist`         | Address whitelisting                 |
| `Payments`          | Payment processing                   |
| `Sales`             | Marketplace sales                    |
| `Memberships`       | Membership system                    |
| `USDCApprovalProxy` | Forwards ERC-2612 USDC permits       |

## Networks

- **mainnet**: Avalanche (43114)
- **testnet**: Avalanche Fuji (43113)
- **local**: Anvil (31337)

## API Reference

### `getContract(name, network)`

Returns contract configuration with address and ABI.

```javascript
const contract = getContract("Sales", "testnet");
// Returns: { address: '0x...', abi: [...] }
```

### Direct Access

```javascript
const { addresses, abis } = require("@crutrade/contracts");

// All addresses by network
console.log(addresses.testnet.Sales);
console.log(addresses.mainnet.Roles);

// All ABIs
console.log(abis.Sales);
```

## TypeScript Support

Full TypeScript support included:

```typescript
import { getContract, addresses, abis } from "@crutrade/contracts";
import type { Address } from "viem";

const salesAddress: Address = addresses.testnet.Sales;
```

TypeChain bindings for `ethers` v6 ship under a separate entry point:

```typescript
import { Sales__factory } from "@crutrade/contracts/types";

const sales = Sales__factory.connect(salesAddress, signer);
```

## Developing the contracts

Requires [Foundry](https://getfoundry.sh) and [Bun](https://bun.sh).

```bash
forge soldeer install   # Solidity dependencies
bun install             # JavaScript dependencies

forge build --via-ir    # compile
forge test              # run the test suite
npm run build           # compile + regenerate types, addresses and dist/
```

`via-ir` is required; it is the default profile in `foundry.toml`.

### Local deployment

```bash
npm run anvil           # terminal 1: local chain on :8545
npm run deploy:local    # terminal 2: deploy the full ecosystem
```

Testnet and mainnet deployments need `PRIVATE_KEY` in `.env`; see `.env.example` and
[`docs/17-operations.md`](docs/17-operations.md).

### Repository layout

| Path | Contents |
| --- | --- |
| `src/` | Contracts; business logic in `src/abstracts/`, shared types in `src/interfaces/` |
| `script/` | Foundry deployment and upgrade scripts, Bun CLI tooling |
| `test/` | `Crutrade.t.sol`, the Foundry test suite |
| `types/`, `index.ts` | Generated package artifacts, do not edit by hand |

## Documentation

- [`docs/`](docs/README.md) - architecture, data model, flows, API and operations
- [`AGENTS.md`](AGENTS.md) - conventions and the change protocol for contributors and coding agents
- [`CHANGELOG.md`](CHANGELOG.md) - release notes

---

**CruTrade** - Decentralized marketplace for luxury goods
