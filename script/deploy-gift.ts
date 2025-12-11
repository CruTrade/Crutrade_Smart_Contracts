/// <reference types="bun-types" />
/// <reference types="node" />
import { $ } from "bun";
import { argv, env } from "process";
import { avalanche, avalancheFuji, anvil } from "viem/chains";
import { config as dotenvConfig } from "dotenv";

// Load .env file
dotenvConfig();

const ANVIL_ADDRESS_1_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const ANVIL_ADDRESS_1 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

// Network config mapping
const chainConfigs = {
  local: {
    chain: anvil,
    rpc: anvil.rpcUrls.default.http[0],
    privateKey: ANVIL_ADDRESS_1_PRIVATE_KEY,
    rolesAddress: ANVIL_ADDRESS_1,
    forgeArgs: "",
  },
  testnet: {
    chain: avalancheFuji,
    rpc: avalancheFuji.rpcUrls.default.http[0],
    privateKey: env.PRIVATE_KEY,
    rolesAddress: env.ROLES_ADDRESS,
    forgeArgs: "",
  },
  fuji: {
    chain: avalancheFuji,
    rpc: avalancheFuji.rpcUrls.default.http[0],
    privateKey: env.PRIVATE_KEY,
    rolesAddress: env.ROLES_ADDRESS,
    forgeArgs: "",
  },
  mainnet: {
    chain: avalanche,
    rpc: avalanche.rpcUrls.default.http[0],
    privateKey: env.PRIVATE_KEY,
    rolesAddress: env.ROLES_ADDRESS,
    forgeArgs: "",
  },
};

const network = (argv[2] ||
  env.NETWORK ||
  "local") as keyof typeof chainConfigs;

const config = chainConfigs[network];

if (!config) {
  console.error(`Unknown network: ${network}`);
  process.exit(1);
}

if (!config.privateKey) {
  console.error(`Missing PRIVATE_KEY for network: ${network}`);
  console.error("Please set PRIVATE_KEY in your .env file");
  process.exit(1);
}

if (!config.rolesAddress) {
  console.error(`Missing ROLES_ADDRESS for network: ${network}`);
  console.error("Please set ROLES_ADDRESS in your .env file");
  process.exit(1);
}

console.log(`\n=== Gift Deployment Configuration for ${network.toUpperCase()} ===`);
console.log(`Roles Address: ${config.rolesAddress}`);
console.log(`RPC: ${config.rpc}`);

// Compose env for forge
const envVars = {
  ...env,
  NETWORK: network === "fuji" ? "fuji" : network,
  ROLES_ADDRESS: config.rolesAddress,
};

console.log("\n🚀 Starting Gift deployment...");

// Run forge script
await $`forge script script/deploy-gift.s.sol:DeployGift --rpc-url ${config.rpc} --private-key ${config.privateKey} --broadcast --via-ir ${config.forgeArgs}`.env(
  envVars
);

console.log("\n✅ Gift deployment completed successfully!");

// Update deployments folder
console.log("\n📁 Updating deployments folder...");
await $`bun script/create-gift-deployments.ts`;

console.log("\n✅ All done!");




