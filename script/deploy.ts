/// <reference types="bun-types" />
/// <reference types="node" />
import { $ } from "bun";
import { argv, env } from "process";
import { avalanche, avalancheFuji, anvil } from "viem/chains";
import {
  getPaymentsConfig,
  validatePaymentsConfig,
  printPaymentsConfig,
} from "./payments-config";
import {
  getRolesConfig,
  validateRolesConfig,
  printRolesConfig,
  generateEnvVars,
  checkSecurityIssues,
} from "./roles-config";

const ANVIL_ADDRESS_1_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const ANVIL_ADDRESS_2_PRIVATE_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const ANVIL_ADDRESS_3_PRIVATE_KEY =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

// Network config mapping
const chainConfigs = {
  local: {
    chain: anvil,
    rpc: anvil.rpcUrls.default.http[0],
    usdc: undefined, // Will be set after mock deploy
    privateKey: ANVIL_ADDRESS_1_PRIVATE_KEY,
    forgeArgs: "",
  },
  testnet: {
    chain: avalancheFuji,
    rpc: avalancheFuji.rpcUrls.default.http[0],
    usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
    privateKey: env.PRIVATE_KEY,
    forgeArgs: "",
  },
  mainnet: {
    chain: avalanche,
    rpc: avalanche.rpcUrls.default.http[0],
    usdc: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
    privateKey: env.PRIVATE_KEY,
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
  process.exit(1);
}

// Get and validate roles configuration
const rolesConfig = getRolesConfig(network);

// Get and validate payments configuration
const paymentsConfig = getPaymentsConfig(network);

// Override treasury address with the roles config treasury address
paymentsConfig.treasuryAddress = rolesConfig.treasury;

console.log(`\n=== Deployment Configuration for ${network.toUpperCase()} ===`);
console.log(`USDC: ${config.usdc || "MockUSDC (will be deployed)"}`);

// Print and validate roles configuration
printRolesConfig(rolesConfig, network);

if (!validateRolesConfig(rolesConfig, network)) {
  console.error("❌ Roles configuration validation failed!");
  process.exit(1);
}

// Check for security issues
const securityWarnings = checkSecurityIssues(rolesConfig);
if (securityWarnings.length > 0) {
  console.log("\n🔒 Security Warnings:");
  securityWarnings.forEach((warning) => console.log(warning));
  console.log("");
}

console.log("✅ Roles configuration validated successfully!");

// Print and validate payments configuration
printPaymentsConfig(paymentsConfig);

if (!validatePaymentsConfig(paymentsConfig)) {
  console.error("❌ Payments configuration validation failed!");
  process.exit(1);
}

console.log("✅ Payments configuration validated successfully!");

// Generate environment variables
const rolesEnvVars = generateEnvVars(rolesConfig);

// Compose env for forge with both configurations
const envVars = {
  ...env,
  NETWORK: network,
  USDC_ADDRESS: config.usdc || "",
  // Roles configuration
  ...rolesEnvVars,
  // Payments configuration
  TREASURY_ADDRESS: paymentsConfig.treasuryAddress,
  FIAT_FEE_PERCENTAGE: paymentsConfig.fiatFeePercentage.toString(),
  MEMBERSHIP_FEES: JSON.stringify(paymentsConfig.membershipFees),
};

console.log("\n🚀 Starting deployment...");

// For local, usdc is set by the deploy script after deploying MockUSDC
await $`forge script script/deploy.s.sol --rpc-url ${config.rpc} --private-key ${config.privateKey} --broadcast --via-ir ${config.forgeArgs}`.env(
  envVars
);

console.log("\n✅ Deployment completed successfully!");

// await $`bun script/update-package.ts`;
