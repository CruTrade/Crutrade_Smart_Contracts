#!/usr/bin/env bun
import { writeFileSync, readFileSync, existsSync } from "fs";
import { resolve } from "path";

const contracts = [
  "Roles",
  "Brands",
  "Wrappers",
  "Whitelist",
  "Payments",
  "Sales",
  "Memberships",
] as const;

async function loadAbi(contractName: string) {
  const abiPath = resolve(`out/${contractName}.sol/${contractName}.json`);
  if (!existsSync(abiPath)) return [];

  try {
    const artifact = JSON.parse(readFileSync(abiPath, "utf8"));
    return artifact.abi;
  } catch {
    return [];
  }
}

function extractAddressesFromBroadcast(
  network: "mainnet" | "testnet"
): Record<string, string> {
  const networkId = network === "mainnet" ? "43114" : "43113";
  const broadcastPath = resolve(
    `broadcast/deploy.s.sol/${networkId}/run-latest.json`
  );

  if (!existsSync(broadcastPath)) {
    console.log(`⚠️  No broadcast file found for ${network}: ${broadcastPath}`);
    return {};
  }

  try {
    const broadcastData = JSON.parse(readFileSync(broadcastPath, "utf8"));
    const proxyAddresses: string[] = [];

    // Extract ERC1967Proxy addresses in order
    for (const tx of broadcastData.transactions) {
      if (
        tx.transactionType === "CREATE" &&
        tx.contractName === "ERC1967Proxy"
      ) {
        proxyAddresses.push(tx.contractAddress);
        console.log(`  Found ${network} ERC1967Proxy at ${tx.contractAddress}`);
      }
    }

    // Map proxy addresses to contract names based on deployment order
    const contractKeys = [
      "roles",
      "brands",
      "wrappers",
      "whitelist",
      "payments",
      "sales",
      "memberships",
    ];
    const addresses: Record<string, string> = {};

    for (
      let i = 0;
      i < Math.min(proxyAddresses.length, contractKeys.length);
      i++
    ) {
      addresses[contractKeys[i]] = proxyAddresses[i];
      console.log(
        `  Mapped ${network} ${contractKeys[i]}: ${proxyAddresses[i]}`
      );
    }

    return addresses;
  } catch (error) {
    console.error(`Error reading broadcast file for ${network}:`, error);
    return {};
  }
}

function loadDeployments() {
  const deployments: any = { mainnet: {}, testnet: {} };

  // Extract addresses from broadcast files
  deployments.mainnet = extractAddressesFromBroadcast("mainnet");
  deployments.testnet = extractAddressesFromBroadcast("testnet");

  return deployments;
}

async function updatePackage() {
  const deployments = loadDeployments();
  const timestamp = new Date().toISOString();

  // Load all ABIs
  const abis: Record<string, any> = {};
  for (const contract of contracts) {
    abis[contract] = await loadAbi(contract);
  }

  const indexContent = `// Auto-generated - Do not edit manually
// Updated: ${timestamp}

import type { Address } from 'viem';

// Contract ABIs
export const abis = {
${contracts
  .map((name) => `  ${name}: ${JSON.stringify(abis[name], null, 2)} as const,`)
  .join("\n")}
};

// Contract addresses
export const addresses = {
  mainnet: {
${contracts
  .map((name) => {
    const addr =
      deployments.mainnet[name.toLowerCase()] ||
      "0x0000000000000000000000000000000000000000";
    return `    ${name}: '${addr}' as Address,`;
  })
  .join("\n")}
  },
  testnet: {
${contracts
  .map((name) => {
    const addr =
      deployments.testnet[name.toLowerCase()] ||
      "0x0000000000000000000000000000000000000000";
    return `    ${name}: '${addr}' as Address,`;
  })
  .join("\n")}
  }
};

// Helper function
export function getContract(name: keyof typeof addresses.mainnet, network: 'mainnet' | 'testnet') {
  return {
    address: addresses[network][name],
    abi: abis[name]
  };
}

// Default export
export default { abis, addresses, getContract };`;

  writeFileSync(resolve("index.ts"), indexContent);
  console.log("📦 Package updated");
}

updatePackage().catch(console.error);
