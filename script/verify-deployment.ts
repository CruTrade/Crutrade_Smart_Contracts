import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

import {
  getRolesConfig,
  generateEnvVars as generateRolesEnvVars,
} from "./roles-config";
import { getPaymentsConfig } from "./payments-config";

interface BroadcastTransaction {
  transactionType: string;
  contractName: string;
  contractAddress: string;
  constructorArgs: any[];
}

interface BroadcastFile {
  transactions: BroadcastTransaction[];
}

/**
 * Extracts contract addresses from Foundry broadcast files
 */
class DeploymentAddressExtractor {
  private broadcastDir: string;
  private networkId: string;

  constructor(
    deployScript: string = "deploy.s.sol",
    networkId: string = "31337"
  ) {
    this.broadcastDir = `./broadcast/${deployScript}`;
    this.networkId = networkId;
  }

  /**
   * Gets the latest broadcast file path
   */
  private getLatestBroadcastPath(): string {
    const networkDir = path.join(this.broadcastDir, this.networkId);
    const dryRunDir = path.join(networkDir, "dry-run");

    // Check if dry-run directory exists (most common case)
    if (fs.existsSync(dryRunDir)) {
      const files = fs
        .readdirSync(dryRunDir)
        .filter((file) => file.startsWith("run-") && file.endsWith(".json"))
        .sort()
        .reverse();

      if (files.length === 0) {
        throw new Error(`No broadcast files found in ${dryRunDir}`);
      }

      return path.join(dryRunDir, files[0]);
    }

    // Fallback: check network directory directly
    if (!fs.existsSync(networkDir)) {
      throw new Error(`Broadcast directory not found: ${networkDir}`);
    }

    const files = fs
      .readdirSync(networkDir)
      .filter((file) => file.startsWith("run-") && file.endsWith(".json"))
      .sort()
      .reverse();

    if (files.length === 0) {
      throw new Error(`No broadcast files found in ${networkDir}`);
    }

    return path.join(networkDir, files[0]);
  }

  /**
   * Extracts contract addresses from broadcast file
   */
  extractAddresses(): Record<string, string> {
    const broadcastPath = this.getLatestBroadcastPath();
    console.log(`Reading broadcast file: ${broadcastPath}`);

    const broadcastData: BroadcastFile = JSON.parse(
      fs.readFileSync(broadcastPath, "utf8")
    );

    const addresses: Record<string, string> = {};

    for (const tx of broadcastData.transactions) {
      if (tx.contractAddress && tx.contractName) {
        // Map contract names to our expected keys
        const key = this.mapContractName(tx.contractName);
        if (key) {
          addresses[key] = tx.contractAddress;
          console.log(`  Found ${tx.contractName} at ${tx.contractAddress}`);
        }
      }
    }

    return addresses;
  }

  /**
   * Maps contract names from broadcast to our expected keys
   */
  private mapContractName(contractName: string): string | null {
    const mapping: Record<string, string> = {
      Roles: "ROLES_ADDRESS",
      Brands: "BRANDS_ADDRESS",
      Wrappers: "WRAPPERS_ADDRESS",
      Whitelist: "WHITELIST_ADDRESS",
      Payments: "PAYMENTS_ADDRESS",
      Sales: "SALES_ADDRESS",
      Memberships: "MEMBERSHIPS_ADDRESS",
    };

    return mapping[contractName] || null;
  }
}

/**
 * Main verification runner
 */
class DeploymentVerifier {
  private extractor: DeploymentAddressExtractor;
  private rolesConfig: any;
  private paymentsConfig: any;
  private network: string;

  constructor(
    networkId: string = "31337",
    deployScript: string = "deploy.s.sol",
    network: string = "local"
  ) {
    this.extractor = new DeploymentAddressExtractor(deployScript, networkId);
    this.network = network;
    this.rolesConfig = getRolesConfig(network);
    this.paymentsConfig = getPaymentsConfig(network);
  }

  /**
   * Runs the verification process
   */
  async run() {
    console.log("=== Crutrade Deployment Verification ===");
    console.log(`Network: ${this.network}`);
    console.log("");

    try {
      // Extract addresses from broadcast file
      const addresses = this.extractor.extractAddresses();

      // Set environment variables for the Foundry script
      this.setEnvironmentVariables(addresses);

      // Run the Foundry verification script
      await this.runFoundryScript();
    } catch (error) {
      console.error("Verification failed:", error);
      process.exit(1);
    }
  }

  /**
   * Sets environment variables for the Foundry script
   */
  private setEnvironmentVariables(addresses: Record<string, string>) {
    console.log("Setting environment variables:");

    // Set contract addresses
    for (const [key, address] of Object.entries(addresses)) {
      process.env[key] = address;
      console.log(`  ${key}: ${address}`);
    }

    // Set network
    process.env.NETWORK = this.network;

    // Load environment variables from roles configuration
    console.log("");
    console.log("Loading environment variables from roles configuration...");
    const rolesEnvVars = generateRolesEnvVars(this.rolesConfig);
    for (const [key, value] of Object.entries(rolesEnvVars)) {
      process.env[key] = value;
      console.log(`  ${key}: ${value}`);
    }

    // Load environment variables from payments configuration
    console.log("");
    console.log("Loading environment variables from payments configuration...");
    process.env.TREASURY_ADDRESS = this.paymentsConfig.treasuryAddress;
    process.env.FIAT_FEE_PERCENTAGE = String(
      this.paymentsConfig.fiatFeePercentage
    );
    process.env.MEMBERSHIP_FEES = JSON.stringify(
      this.paymentsConfig.membershipFees
    );

    console.log(`  TREASURY_ADDRESS: ${this.paymentsConfig.treasuryAddress}`);
    console.log(
      `  FIAT_FEE_PERCENTAGE: ${this.paymentsConfig.fiatFeePercentage}`
    );
    console.log(
      `  MEMBERSHIP_FEES: ${JSON.stringify(this.paymentsConfig.membershipFees)}`
    );

    // Write environment variables to a file for shell scripts to use
    this.writeEnvFile();

    // Load required environment variables
    this.loadRequiredEnvVars();

    console.log("");
  }

  /**
   * Writes environment variables to a file for shell scripts to source
   */
  private writeEnvFile() {
    const envFile = ".env.verification";
    const fs = require("fs");

    let envContent = "";

    // Add contract addresses
    for (const [key, value] of Object.entries(process.env)) {
      if (
        key.includes("_ADDRESS") ||
        key === "OWNER" ||
        key === "OPERATIONAL_1" ||
        key === "OPERATIONAL_2" ||
        key === "OPERATIONAL_3" ||
        key === "OPERATIONAL_4" ||
        key === "TREASURY_ADDRESS" ||
        key === "FIAT_FEE_PERCENTAGE" ||
        key === "MEMBERSHIP_FEES" ||
        key === "NETWORK"
      ) {
        envContent += `${key}=${value}\n`;
      }
    }

    fs.writeFileSync(envFile, envContent);
    console.log(`  Environment variables written to ${envFile}`);
  }

  /**
   * Loads required environment variables and validates them
   */
  private loadRequiredEnvVars() {
    const requiredVars = [
      "OWNER",
      "OPERATIONAL_1",
      "OPERATIONAL_2",
      "TREASURY_ADDRESS",
      "FIAT_FEE_PERCENTAGE",
    ];

    const missingVars: string[] = [];

    for (const varName of requiredVars) {
      if (!process.env[varName]) {
        missingVars.push(varName);
      }
    }

    if (missingVars.length > 0) {
      console.warn("Warning: Missing environment variables:");
      for (const varName of missingVars) {
        console.warn(`  - ${varName}`);
      }
      console.warn("These may cause verification to fail.");
    } else {
      console.log("✅ All required environment variables are set");
    }
  }

  /**
   * Runs the Foundry verification script
   */
  private async runFoundryScript(): Promise<void> {
    console.log("Running Foundry verification script...");

    try {
      const rpcUrl = this.getRpcUrl();
      const command = `forge script script/verify-deployment.s.sol:DeploymentVerifier --rpc-url ${rpcUrl} --broadcast`;

      console.log(`Executing: ${command}`);
      const output = execSync(command, {
        encoding: "utf8",
        stdio: "inherit",
        env: { ...process.env },
      });

      console.log("Verification script completed successfully");
    } catch (error) {
      console.error("Failed to run verification script:", error);
      throw error;
    }
  }

  /**
   * Gets the RPC URL for the current network
   */
  private getRpcUrl(): string {
    switch (this.network) {
      case "mainnet":
        return (
          process.env.AVALANCHE_RPC_URL ||
          "https://api.avax.network/ext/bc/C/rpc"
        );
      case "fuji":
        return (
          process.env.FUJI_RPC_URL ||
          "https://api.avax-test.network/ext/bc/C/rpc"
        );
      case "local":
        return process.env.ANVIL_RPC_URL || "http://localhost:8545";
      default:
        return process.env.ANVIL_RPC_URL || "http://localhost:8545";
    }
  }
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);
  const network = args[0] || "local";
  const networkId = args[1] || "31337";
  const deployScript = args[2] || "deploy.s.sol";

  console.log(`Starting verification for network: ${network}`);
  console.log(`Network ID: ${networkId}`);
  console.log(`Deploy script: ${deployScript}`);
  console.log("");

  const verifier = new DeploymentVerifier(networkId, deployScript, network);
  await verifier.run();
}

// Run if called directly
if (require.main === module) {
  main().catch((error) => {
    console.error("Verification failed:", error);
    process.exit(1);
  });
}

export { DeploymentVerifier, DeploymentAddressExtractor };
