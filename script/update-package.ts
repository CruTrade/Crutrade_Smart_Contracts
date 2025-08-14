#!/usr/bin/env bun
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

const contracts = ['Roles', 'Brands', 'Wrappers', 'Whitelist', 'Payments', 'Sales', 'Memberships', 'USDCApprovalProxy'] as const;

async function loadAbi(contractName: string) {
  const abiPath = resolve(`out/${contractName}.sol/${contractName}.json`);
  if (!existsSync(abiPath)) return [];
  
  try {
    const artifact = JSON.parse(readFileSync(abiPath, 'utf8'));
    return artifact.abi;
  } catch {
    return [];
  }
}

function loadDeployments() {
  const deployments: any = { mainnet: {}, testnet: {} };
  
  // Load mainnet
  const mainnetPath = resolve('deployments/mainnet/latest.json');
  if (existsSync(mainnetPath)) {
    try {
      const mainnetData = JSON.parse(readFileSync(mainnetPath, 'utf8'));
      deployments.mainnet = mainnetData.contracts || {};
    } catch {}
  }
  
  // Load testnet  
  const testnetPath = resolve('deployments/testnet/latest.json');
  if (existsSync(testnetPath)) {
    try {
      const testnetData = JSON.parse(readFileSync(testnetPath, 'utf8'));
      deployments.testnet = testnetData.contracts || {};
    } catch {}
  }
  
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
${contracts.map(name => `  ${name}: ${JSON.stringify(abis[name], null, 2)} as const,`).join('\n')}
};

// Contract addresses
export const addresses = {
  mainnet: {
${contracts.map(name => {
    const addr = deployments.mainnet[name.toLowerCase()] || '0x0000000000000000000000000000000000000000';
    return `    ${name}: '${addr}' as Address,`;
  }).join('\n')}
  },
  testnet: {
${contracts.map(name => {
    const addr = deployments.testnet[name.toLowerCase()] || '0x0000000000000000000000000000000000000000';
    return `    ${name}: '${addr}' as Address,`;
  }).join('\n')}
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

  writeFileSync(resolve('index.ts'), indexContent);
  console.log('📦 Package updated');
}

updatePackage().catch(console.error);