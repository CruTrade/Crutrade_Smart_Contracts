#!/usr/bin/env bun

import { ethers } from "ethers";
import * as fs from "fs";

// --- Config ---
const MAINNET_RPC =
  process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc";
const FUJI_RPC =
  process.env.FUJI_RPC || "https://api.avax-test.network/ext/bc/C/rpc";
const DEPLOYMENT_PATH = "./broadcast/deploy.s.sol/43114/run-latest.json";
const ABI_PATH = "./out/USDCApprovalProxy.sol/USDCApprovalProxy.json";
const CONTRACT_NAME = "USDCApprovalProxy";

// USDC Approval Proxy contract addresses for different environments
const USDC_PROXY_ADDRESSES = {
  production: "", // To be set after mainnet deployment
  staging: "", // To be set after testnet deployment
  testnet: "", // Same as staging for now
};

// USDC token addresses for different environments
const USDC_TOKEN_ADDRESSES = {
  production: "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", // Avalanche mainnet USDC
  staging: "0x5425890298aed601595a70AB815c96711a31Bc65", // Fuji testnet USDC
  testnet: "0x5425890298aed601595a70AB815c96711a31Bc65", // Same as staging for now
};

// Payments contract addresses for different environments
const PAYMENTS_ADDRESSES = {
  production: "", // To be set after mainnet deployment
  staging: "", // To be set after testnet deployment
  testnet: "", // Same as staging for now
};

// --- Helpers ---
function getContractAddress(environment: string): string {
  // If environment is specified, use the predefined address
  if (USDC_PROXY_ADDRESSES[environment as keyof typeof USDC_PROXY_ADDRESSES]) {
    const address = USDC_PROXY_ADDRESSES[environment as keyof typeof USDC_PROXY_ADDRESSES];
    if (address) return address;
  }

  // Fallback to reading from deployment file
  try {
    const data = JSON.parse(fs.readFileSync(DEPLOYMENT_PATH, "utf8"));
    const contractOrder = [
      "Roles",
      "Brands",
      "Wrappers",
      "Whitelist",
      "Payments",
      "Sales",
      "Memberships",
      "USDCApprovalProxy",
    ];
    const proxyAddresses: string[] = [];
    for (const tx of data.transactions) {
      if (
        tx.transactionType === "CREATE" &&
        tx.contractName === "ERC1967Proxy"
      ) {
        proxyAddresses.push(tx.contractAddress);
      }
    }
    const idx = contractOrder.indexOf(CONTRACT_NAME);
    if (idx >= 0 && idx < proxyAddresses.length) {
      return proxyAddresses[idx];
    }
    const tx = data.transactions.find(
      (t: any) => t.contractName === CONTRACT_NAME
    );
    if (tx) return tx.contractAddress;
  } catch (error) {
    console.warn("Could not read deployment file, using predefined address");
  }

  throw new Error(
    `Could not find ${CONTRACT_NAME} address for environment: ${environment}`
  );
}

function getUSDCTokenAddress(environment: string): string {
  return USDC_TOKEN_ADDRESSES[environment as keyof typeof USDC_TOKEN_ADDRESSES];
}

function getPaymentsAddress(environment: string): string {
  return PAYMENTS_ADDRESSES[environment as keyof typeof PAYMENTS_ADDRESSES] || "";
}

function getABI(): any {
  const artifact = JSON.parse(fs.readFileSync(ABI_PATH, "utf8"));
  return artifact.abi;
}

function getRPCUrl(environment: string): string {
  switch (environment) {
    case "production":
      return MAINNET_RPC;
    case "staging":
    case "testnet":
      return FUJI_RPC;
    default:
      throw new Error(`Unknown environment: ${environment}`);
  }
}

// --- Main ---
async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log(
      "Usage: bun script/configure-usdc-proxy.ts <environment> <action> [parameters]"
    );
    console.log("Environments: production, staging, testnet");
    console.log("Actions:");
    console.log("  set-usdc <address>         - Set USDC token address");
    console.log("  set-payments <address>     - Set payments contract address");
    console.log("  get-config                 - Get current configuration");
    console.log("  record-approval <spender> <amount> - Record an approval");
    console.log("  get-allowance <owner> <spender>    - Get allowance");
    console.log("\nAvailable environments:");
    console.log("  production - Mainnet Avalanche");
    console.log("  staging    - Fuji testnet");
    console.log("  testnet    - Fuji testnet (alias for staging)");
    process.exit(1);
  }

  const environment = args[0];
  const action = args[1];

  if (!["production", "staging", "testnet"].includes(environment)) {
    console.error("Invalid environment. Use: production, staging, or testnet");
    process.exit(1);
  }

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Set your OWNER private key in PRIVATE_KEY env var.");
    process.exit(1);
  }

  try {
    const rpcUrl = getRPCUrl(environment);
    const contractAddress = getContractAddress(environment);

    console.log(`\n🔧 Configuring USDC Approval Proxy for ${environment} environment...`);
    console.log(`📋 Contract: ${contractAddress}`);
    console.log(
      `🌍 Network: ${
        environment === "production" ? "Avalanche Mainnet" : "Fuji Testnet"
      }`
    );
    console.log(`🎯 Action: ${action}\n`);

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const abi = getABI();
    const contract = new ethers.Contract(contractAddress, abi, wallet);

    switch (action) {
      case "set-usdc":
        if (args.length < 3) {
          console.error("Please provide USDC token address");
          process.exit(1);
        }
        await setUSDCToken(contract, args[2]);
        break;

      case "set-payments":
        if (args.length < 3) {
          console.error("Please provide payments contract address");
          process.exit(1);
        }
        await setPaymentsContract(contract, args[2]);
        break;

      case "get-config":
        await getConfiguration(contract);
        break;

      case "record-approval":
        if (args.length < 4) {
          console.error("Please provide spender address and amount");
          process.exit(1);
        }
        await recordApproval(contract, args[2], args[3]);
        break;

      case "get-allowance":
        if (args.length < 4) {
          console.error("Please provide owner and spender addresses");
          process.exit(1);
        }
        await getAllowance(contract, args[2], args[3]);
        break;

      default:
        console.error(`Unknown action: ${action}`);
        process.exit(1);
    }
  } catch (error) {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  }
}

async function setUSDCToken(contract: ethers.Contract, usdcAddress: string) {
  console.log("📤 Setting USDC token address...");
  try {
    const tx = await contract.setUSDCToken(usdcAddress);
    console.log("📋 Transaction sent:", tx.hash);

    console.log("⏳ Waiting for confirmation...");
    await tx.wait();

    console.log("✅ USDC token address updated successfully!");
    console.log(`🔗 New USDC address: ${usdcAddress}`);
    console.log(`📋 Transaction: ${tx.hash}`);
  } catch (error: any) {
    console.error("❌ Transaction failed!");
    handleError(error);
  }
}

async function setPaymentsContract(contract: ethers.Contract, paymentsAddress: string) {
  console.log("📤 Setting payments contract address...");
  try {
    const tx = await contract.setPaymentsContract(paymentsAddress);
    console.log("📋 Transaction sent:", tx.hash);

    console.log("⏳ Waiting for confirmation...");
    await tx.wait();

    console.log("✅ Payments contract address updated successfully!");
    console.log(`🔗 New payments address: ${paymentsAddress}`);
    console.log(`📋 Transaction: ${tx.hash}`);
  } catch (error: any) {
    console.error("❌ Transaction failed!");
    handleError(error);
  }
}

async function getConfiguration(contract: ethers.Contract) {
  console.log("📖 Getting current configuration...");
  try {
    const usdcToken = await contract.usdcToken();
    const paymentsContract = await contract.paymentsContract();

    console.log("✅ Current configuration:");
    console.log(`🔗 USDC Token: ${usdcToken}`);
    console.log(`🔗 Payments Contract: ${paymentsContract}`);
  } catch (error: any) {
    console.error("❌ Failed to get configuration!");
    handleError(error);
  }
}

async function recordApproval(contract: ethers.Contract, spender: string, amount: string) {
  console.log("📤 Recording approval...");
  try {
    const tx = await contract.recordUSDCApproval(spender, amount);
    console.log("📋 Transaction sent:", tx.hash);

    console.log("⏳ Waiting for confirmation...");
    await tx.wait();

    console.log("✅ Approval recorded successfully!");
    console.log(`👤 Spender: ${spender}`);
    console.log(`💰 Amount: ${amount}`);
    console.log(`📋 Transaction: ${tx.hash}`);
  } catch (error: any) {
    console.error("❌ Transaction failed!");
    handleError(error);
  }
}

async function getAllowance(contract: ethers.Contract, owner: string, spender: string) {
  console.log("📖 Getting allowance...");
  try {
    const allowance = await contract.allowance(owner, spender);

    console.log("✅ Allowance retrieved:");
    console.log(`👤 Owner: ${owner}`);
    console.log(`👤 Spender: ${spender}`);
    console.log(`💰 Allowance: ${allowance.toString()}`);
  } catch (error: any) {
    console.error("❌ Failed to get allowance!");
    handleError(error);
  }
}

function handleError(error: any) {
  // Try to decode the error
  if (error.data) {
    console.error("📋 Error data:", error.data);

    // Check if it's a custom error
    if (error.data.startsWith("0xb87a12a9")) {
      console.error(
        "🔍 This appears to be a 'NotAllowed' error - your wallet doesn't have the required role"
      );
      console.error(
        "💡 Make sure your wallet has the OWNER role in the Roles contract"
      );
    }
  }

  if (error.reason) {
    console.error("📋 Error reason:", error.reason);
  }

  if (error.shortMessage) {
    console.error("📋 Error message:", error.shortMessage);
  }

  throw error;
}

main().catch((err) => {
  console.error("❌ Fatal error:", err);
  process.exit(1);
});