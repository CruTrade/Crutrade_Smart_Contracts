# crutrade-contracts

CruTrade Smart Contracts Package - ABIs and Addresses for easy integration.

## Installation

```bash
npm install crutrade-contracts viem
```

## Quick Start

```javascript
const { getContract } = require('crutrade-contracts');

// Get contract config
const sales = getContract('Sales', 'testnet');
console.log('Sales address:', sales.address);

// Use with viem
const { createPublicClient, http, getContract: viemGetContract } = require('viem');
const { avalancheFuji } = require('viem/chains');

const client = createPublicClient({
  chain: avalancheFuji,
  transport: http('https://api.avax-test.network/ext/bc/C/rpc')
});

const contract = viemGetContract({
  address: sales.address,
  abi: sales.abi,
  client
});

// Call contract functions
const result = await contract.read.someFunction();
```

## Available Contracts

| Contract | Description |
|----------|-------------|
| `Roles` | Access control and permissions |
| `Brands` | Brand registration and management |
| `Wrappers` | NFT wrapping functionality |
| `Whitelist` | Address whitelisting |
| `Payments` | Payment processing |
| `Sales` | Marketplace sales |
| `Memberships` | Membership system |

## Networks

- **mainnet**: Avalanche (43114)
- **testnet**: Avalanche Fuji (43113)  
- **local**: Anvil (31337)

## API Reference

### `getContract(name, network)`

Returns contract configuration with address and ABI.

```javascript
const contract = getContract('Sales', 'testnet');
// Returns: { address: '0x...', abi: [...] }
```

### Direct Access

```javascript
const { addresses, abis } = require('crutrade-contracts');

// All addresses by network
console.log(addresses.testnet.Sales);
console.log(addresses.mainnet.Roles);

// All ABIs
console.log(abis.Sales);
```

## TypeScript Support

Full TypeScript support included:

```typescript
import { getContract, addresses, abis } from 'crutrade-contracts';
import type { Address } from 'viem';

const salesAddress: Address = addresses.testnet.Sales;
```

---

**CruTrade** - Decentralized marketplace for luxury goods