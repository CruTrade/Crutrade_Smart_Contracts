/// <reference types="bun-types" />
/// <reference types="node" />
import { $ } from "bun";
import { argv, env } from "process";
import { avalanche, avalancheFuji, anvil } from "viem/chains";

const ANVIL_ADDRESS_1 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const ANVIL_ADDRESS_2 = "0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC";
const ANVIL_ADDRESS_3 = "0xe812BeeF1F7A62ed142835Ec2622B71AeA858085";

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
    owner: ANVIL_ADDRESS_1,
    operational1: ANVIL_ADDRESS_2,
    operational2: ANVIL_ADDRESS_3,
    privateKey: ANVIL_ADDRESS_1_PRIVATE_KEY,
    forgeArgs: "",
  },
  testnet: {
    chain: avalancheFuji,
    rpc: avalancheFuji.rpcUrls.default.http[0],
    usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
    owner: env.OWNER,
    operational1: env.OPERATIONAL_1,
    operational2: env.OPERATIONAL_2,
    privateKey: env.PRIVATE_KEY,
    forgeArgs: "",
  },
  mainnet: {
    chain: avalanche,
    rpc: avalanche.rpcUrls.default.http[0],
    usdc: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
    owner: env.OWNER,
    operational1: env.OPERATIONAL_1,
    operational2: env.OPERATIONAL_2,
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
if (!config.owner) {
  console.error(`Missing OWNER address for network: ${network}`);
  process.exit(1);
}
if (!config.operational1 || !config.operational2) {
  console.error(
    `Missing OPERATIONAL_1 or OPERATIONAL_2 address for network: ${network}`
  );
  process.exit(1);
}

// Compose env for forge
const envVars = {
  ...env,
  NETWORK: network,
  OWNER: config.owner,
  OPERATIONAL_1: config.operational1,
  OPERATIONAL_2: config.operational2,
  USDC_ADDRESS: config.usdc || "",
};

// For local, usdc is set by the deploy script after deploying MockUSDC
await $`forge script script/deploy.s.sol --rpc-url ${config.rpc} --private-key ${config.privateKey} --broadcast --via-ir ${config.forgeArgs}`.env(
  envVars
);

// await $`bun script/update-package.ts`;
