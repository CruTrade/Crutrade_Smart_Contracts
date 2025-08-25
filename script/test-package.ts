#!/usr/bin/env bun
import { execSync } from "child_process";
import { writeFileSync, mkdirSync, rmSync } from "fs";
import { resolve } from "path";

console.log("🧪 Testing package locally...");

// Create test directory
const testDir = resolve("/tmp/test-package-local");
if (rmSync) {
  try {
    rmSync(testDir, { recursive: true, force: true });
  } catch {}
}
mkdirSync(testDir, { recursive: true });

// Step 1: Build and package
console.log("\n1️⃣ Building and packaging...");
try {
  execSync("npm run build", { stdio: 'inherit' });
  execSync("npm pack", { stdio: 'inherit' });
  console.log("✅ Build and package successful");
} catch (error) {
  console.error("❌ Build failed:", error);
  process.exit(1);
}

// Step 2: Create test package.json
console.log("\n2️⃣ Setting up test environment...");
const testPackageJson = {
  name: "test-package",
  version: "1.0.0",
  type: "module",
  scripts: {
    test: "node test.mjs"
  }
};

writeFileSync(resolve(testDir, "package.json"), JSON.stringify(testPackageJson, null, 2));

// Step 3: Install dependencies
console.log("\n3️⃣ Installing dependencies...");
try {
  execSync("npm install typescript @types/node", { cwd: testDir, stdio: 'inherit' });
  execSync(`npm install ${resolve(".")}/crutrade-contracts-*.tgz`, { cwd: testDir, stdio: 'inherit' });
  console.log("✅ Dependencies installed");
} catch (error) {
  console.error("❌ Installation failed:", error);
  process.exit(1);
}

// Step 4: Create test files
console.log("\n4️⃣ Creating test files...");

// Runtime test
const runtimeTest = `
import { getContract, addresses, abis } from "@crutrade/contracts";

// Test all contracts
const contracts = ["Roles", "Brands", "Wrappers", "Whitelist", "Payments", "Sales", "Memberships", "USDCApprovalProxy"];

console.log("✅ Testing all contracts...");

for (const contractName of contracts) {
  const config = getContract(contractName, "testnet");
  console.log(\`\${contractName}:\`);
  console.log(\`  Address: \${config.address}\`);
  console.log(\`  Functions: \${config.abi.filter(item => item.type === "function").length}\`);
  console.log(\`  Events: \${config.abi.filter(item => item.type === "event").length}\`);
  console.log(\`  Mainnet: \${addresses.mainnet[contractName]}\`);
  console.log(\`  Testnet: \${addresses.testnet[contractName]}\`);
}

console.log("✅ Runtime test passed!");
`;

writeFileSync(resolve(testDir, "test.mjs"), runtimeTest);

// TypeScript test
const tsTest = `
import { getContract } from "@crutrade/contracts";
import { 
  Sales__factory, 
  Roles__factory, 
  Brands__factory, 
  Wrappers__factory, 
  Whitelist__factory, 
  Payments__factory, 
  Memberships__factory,
  USDCApprovalProxy__factory 
} from "@crutrade/contracts/types";

// Test all contracts individually
const rolesConfig = getContract("Roles", "testnet");
const brandsConfig = getContract("Brands", "testnet");
const wrappersConfig = getContract("Wrappers", "testnet");
const whitelistConfig = getContract("Whitelist", "testnet");
const paymentsConfig = getContract("Payments", "testnet");
const salesConfig = getContract("Sales", "testnet");
const membershipsConfig = getContract("Memberships", "testnet");
const usdcApprovalProxyConfig = getContract("USDCApprovalProxy", "testnet");

console.log("✅ All contracts accessible via getContract");

// Test TypeChain types
const salesFactory: Sales__factory = Sales__factory;
const rolesFactory: Roles__factory = Roles__factory;
const brandsFactory: Brands__factory = Brands__factory;
const wrappersFactory: Wrappers__factory = Wrappers__factory;
const whitelistFactory: Whitelist__factory = Whitelist__factory;
const paymentsFactory: Payments__factory = Payments__factory;
const membershipsFactory: Memberships__factory = Memberships__factory;
const usdcApprovalProxyFactory: USDCApprovalProxy__factory = USDCApprovalProxy__factory;

console.log("✅ TypeScript test passed!");
console.log("✅ All TypeChain types work!");
`;

writeFileSync(resolve(testDir, "test.ts"), tsTest);

// TypeScript config
const tsConfig = {
  compilerOptions: {
    target: "ESNext",
    module: "ESNext",
    moduleResolution: "node",
    esModuleInterop: true,
    allowSyntheticDefaultImports: true,
    strict: false,
    skipLibCheck: true,
    forceConsistentCasingInFileNames: true,
    lib: ["ESNext", "DOM"],
    noEmit: true
  },
  include: ["*.ts"],
  exclude: ["node_modules"]
};

writeFileSync(resolve(testDir, "tsconfig.json"), JSON.stringify(tsConfig, null, 2));

// Step 5: Run tests
console.log("\n5️⃣ Running tests...");

try {
  // Test runtime
  console.log("Testing runtime functionality...");
  execSync("node test.mjs", { cwd: testDir, stdio: 'inherit' });
  
  // Test TypeScript compilation
  console.log("Testing TypeScript compilation...");
  execSync("npx tsc --project tsconfig.json", { cwd: testDir, stdio: 'inherit' });
  
  console.log("\n🎉 All tests passed!");
  console.log("✅ Package is ready for publishing");
} catch (error) {
  console.error("❌ Tests failed:", error);
  process.exit(1);
}

// Cleanup
console.log("\n🧹 Cleaning up...");
try {
  rmSync(testDir, { recursive: true, force: true });
  console.log("✅ Cleanup complete");
} catch (error) {
  console.log("⚠️ Cleanup failed, but tests passed");
} 