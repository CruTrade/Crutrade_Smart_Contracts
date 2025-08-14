/**
 * @title Network Configuration
 * @notice Shared network configuration for all scripts
 * @dev Centralized network configuration to avoid duplication across scripts
 * @author Crutrade Team
 */

import { avalanche, avalancheFuji, anvil } from "viem/chains";

export interface NetworkConfig {
  chainId: number;
  rpc: string;
  usdc?: string;
  privateKey?: string;
  forgeArgs?: string;
}

export const ANVIL_ADDRESS_1_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

// Network configuration mapping
export const NETWORK_CONFIGS: Record<string, NetworkConfig> = {
  local: {
    chainId: 31337,
    rpc: anvil.rpcUrls.default.http[0],
    privateKey: ANVIL_ADDRESS_1_PRIVATE_KEY,
    forgeArgs: "",
  },
  testnet: {
    chainId: 43113,
    rpc: process.env.TESTNET_RPC || avalancheFuji.rpcUrls.default.http[0],
    usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
    privateKey: process.env.PRIVATE_KEY,
    forgeArgs: "",
  },
  fuji: {
    chainId: 43113,
    rpc: process.env.TESTNET_RPC || avalancheFuji.rpcUrls.default.http[0],
    usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
    privateKey: process.env.PRIVATE_KEY,
    forgeArgs: "",
  },
  mainnet: {
    chainId: 43114,
    rpc: process.env.MAINNET_RPC || avalanche.rpcUrls.default.http[0],
    usdc: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E",
    privateKey: process.env.PRIVATE_KEY,
    forgeArgs: "",
  },
};

/**
 * @notice Get network configuration for a specific network
 * @param network The network name
 * @returns NetworkConfig for the specified network
 */
export function getNetworkConfig(network: string): NetworkConfig {
  const config = NETWORK_CONFIGS[network];
  if (!config) {
    throw new Error(`Unknown network: ${network}. Available networks: ${Object.keys(NETWORK_CONFIGS).join(', ')}`);
  }
  return config;
}

/**
 * @notice Get network from command line arguments or environment
 * @param argv Command line arguments
 * @param defaultNetwork Default network if not specified
 * @returns Network name
 */
export function getNetwork(argv: string[], defaultNetwork: string = "testnet"): string {
  return argv[2] || process.env.NETWORK || defaultNetwork;
}

/**
 * @notice Validate that required environment variables are set for a network
 * @param network The network name
 * @param config The network configuration
 */
export function validateNetworkConfig(network: string, config: NetworkConfig): void {
  if (network !== "local" && !config.privateKey) {
    throw new Error(`Missing PRIVATE_KEY for network: ${network}`);
  }
}


