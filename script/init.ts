#!/usr/bin/env bun
import { createPublicClient, createWalletClient, http, getContract } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { avalanche, avalancheFuji } from 'viem/chains';
import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

// Simple config
const isDev = process.env.NODE_ENV === 'dev';
const chain = isDev ? avalancheFuji : avalanche;
const rpc = isDev ? process.env.RPC_DEV! : process.env.RPC!;
const network = isDev ? 'testnet' : 'mainnet';

const USDT_ADDRESS = isDev 
  ? '0xd495C61A12f0E67E0F293E9DAC4772Acb457d287'
  : '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';

const ROLES = {
  OPERATIONAL: '0xb0564e6f165ee6c5d845565cff3a6e9321dd47d8cc479ebdc0ef1f562f79b57b',
  FIAT: '0xd6d95ec8ff0096cc12d80d844c22f649871840100e7e4322db215d7a870846c6',
  OWNER: '0x6270edb7c868f86fda4adedba75108201087268ea345934db8bad688e1feb91b',
  PAUSER: '0x539440820030c4994db4e31b6b800deafd503688728f932addfe7a410515c14c',
  UPGRADER: '0xa615a8afb6fffcb8c6809ac0997b5c9c12b8cc97651150f14c8f6203168cff4c',
  TREASURY: '0x06aa03964db1f7257357ef09714a5f0ca3633723df419e97015e0c7a3e83edb7',
};

// Robust transaction waiting with retry
async function waitForTx(publicClient: any, hash: string, description: string, maxRetries = 5) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const receipt = await publicClient.waitForTransactionReceipt({ 
        hash, 
        timeout: 30000,
        confirmations: 1
      });
      return receipt;
    } catch (error) {
      console.log(`  ⏳ ${description} - retry ${i + 1}/${maxRetries}`);
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 3000)); // Wait 3s between retries
    }
  }
}

async function main() {
  console.log(`🚀 Initializing ${network}...`);

  // Setup client
  const account = privateKeyToAccount(process.env.PRIVATE_KEY! as `0x${string}`);
  const publicClient = createPublicClient({ 
    chain, 
    transport: http(rpc, { 
      timeout: 30000,
      retryCount: 3 
    }) 
  });
  const walletClient = createWalletClient({ 
    account, 
    chain, 
    transport: http(rpc, { 
      timeout: 30000,
      retryCount: 3 
    }) 
  });

  // Load deployment
  const deploymentPath = resolve(`deployments/${network}/latest.json`);
  if (!existsSync(deploymentPath)) {
    throw new Error(`Deployment not found: ${deploymentPath}`);
  }
  const deployment = JSON.parse(readFileSync(deploymentPath, 'utf8'));

  // Load ABIs
  const loadAbi = (name: string) => {
    const path = resolve(`out/${name}.sol/${name}.json`);
    return JSON.parse(readFileSync(path, 'utf8')).abi;
  };

  const roles = getContract({
    address: deployment.roles,
    abi: loadAbi('Roles'),
    client: { public: publicClient, wallet: walletClient }
  });

  const brands = getContract({
    address: deployment.brands,
    abi: loadAbi('Brands'),
    client: { public: publicClient, wallet: walletClient }
  });

  try {
    // Setup roles
    const admin = '0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6';
    const operational = ['0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC', '0xe812BeeF1F7A62ed142835Ec2622B71AeA858085'];
    
    const roleSetup = [
      { role: ROLES.FIAT, accounts: [admin] },
      { role: ROLES.OWNER, accounts: [admin] },
      { role: ROLES.PAUSER, accounts: [admin] },
      { role: ROLES.UPGRADER, accounts: [admin] },
      { role: ROLES.TREASURY, accounts: [admin] },
      { role: ROLES.OPERATIONAL, accounts: operational },
    ];

    console.log('👥 Setting up roles...');
    for (const { role, accounts } of roleSetup) {
      for (const addr of accounts) {
        const hash = await roles.write.grantRole([role, addr]);
        await waitForTx(publicClient, hash, `Grant role to ${addr.slice(0,6)}...${addr.slice(-4)}`);
      }
    }

    // Setup payments
    console.log('💳 Setting up payments...');
    let hash = await roles.write.setPayment([USDT_ADDRESS, 6]);
    await waitForTx(publicClient, hash, 'Set USDT payment');
    
    hash = await roles.write.setDefaultFiatToken([USDT_ADDRESS]);
    await waitForTx(publicClient, hash, 'Set default fiat token');

    // Register brand
    console.log('🌟 Registering brand...');
    hash = await brands.write.register([account.address]);
    await waitForTx(publicClient, hash, 'Register brand');

    console.log('✅ Initialization complete');

  } catch (error) {
    console.error('❌ Init failed:', error.shortMessage || error.message);
    process.exit(1);
  }
}

main();