# crutrade-contracts

CruTrade Smart Contracts Package - ABIs and Addresses for easy integration.

## Installation

```bash
npm install crutrade-contracts viem
```

## Quick Start

```javascript
const { getContract } = require("crutrade-contracts");

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

| Contract      | Description                       |
| ------------- | --------------------------------- |
| `Roles`       | Access control and permissions    |
| `Brands`      | Brand registration and management |
| `Wrappers`    | NFT wrapping functionality        |
| `Whitelist`   | Address whitelisting              |
| `Payments`    | Payment processing                |
| `Sales`       | Marketplace sales                 |
| `Memberships` | Membership system                 |

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
const { addresses, abis } = require("crutrade-contracts");

// All addresses by network
console.log(addresses.testnet.Sales);
console.log(addresses.mainnet.Roles);

// All ABIs
console.log(abis.Sales);
```

## TypeScript Support

Full TypeScript support included with TypeChain-generated types:

### Basic Usage
```typescript
import { getContract, addresses, abis } from "crutrade-contracts";
import type { Address } from "viem";

const salesAddress: Address = addresses.testnet.Sales;
```

### TypeChain Types
Access strongly-typed contract interfaces and factories:

```typescript
// Import types directly from the types subpath
import { 
  Sales, 
  Sales__factory,
  Roles,
  Roles__factory 
} from "@crutrade/contracts/types";

// Use contract types
const salesContract: Sales = /* your contract instance */;

// Use factories to create contract instances
const salesFactory = new Sales__factory();
const rolesFactory = new Roles__factory();
```

### Complete Example with TypeChain
```typescript
import { 
  Sales__factory
} from "@crutrade/contracts/types";
import { 
  addresses, 
  getContract 
} from "@crutrade/contracts";
import { ethers } from "ethers";

// Get contract config
const salesConfig = getContract("Sales", "testnet");

// Create typed contract instance
const provider = new ethers.JsonRpcProvider("YOUR_RPC_URL");
const salesContract = Sales__factory.connect(
  salesConfig.address, 
  provider
);

// Now you have full TypeScript support
const result = await salesContract.someFunction();
```

## Local Testing

### Testing Package Updates Locally

Before publishing, you can test your package locally to ensure everything works correctly:

#### **1. Build and Package**
```bash
# Clean and rebuild everything
npm run clean
npm run build

# Create a test package
npm pack
```

#### **2. Test Package Contents**
```bash
# Check what's included in the package
tar -tzf crutrade-contracts-*.tgz

# Should include:
# - dist/ (compiled JavaScript/TypeScript)
# - types/ (TypeChain generated types)
# - package.json
# - README.md
```

#### **3. Test Package Installation**
```bash
# Create a test directory
mkdir -p /tmp/test-package && cd /tmp/test-package
npm init -y

# Install your local package
npm install /path/to/your/crutrade-contracts-*.tgz

# Verify installation
ls -la node_modules/@crutrade/contracts/
```

#### **4. Test Runtime Functionality**
```bash
# Create a test file
cat > test.mjs << 'EOF'
import { getContract, addresses, abis } from "@crutrade/contracts";

const config = getContract("Sales", "testnet");
console.log("✅ Package works!");
console.log("Sales address:", config.address);
console.log("Sales ABI functions:", config.abi.filter(item => item.type === "function").length);
console.log("Sales ABI events:", config.abi.filter(item => item.type === "event").length);
EOF

# Run the test
node test.mjs
```

#### **5. Test TypeScript Compilation**
```bash
# Install TypeScript
npm install typescript @types/node

# Create a TypeScript test
cat > test.ts << 'EOF'
import { getContract } from "@crutrade/contracts";
import { Sales__factory } from "@crutrade/contracts/types";

const config = getContract("Sales", "testnet");
console.log("✅ TypeScript compilation works!");
EOF

# Test compilation
npx tsc --noEmit test.ts
```

#### **6. Test TypeChain Types**
```bash
# Create a TypeScript config
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["*.ts"],
  "exclude": ["node_modules"]
}
EOF

# Test TypeChain types
cat > types-test.ts << 'EOF'
import { Sales, Sales__factory } from "@crutrade/contracts/types";

// Test that types are available
const factory: Sales__factory = Sales__factory;
console.log("✅ TypeChain types work!");

// Test type imports
type SalesContract = Sales;
console.log("✅ Sales contract type imported successfully!");
EOF

npx tsc --noEmit types-test.ts
```

#### **7. Test Complete Integration**
```bash
# Create a comprehensive test
cat > integration-test.ts << 'EOF'
import { getContract, addresses, abis } from "@crutrade/contracts";
import { Sales__factory, Roles__factory } from "@crutrade/contracts/types";

// Test main package
const salesConfig = getContract("Sales", "testnet");
console.log("✅ Main package works!");

// Test addresses
console.log("Mainnet Sales:", addresses.mainnet.Sales);
console.log("Testnet Sales:", addresses.testnet.Sales);

// Test ABIs
console.log("Sales ABI functions:", abis.Sales.filter(item => item.type === "function").length);
console.log("Roles ABI functions:", abis.Roles.filter(item => item.type === "function").length);

// Test TypeChain types
const salesFactory: Sales__factory = Sales__factory;
const rolesFactory: Roles__factory = Roles__factory;
console.log("✅ TypeChain types work!");

console.log("🎉 All tests passed!");
EOF

npx tsc --noEmit integration-test.ts
```

#### **8. Expected Test Results**
If everything works correctly, you should see:
- ✅ Package installation without errors
- ✅ Runtime execution with contract data
- ✅ TypeScript compilation without errors
- ✅ TypeChain types accessible
- ✅ All ABIs and addresses available

#### **9. Troubleshooting**
- **TypeScript errors**: Make sure to use `skipLibCheck: true` in tsconfig.json
- **Import errors**: Verify package.json exports are correct
- **Missing types**: Run `npm run generate-types` to regenerate TypeChain types
- **Build errors**: Run `npm run clean && npm run build` to rebuild everything

---

**CruTrade** - Decentralized marketplace for luxury goods
