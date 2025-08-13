#!/usr/bin/env bun

import { ethers } from "ethers";
import * as fs from "fs";

// --- Config ---
const MAINNET_RPC =
  process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc";
const FUJI_RPC =
  process.env.FUJI_RPC || "https://api.avax-test.network/ext/bc/C/rpc";
const DEPLOYMENT_PATH = "./broadcast/deploy.s.sol/43114/run-latest.json";
const ABI_PATH = "./out/Wrappers.sol/Wrappers.json";
const CONTRACT_NAME = "Wrappers";

// Contract addresses for different environments
const CONTRACT_ADDRESSES = {
  production: "0x5C85e3b6C537E8933092c91005F6F037F8CF07f1", // Latest mainnet deployment
  staging: "0x75D8C1F61c2937858b87F1C89A57012cfAB909aa", // Fuji testnet address
  testnet: "0x75D8C1F61c2937858b87F1C89A57012cfAB909aa", // Same as staging for now
};

// Roles contract addresses for different environments
const ROLES_CONTRACT_ADDRESSES = {
  production: "0xc6110825812b42D21F93ac5bc5047547870DB42F", // Latest mainnet deployment
  staging: "0xc6110825812b42D21F93ac5bc5047547870DB42F", // Fuji testnet address
  testnet: "0xc6110825812b42D21F93ac5bc5047547870DB42F", // Same as staging for now
};

// Default base URIs for different environments
const DEFAULT_BASE_URIS = {
  production: "https://wrapper-nfts-production.s3.eu-west-1.amazonaws.com/",
  staging: "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/",
  testnet: "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/",
};

// --- Helpers ---
function getContractAddress(environment: string): string {
  // If environment is specified, use the predefined address
  if (CONTRACT_ADDRESSES[environment as keyof typeof CONTRACT_ADDRESSES]) {
    return CONTRACT_ADDRESSES[environment as keyof typeof CONTRACT_ADDRESSES];
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

function getDefaultBaseURI(environment: string): string {
  return (
    DEFAULT_BASE_URIS[environment as keyof typeof DEFAULT_BASE_URIS] ||
    DEFAULT_BASE_URIS.staging
  );
}

// --- Main ---
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.log(
      "Usage: bun script/set-wrapper-base-uri.ts <environment> [newBaseURI]"
    );
    console.log("Environments: production, staging, testnet");
    console.log("Example: bun script/set-wrapper-base-uri.ts staging");
    console.log(
      "Example: bun script/set-wrapper-base-uri.ts staging https://my-custom-uri.com/"
    );
    console.log("\nAvailable environments:");
    console.log("  production - Mainnet Avalanche");
    console.log("  staging    - Fuji testnet");
    console.log("  testnet    - Fuji testnet (alias for staging)");
    process.exit(1);
  }

  const environment = args[0];
  const newBaseURI = args[1] || getDefaultBaseURI(environment);

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

    console.log(`\n🔧 Setting base URI for ${environment} environment...`);
    console.log(`📋 Contract: ${contractAddress}`);
    console.log(
      `🌍 Network: ${
        environment === "production" ? "Avalanche Mainnet" : "Fuji Testnet"
      }`
    );
    console.log(`🔗 New Base URI: ${newBaseURI}\n`);

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const abi = getABI();
    const contract = new ethers.Contract(contractAddress, abi, wallet);

    console.log("📤 Sending transaction...");
    try {
      const tx = await contract.setHttpsBaseURI(newBaseURI);
      console.log("📋 Transaction sent:", tx.hash);
      
      console.log("⏳ Waiting for confirmation...");
      await tx.wait();
      
      console.log("✅ Base URI updated successfully!");
      console.log(`🔗 New URI: ${newBaseURI}`);
      console.log(`📋 Transaction: ${tx.hash}`);
    } catch (error: any) {
      console.error("❌ Transaction failed!");
      
      // Try to decode the error
      if (error.data) {
        console.error("📋 Error data:", error.data);
        
        // Check if it's a custom error
        if (error.data.startsWith("0xb87a12a9")) {
          console.error("🔍 This appears to be a 'NotAllowed' error - your wallet doesn't have the required role");
          console.error("💡 Make sure your wallet has the OWNER role in the Roles contract");
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
  } catch (error) {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("❌ Fatal error:", err);
  process.exit(1);
});
