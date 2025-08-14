#!/usr/bin/env bun

/**
 * @fileoverview USDC Approval Proxy Configuration and Deployment Script
 * 
 * This script provides a comprehensive interface for deploying, configuring, and interacting
 * with the USDCApprovalProxy contract. The USDCApprovalProxy is designed to handle USDC
 * permit operations on behalf of users, allowing backend services to initiate approvals
 * without requiring users to sign individual transactions.
 * 
 * @author CruTrade Team
 * @version 1.0.0
 * @since 2025-08-14
 * 
 * @usage
 * ====== USAGE GUIDE ======
 * 
 * 1. DEPLOYMENT
 *    Deploy a new USDCApprovalProxy contract to the specified network:
 *    bun script/configure-usdc-proxy.ts <environment> deploy
 *    
 *    Examples:
 *    bun script/configure-usdc-proxy.ts testnet deploy
 *    bun script/configure-usdc-proxy.ts production deploy
 * 
 * 2. CONFIGURATION
 *    Set the USDC token address (required before processing permits):
 *    bun script/configure-usdc-proxy.ts <environment> set-usdc <usdc_address>
 *    
 *    Set the payments contract address (required for payment-specific permits):
 *    bun script/configure-usdc-proxy.ts <environment> set-payments <payments_address>
 *    
 *    Examples:
 *    bun script/configure-usdc-proxy.ts testnet set-usdc 0x5425890298aed601595a70AB815c96711a31Bc65
 *    bun script/configure-usdc-proxy.ts testnet set-payments 0x74da042deaebfb1f9bdbbbb7028ffd79a668803b
 * 
 * 3. PERMIT OPERATIONS
 *    Process a general USDC permit (any spender):
 *    bun script/configure-usdc-proxy.ts <environment> permit-usdc <owner> <spender> <value> <deadline> <v> <r> <s>
 *    
 *    Process a USDC permit specifically for payments contract:
 *    bun script/configure-usdc-proxy.ts <environment> permit-payments <owner> <value> <deadline> <v> <r> <s>
 *    
 *    Examples:
 *    bun script/configure-usdc-proxy.ts testnet permit-usdc 0x1234567890123456789012345678901234567890 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd 1000000 1735689600 27 0x1234567890123456789012345678901234567890123456789012345678901234 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd
 *    bun script/configure-usdc-proxy.ts testnet permit-payments 0x1234567890123456789012345678901234567890 1000000 1735689600 27 0x1234567890123456789012345678901234567890123456789012345678901234 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd
 * 
 * 4. QUERY OPERATIONS
 *    Get current contract configuration:
 *    bun script/configure-usdc-proxy.ts <environment> get-config
 *    
 *    Get USDC allowance for a specific owner-spender pair:
 *    bun script/configure-usdc-proxy.ts <environment> get-allowance <owner> <spender>
 *    
 *    Examples:
 *    bun script/configure-usdc-proxy.ts testnet get-config
 *    bun script/configure-usdc-proxy.ts testnet get-allowance 0x1234567890123456789012345678901234567890 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
 * 
 * ENVIRONMENT OPTIONS:
 * - testnet: Fuji testnet (Avalanche testnet)
 * - staging: Alias for testnet
 * - production: Avalanche mainnet
 * 
 * PREREQUISITES:
 * - Set PRIVATE_KEY environment variable with deployer's private key
 * - Ensure Roles and Payments contracts are deployed before deploying USDCApprovalProxy
 * - Have sufficient native tokens for gas fees
 * 
 * WORKFLOW EXAMPLE:
 * 1. Deploy: bun script/configure-usdc-proxy.ts testnet deploy
 * 2. Configure: bun script/configure-usdc-proxy.ts testnet set-usdc 0x5425890298aed601595a70AB815c96711a31Bc65
 * 3. Configure: bun script/configure-usdc-proxy.ts testnet set-payments 0x74da042deaebfb1f9bdbbbb7028ffd79a668803b
 * 4. Verify: bun script/configure-usdc-proxy.ts testnet get-config
 * 5. Process permits as needed
 * 6. Update package: npm run build && npm run test-package
 * 
 * @requires PRIVATE_KEY environment variable to be set with the deployer's private key
 * @requires MAINNET_RPC environment variable (optional, defaults to Avalanche mainnet)
 * @requires FUJI_RPC environment variable (optional, defaults to Fuji testnet)
 * 
 * @description
 * The USDCApprovalProxy contract implements a permit-only architecture where:
 * - Users sign EIP-712 permit messages off-chain
 * - Backend services submit these signatures to the proxy
 * - The proxy calls USDC.permit() on behalf of the user
 * - This allows gasless approvals and backend-initiated operations
 * 
 * Key Features:
 * - ✅ Permit-only operations (no direct approve functions)
 * - ✅ Support for general USDC permits and payments-specific permits
 * - ✅ Automatic deployment file updates for package integration
 * - ✅ Multi-environment support (mainnet, testnet)
 * - ✅ Comprehensive error handling and validation
 * 
 * Architecture Notes:
 * - The contract uses UUPS upgradeable proxy pattern
 * - Requires Roles contract for access control
 * - Integrates with Payments contract for payment-specific permits
 * - Automatically updates deployment files for package builds
 * 
 * @example
 * // Complete workflow example:
 * 
 * // 1. Deploy the contract
 * bun script/configure-usdc-proxy.ts testnet deploy
 * 
 * // 2. Set USDC token address
 * bun script/configure-usdc-proxy.ts testnet set-usdc 0x5425890298aed601595a70AB815c96711a31Bc65
 * 
 * // 3. Set payments contract address
 * bun script/configure-usdc-proxy.ts testnet set-payments 0x74da042deaebfb1f9bdbbbb7028ffd79a668803b
 * 
 * // 4. Verify configuration
 * bun script/configure-usdc-proxy.ts testnet get-config
 * 
 * // 5. Process a USDC permit (example with dummy values)
 * bun script/configure-usdc-proxy.ts testnet permit-usdc 0x123... 0x456... 1000000 1735689600 27 0xabc... 0xdef...
 * 
 * // 6. Check allowance
 * bun script/configure-usdc-proxy.ts testnet get-allowance 0x123... 0x456...
 * 
 * @see {@link src/USDCApprovalProxy.sol} The main contract implementation
 * @see {@link USDC_PROXY_IMPLEMENTATION_NOTES.txt} Detailed implementation notes
 */

import { ethers } from "ethers";
import { USDCApprovalProxy__factory } from "../types";
import type { USDCApprovalProxy } from "../types";
import * as fs from "fs";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// --- Configuration Constants ---
/**
 * Mainnet RPC URL for Avalanche network
 * @default "https://api.avax.network/ext/bc/C/rpc"
 */
const MAINNET_RPC =
  process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc";

/**
 * Testnet RPC URL for Fuji network
 * @default "https://api.avax-test.network/ext/bc/C/rpc"
 */
const FUJI_RPC =
  process.env.FUJI_RPC || "https://api.avax-test.network/ext/bc/C/rpc";

/**
 * Default deployment file path for mainnet
 */
const DEPLOYMENT_PATH = "./broadcast/deploy.s.sol/43114/run-latest.json";

/**
 * Contract name for USDCApprovalProxy
 */
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

// --- Helper Functions ---
/**
 * Retrieves the deployed contract address for the specified environment
 * 
 * @param environment - The deployment environment ('production', 'staging', 'testnet')
 * @returns The contract address as a string
 * @throws {Error} If the contract address cannot be found
 * 
 * @description
 * This function attempts to find the contract address in the following order:
 * 1. Predefined addresses in USDC_PROXY_ADDRESSES
 * 2. Deployment file from Foundry broadcast
 * 3. Direct contract deployment transaction
 * 
 * @example
 * const address = getContractAddress('testnet');
 * console.log(`Contract deployed at: ${address}`);
 */
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

/**
 * Gets the USDC token address for the specified environment
 * 
 * @param environment - The deployment environment ('production', 'staging', 'testnet')
 * @returns The USDC token contract address
 * 
 * @description
 * Returns the appropriate USDC token address based on the environment:
 * - production: Avalanche mainnet USDC (0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E)
 * - staging/testnet: Fuji testnet USDC (0x5425890298aed601595a70AB815c96711a31Bc65)
 */
function getUSDCTokenAddress(environment: string): string {
  return USDC_TOKEN_ADDRESSES[environment as keyof typeof USDC_TOKEN_ADDRESSES];
}

/**
 * Gets the payments contract address for the specified environment
 * 
 * @param environment - The deployment environment ('production', 'staging', 'testnet')
 * @returns The payments contract address or empty string if not set
 * 
 * @description
 * Returns the payments contract address if predefined, otherwise returns empty string.
 * This is used for initializing the USDCApprovalProxy with the correct payments contract.
 */
function getPaymentsAddress(environment: string): string {
  return PAYMENTS_ADDRESSES[environment as keyof typeof PAYMENTS_ADDRESSES] || "";
}

/**
 * Gets the RPC URL for the specified environment
 * 
 * @param environment - The deployment environment ('production', 'staging', 'testnet')
 * @returns The RPC URL for the network
 * @throws {Error} If the environment is not recognized
 * 
 * @description
 * Returns the appropriate RPC URL:
 * - production: Avalanche mainnet RPC
 * - staging/testnet: Fuji testnet RPC
 */
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

// --- Deployment File Updates ---
async function updateDeploymentFiles(environment: string, deployedAddress: string) {
  console.log("📝 Updating deployment files...");
  
  try {
    const networkId = environment === "production" ? "43114" : "43113";
    const deploymentPath = `./deployments/${environment === "production" ? "mainnet" : "testnet"}/latest.json`;
    
    // Read existing deployment file
    let deploymentData;
    if (fs.existsSync(deploymentPath)) {
      deploymentData = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    } else {
      // Create new deployment data structure
      deploymentData = {
        network: environment === "production" ? "mainnet" : "testnet",
        chainId: parseInt(networkId),
        timestamp: new Date().toISOString(),
        contracts: {}
      };
    }
    
    // Update the USDCApprovalProxy address
    deploymentData.contracts.usdcapprovalproxy = deployedAddress;
    deploymentData.timestamp = new Date().toISOString();
    
    // Ensure deployments directory exists
    const deploymentsDir = `./deployments/${environment === "production" ? "mainnet" : "testnet"}`;
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    // Write updated deployment file
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentData, null, 2));
    
    console.log(`✅ Updated deployment file: ${deploymentPath}`);
    console.log(`🔗 USDCApprovalProxy address: ${deployedAddress}`);
    
    // Also update the index file
    await updateDeploymentIndex(environment, deployedAddress);
    
  } catch (error) {
    console.error("❌ Failed to update deployment files:", error);
    throw error;
  }
}

async function updateDeploymentIndex(environment: string, deployedAddress: string) {
  try {
    const indexPath = "./deployments/index.json";
    let indexData;
    
    if (fs.existsSync(indexPath)) {
      indexData = JSON.parse(fs.readFileSync(indexPath, "utf8"));
    } else {
      indexData = {
        mainnet: { contracts: {} },
        testnet: { contracts: {} },
        timestamp: new Date().toISOString()
      };
    }
    
    const networkKey = environment === "production" ? "mainnet" : "testnet";
    if (!indexData[networkKey]) {
      indexData[networkKey] = { contracts: {} };
    }
    
    indexData[networkKey].contracts.usdcapprovalproxy = deployedAddress;
    indexData.timestamp = new Date().toISOString();
    
    // Ensure deployments directory exists
    if (!fs.existsSync("./deployments")) {
      fs.mkdirSync("./deployments", { recursive: true });
    }
    
    fs.writeFileSync(indexPath, JSON.stringify(indexData, null, 2));
    console.log(`✅ Updated deployment index: ${indexPath}`);
    
  } catch (error) {
    console.error("❌ Failed to update deployment index:", error);
    // Don't throw here as this is not critical
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
    console.log("  deploy                     - Deploy USDCApprovalProxy contract");
    console.log("  set-usdc <address>         - Set USDC token address");
    console.log("  set-payments <address>     - Set payments contract address");
    console.log("  get-config                 - Get current configuration");
    console.log("  permit-usdc <owner> <spender> <value> <deadline> <v> <r> <s> - Process USDC permit");
    console.log("  permit-payments <owner> <value> <deadline> <v> <r> <s> - Process payments permit");
    console.log("  get-allowance <owner> <spender>    - Get allowance");
    console.log("");
    console.log("⚠️  Note: approve-usdc and approve-payments functions have been removed.");
    console.log("    Use permit functions instead, or call USDC.approve() directly.");
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

    console.log(`\n🔧 Configuring USDC Approval Proxy for ${environment} environment...`);
    console.log(
      `🌍 Network: ${
        environment === "production" ? "Avalanche Mainnet" : "Fuji Testnet"
      }`
    );
    console.log(`🎯 Action: ${action}\n`);

    // Handle deploy action separately since we don't need contract address yet
    if (action === "deploy") {
      await deployContract(environment);
      return;
    }

    // For all other actions, we need the contract address
    const contractAddress = getContractAddress(environment);
    console.log(`📋 Contract: ${contractAddress}`);

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    
    // Use TypeChain factory to create contract instance
    const contract = USDCApprovalProxy__factory.connect(contractAddress, wallet);

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

      case "approve-usdc":
      case "approve-payments":
        console.error("❌ Approve functions have been removed from USDCApprovalProxy.");
        console.error("💡 Use permit functions instead:");
        console.error("   - permit-usdc for general permits");
        console.error("   - permit-payments for payments contract permits");
        console.error("   - Or call USDC.approve() directly for simple approvals");
        process.exit(1);
        break;

      case "permit-usdc":
        if (args.length < 9) {
          console.error("Please provide owner, spender, value, deadline, v, r, s");
          process.exit(1);
        }
        await permitUSDC(contract, args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
        break;

      case "permit-payments":
        if (args.length < 8) {
          console.error("Please provide owner, value, deadline, v, r, s");
          process.exit(1);
        }
        await permitForPayments(contract, args[2], args[3], args[4], args[5], args[6], args[7]);
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

/**
 * Sets the USDC token address in the USDCApprovalProxy contract
 * 
 * @param contract - The USDCApprovalProxy contract instance
 * @param usdcAddress - The USDC token contract address to set
 * 
 * @description
 * This function calls the setUSDCToken function on the contract to configure
 * which USDC token the proxy should interact with. This is a critical configuration
 * that must be set before the proxy can process any USDC permits.
 * 
 * @example
 * await setUSDCToken(contract, "0x5425890298aed601595a70AB815c96711a31Bc65");
 * 
 * @throws {Error} If the transaction fails or the caller lacks permission
 */
async function setUSDCToken(contract: USDCApprovalProxy, usdcAddress: string) {
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

/**
 * Sets the payments contract address in the USDCApprovalProxy contract
 * 
 * @param contract - The USDCApprovalProxy contract instance
 * @param paymentsAddress - The payments contract address to set
 * 
 * @description
 * This function calls the setPaymentsContract function on the contract to configure
 * which payments contract the proxy should use for payment-specific permits.
 * This enables the permitForPayments function to work correctly.
 * 
 * @example
 * await setPaymentsContract(contract, "0x74da042deaebfb1f9bdbbbb7028ffd79a668803b");
 * 
 * @throws {Error} If the transaction fails or the caller lacks permission
 */
async function setPaymentsContract(contract: USDCApprovalProxy, paymentsAddress: string) {
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

/**
 * Retrieves the current configuration of the USDCApprovalProxy contract
 * 
 * @param contract - The USDCApprovalProxy contract instance
 * 
 * @description
 * This function reads the current USDC token and payments contract addresses
 * from the contract and displays them. This is useful for verifying the
 * current configuration or debugging issues.
 * 
 * @example
 * await getConfiguration(contract);
 * // Output:
 * // ✅ Current configuration:
 * // 🔗 USDC Token: 0x5425890298aed601595a70AB815c96711a31Bc65
 * // 🔗 Payments Contract: 0x74da042deaebfb1f9bdbbbb7028ffd79a668803b
 */
async function getConfiguration(contract: USDCApprovalProxy) {
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

// ❌ Removed: approveUSDC and approveForPayments functions
// These functions have been removed because the contract no longer supports approve operations.
// Use permit functions instead, or call USDC.approve() directly.

/**
 * Processes a USDC permit through the USDCApprovalProxy contract
 * 
 * @param contract - The USDCApprovalProxy contract instance
 * @param owner - The address of the USDC token owner
 * @param spender - The address that will be approved to spend USDC
 * @param value - The amount of USDC to approve (in wei)
 * @param deadline - The deadline timestamp for the permit
 * @param v - The v component of the ECDSA signature
 * @param r - The r component of the ECDSA signature
 * @param s - The s component of the ECDSA signature
 * 
 * @description
 * This function processes a USDC permit by calling the permitUSDC function
 * on the contract. The permit allows the spender to spend the specified
 * amount of USDC on behalf of the owner without requiring a separate
 * approve transaction.
 * 
 * The signature parameters (v, r, s) are generated by the owner signing
 * an EIP-712 permit message off-chain. This enables gasless approvals.
 * 
 * @example
 * await permitUSDC(
 *   contract,
 *   "0x1234567890123456789012345678901234567890", // owner
 *   "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd", // spender
 *   "1000000", // value (1 USDC with 6 decimals)
 *   "1735689600", // deadline
 *   "27", // v
 *   "0x1234567890123456789012345678901234567890123456789012345678901234", // r
 *   "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd" // s
 * );
 * 
 * @throws {Error} If the transaction fails, signature is invalid, or deadline has passed
 */
async function permitUSDC(
  contract: USDCApprovalProxy, 
  owner: string, 
  spender: string, 
  value: string, 
  deadline: string, 
  v: string, 
  r: string, 
  s: string
) {
  console.log("📤 Processing USDC permit through proxy...");
  try {
    const tx = await contract.permitUSDC(owner, spender, value, deadline, v, r, s);
    console.log("📋 Transaction sent:", tx.hash);

    console.log("⏳ Waiting for confirmation...");
    await tx.wait();

    console.log("✅ USDC permit successful!");
    console.log(`👤 Owner: ${owner}`);
    console.log(`👤 Spender: ${spender}`);
    console.log(`💰 Value: ${value}`);
    console.log(`⏰ Deadline: ${deadline}`);
    console.log(`📋 Transaction: ${tx.hash}`);
  } catch (error: any) {
    console.error("❌ Transaction failed!");
    handleError(error);
  }
}

/**
 * Processes a USDC permit specifically for the payments contract
 * 
 * @param contract - The USDCApprovalProxy contract instance
 * @param owner - The address of the USDC token owner
 * @param value - The amount of USDC to approve for payments (in wei)
 * @param deadline - The deadline timestamp for the permit
 * @param v - The v component of the ECDSA signature
 * @param r - The r component of the ECDSA signature
 * @param s - The s component of the ECDSA signature
 * 
 * @description
 * This function processes a USDC permit specifically for the payments contract
 * by calling the permitForPayments function. This is a convenience function
 * that automatically sets the spender to the configured payments contract
 * address, making it easier to approve USDC for payment operations.
 * 
 * The signature parameters (v, r, s) are generated by the owner signing
 * an EIP-712 permit message off-chain with the payments contract as the spender.
 * 
 * @example
 * await permitForPayments(
 *   contract,
 *   "0x1234567890123456789012345678901234567890", // owner
 *   "1000000", // value (1 USDC with 6 decimals)
 *   "1735689600", // deadline
 *   "27", // v
 *   "0x1234567890123456789012345678901234567890123456789012345678901234", // r
 *   "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd" // s
 * );
 * 
 * @throws {Error} If the transaction fails, signature is invalid, deadline has passed, or payments contract not set
 */
async function permitForPayments(
  contract: USDCApprovalProxy, 
  owner: string, 
  value: string, 
  deadline: string, 
  v: string, 
  r: string, 
  s: string
) {
  console.log("📤 Processing USDC permit for payments contract...");
  try {
    const tx = await contract.permitForPayments(owner, value, deadline, v, r, s);
    console.log("📋 Transaction sent:", tx.hash);

    console.log("⏳ Waiting for confirmation...");
    await tx.wait();

    console.log("✅ Payments permit successful!");
    console.log(`👤 Owner: ${owner}`);
    console.log(`💰 Value: ${value}`);
    console.log(`⏰ Deadline: ${deadline}`);
    console.log(`📋 Transaction: ${tx.hash}`);
  } catch (error: any) {
    console.error("❌ Transaction failed!");
    handleError(error);
  }
}

async function getAllowance(contract: USDCApprovalProxy, owner: string, spender: string) {
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

async function deployContract(environment: string) {
  console.log("🚀 Deploying USDCApprovalProxy contract...");
  
  try {
    // Get deployment configuration
    const rpcUrl = getRPCUrl(environment);
    const usdcTokenAddress = getUSDCTokenAddress(environment);
    
    // Get existing contract addresses from deployment files
    const rolesAddress = getExistingContractAddress("Roles", environment);
    const paymentsAddress = getExistingContractAddress("Payments", environment);
    
    if (!rolesAddress || !paymentsAddress) {
      throw new Error("Could not find Roles or Payments contract addresses. Deploy them first.");
    }
    
    // Convert addresses to checksummed format for Solidity
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const checksummedRolesAddress = ethers.getAddress(rolesAddress);
    const checksummedPaymentsAddress = ethers.getAddress(paymentsAddress);
    const checksummedUSDCTokenAddress = ethers.getAddress(usdcTokenAddress);
    
    console.log(`📋 Deployment configuration:`);
    console.log(`   Network: ${environment === "production" ? "Avalanche Mainnet" : "Fuji Testnet"}`);
    console.log(`   RPC: ${rpcUrl}`);
    console.log(`   USDC Token: ${checksummedUSDCTokenAddress}`);
    console.log(`   Roles Contract: ${checksummedRolesAddress}`);
    console.log(`   Payments Contract: ${checksummedPaymentsAddress}`);
    
    // Deploy using Foundry
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      throw new Error("Set your PRIVATE_KEY env var for deployment");
    }
    
    // Create deployment script content
    const deploymentScript = `
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/USDCApprovalProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployUSDCApprovalProxy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementation
        USDCApprovalProxy implementation = new USDCApprovalProxy();
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(implementation.initialize, (
                address(${checksummedRolesAddress}), // roles
                address(${checksummedUSDCTokenAddress}), // usdcToken
                address(${checksummedPaymentsAddress}) // paymentsContract
            ))
        );
        
        console.log("USDCApprovalProxy deployed at:", address(proxy));
        console.log("Implementation at:", address(implementation));
        
        vm.stopBroadcast();
    }
}`;
    
    // Write temporary deployment script
    const scriptPath = "./script/deploy-usdc-proxy.s.sol";
    fs.writeFileSync(scriptPath, deploymentScript);
    
    // Execute deployment
    console.log("⏳ Executing deployment...");
    const { stdout, stderr } = await execAsync(
      `forge script ${scriptPath} --rpc-url ${rpcUrl} --broadcast --verify`
    );
    
    console.log("✅ Deployment completed!");
    console.log(stdout);
    
    if (stderr) {
      console.warn("⚠️ Deployment warnings:", stderr);
    }
    
    // Clean up temporary script
    fs.unlinkSync(scriptPath);
    
    // Extract deployed address from output
    const addressMatch = stdout.match(/USDCApprovalProxy deployed at: (0x[a-fA-F0-9]{40})/);
    if (addressMatch) {
      const deployedAddress = addressMatch[1];
      console.log(`🎉 Contract deployed successfully at: ${deployedAddress}`);
      
      // Update the address in the script for future use
      USDC_PROXY_ADDRESSES[environment as keyof typeof USDC_PROXY_ADDRESSES] = deployedAddress;
      
      // Update deployment files so package build will include the new address
      await updateDeploymentFiles(environment, deployedAddress);
      
      console.log("\n📦 Next steps:");
      console.log("1. Run 'npm run build' to update the package with the new address");
      console.log("2. Run 'npm run test-package' to verify the package works correctly");
      console.log("3. The USDCApprovalProxy address will now be available in the published package");
    }
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    throw error;
  }
}

function getExistingContractAddress(contractName: string, environment: string): string | null {
  try {
    const deploymentPath = `./broadcast/deploy.s.sol/${environment === "production" ? "43114" : "43113"}/run-latest.json`;
    const data = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    
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
      if (tx.transactionType === "CREATE" && tx.contractName === "ERC1967Proxy") {
        proxyAddresses.push(tx.contractAddress);
      }
    }
    
    const idx = contractOrder.indexOf(contractName);
    if (idx >= 0 && idx < proxyAddresses.length) {
      return proxyAddresses[idx];
    }
    
    return null;
  } catch (error) {
    console.warn(`Could not read deployment file for ${contractName}`);
    return null;
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