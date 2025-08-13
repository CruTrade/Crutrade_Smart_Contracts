#!/usr/bin/env bun

/**
 * @title Sales Schedule Configuration Script
 * @notice Configures sales schedules for different networks and timezones
 * @dev Handles timezone conversions and network-specific configurations
 * @author Crutrade Team
 */

import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

// Timezone conversion utilities
const TIMEZONE_OFFSETS = {
  "GMT-5": -5 * 60 * 60, // EST/EDT
  "GMT-4": -4 * 60 * 60, // EDT
  "GMT-8": -8 * 60 * 60, // PST/PDT
  "GMT-7": -7 * 60 * 60, // PDT
  "GMT+0": 0, // UTC/GMT
  "GMT+1": 1 * 60 * 60, // CET
  "GMT+2": 2 * 60 * 60, // CEST
  "GMT+5": 5 * 60 * 60, // IST
  "GMT+8": 8 * 60 * 60, // CST
  "GMT+9": 9 * 60 * 60, // JST
} as const;

type Timezone = keyof typeof TIMEZONE_OFFSETS;

interface ScheduleConfig {
  scheduleId: number;
  dayOfWeek: number; // 1-7 (Monday-Sunday)
  hour: number; // 0-23
  minute: number; // 0-59
  timezone: Timezone;
  description: string;
}

interface NetworkConfig {
  name: string;
  rpcUrl: string;
  privateKey: string;
  schedules: ScheduleConfig[];
}

// Chain configuration mapping
const chainConfigs = {
  local: {
    chainId: 31337,
    rpc: "http://localhost:8545",
    privateKey:
      process.env.PRIVATE_KEY ||
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  },
  testnet: {
    chainId: 43113,
    rpc:
      process.env.TESTNET_RPC || "https://api.avax-test.network/ext/bc/C/rpc",
    privateKey: process.env.PRIVATE_KEY || "",
  },
  mainnet: {
    chainId: 43114,
    rpc: process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc",
    privateKey: process.env.PRIVATE_KEY || "",
  },
};

/**
 * Gets contract address from deployment files
 */
async function getContractAddress(contractName: string): Promise<string> {
  try {
    const network = process.env.NETWORK || "local";
    const networkId =
      network === "local" ? "31337" : network === "testnet" ? "43113" : "43114";

    const broadcastPath = `./broadcast/deploy.s.sol/${networkId}/run-latest.json`;

    if (!fs.existsSync(broadcastPath)) {
      throw new Error(`Broadcast file not found: ${broadcastPath}`);
    }

    const broadcastData = JSON.parse(fs.readFileSync(broadcastPath, "utf8"));

    // For upgradeable contracts, use the order-based mapping approach
    if (
      contractName !== "Roles" &&
      contractName !== "CruToken" &&
      contractName !== "Vesting"
    ) {
      const proxyAddresses: string[] = [];

      // Collect all ERC1967Proxy addresses in order
      for (const tx of broadcastData.transactions) {
        if (
          tx.transactionType === "CREATE" &&
          tx.contractName === "ERC1967Proxy"
        ) {
          proxyAddresses.push(tx.contractAddress);
        }
      }

      // Map proxy addresses to contract types based on deployment order
      // The order should be: Roles, Brands, Wrappers, Whitelist, Payments, Sales, Memberships
      const contractOrder = [
        "Roles",
        "Brands",
        "Wrappers",
        "Whitelist",
        "Payments",
        "Sales",
        "Memberships",
      ];

      const contractIndex = contractOrder.indexOf(contractName);
      if (contractIndex >= 0 && contractIndex < proxyAddresses.length) {
        return proxyAddresses[contractIndex];
      }
    }

    // For non-upgradeable contracts, find the direct deployment
    const transaction = broadcastData.transactions.find(
      (tx: any) => tx.contractName === contractName
    );

    if (!transaction) {
      throw new Error(`Contract ${contractName} not found in deployment`);
    }

    return transaction.contractAddress;
  } catch (error) {
    console.error(`Error getting address for ${contractName}:`, error);
    throw error;
  }
}

/**
 * Gets contract ABI from artifacts
 */
async function getContractABI(contractName: string): Promise<any> {
  try {
    const artifactPath = `./out/${contractName}.sol/${contractName}.json`;

    if (!fs.existsSync(artifactPath)) {
      throw new Error(`Artifact file not found: ${artifactPath}`);
    }

    const artifactData = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    return artifactData.abi;
  } catch (error) {
    console.error(`Error getting ABI for ${contractName}:`, error);
    throw error;
  }
}

// Network configurations
const NETWORK_CONFIGS: Record<string, NetworkConfig> = {
  local: {
    name: "Local",
    rpcUrl: "http://localhost:8545",
    privateKey:
      "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    schedules: [
      {
        scheduleId: 2,
        dayOfWeek: 7, // Sunday
        hour: 23, // 11 PM
        minute: 0, // 0 minutes
        timezone: "GMT-5",
        description: "Sunday Night Release (EST)",
      },
    ],
  },
  testnet: {
    name: "Testnet",
    rpcUrl:
      process.env.TESTNET_RPC || "https://api.avax-test.network/ext/bc/C/rpc",
    privateKey: process.env.PRIVATE_KEY || "",
    schedules: [
      {
        scheduleId: 2,
        dayOfWeek: 7, // Sunday
        hour: 22, // 10 PM
        minute: 30, // 30 minutes
        timezone: "GMT-5",
        description: "Sunday Night Release (EST)",
      },
    ],
  },
  mainnet: {
    name: "Mainnet",
    rpcUrl: process.env.MAINNET_RPC || "https://api.avax.network/ext/bc/C/rpc",
    privateKey: process.env.PRIVATE_KEY || "",
    schedules: [
      {
        scheduleId: 16,
        dayOfWeek: 4, // Thursday
        hour: 8, // 7 PM
        minute: 0, // 0 minutes
        timezone: "GMT-5",
        description: "Thursday Night Release (EST)",
      },
    ],
  },
};

/**
 * Converts local time to UTC based on timezone
 */
function convertToUTC(
  hour: number,
  minute: number,
  timezone: Timezone
): { hour: number; minute: number; dayOffset: number } {
  const offset = TIMEZONE_OFFSETS[timezone];
  const totalMinutes = hour * 60 + minute;
  const utcMinutes = totalMinutes - offset / 60;

  // Calculate day offset
  let dayOffset = 0;
  let utcHour = Math.floor(utcMinutes / 60);
  let utcMinute = utcMinutes % 60;

  // Handle negative minutes
  if (utcMinute < 0) {
    utcMinute += 60;
    utcHour -= 1;
  }

  // Handle day rollover
  if (utcHour >= 24) {
    dayOffset = Math.floor(utcHour / 24);
    utcHour = utcHour % 24;
  } else if (utcHour < 0) {
    dayOffset = Math.ceil(utcHour / 24) - 1;
    utcHour = ((utcHour % 24) + 24) % 24;
  }

  return { hour: utcHour, minute: utcMinute, dayOffset };
}

/**
 * Converts UTC time to local time based on timezone
 */
function convertFromUTC(
  hour: number,
  minute: number,
  timezone: Timezone
): { hour: number; minute: number; dayOffset: number } {
  const offset = TIMEZONE_OFFSETS[timezone];
  const totalMinutes = hour * 60 + minute;
  const localMinutes = totalMinutes + offset / 60;

  // Calculate day offset
  let dayOffset = 0;
  let localHour = Math.floor(localMinutes / 60);
  let localMinute = localMinutes % 60;

  // Handle negative minutes
  if (localMinute < 0) {
    localMinute += 60;
    localHour -= 1;
  }

  // Handle day rollover
  if (localHour >= 24) {
    dayOffset = Math.floor(localHour / 24);
    localHour = localHour % 24;
  } else if (localHour < 0) {
    dayOffset = Math.ceil(localHour / 24) - 1;
    localHour = ((localHour % 24) + 24) % 24;
  }

  return { hour: localHour, minute: localMinute, dayOffset };
}

/**
 * Gets day name from day of week number
 */
function getDayName(dayOfWeek: number): string {
  const days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];
  return days[dayOfWeek - 1] || "Unknown";
}

/**
 * Formats time as HH:MM
 */
function formatTime(hour: number, minute: number): string {
  return `${hour.toString().padStart(2, "0")}:${minute
    .toString()
    .padStart(2, "0")}`;
}

/**
 * Validates schedule configuration
 */
function validateSchedule(schedule: ScheduleConfig): string[] {
  const errors: string[] = [];

  if (schedule.dayOfWeek < 1 || schedule.dayOfWeek > 7) {
    errors.push("Day of week must be between 1 (Monday) and 7 (Sunday)");
  }

  if (schedule.hour < 0 || schedule.hour > 23) {
    errors.push("Hour must be between 0 and 23");
  }

  if (schedule.minute < 0 || schedule.minute > 59) {
    errors.push("Minute must be between 0 and 59");
  }

  if (!TIMEZONE_OFFSETS[schedule.timezone]) {
    errors.push(`Invalid timezone: ${schedule.timezone}`);
  }

  return errors;
}

/**
 * Displays schedule information
 */
function displaySchedule(
  schedule: ScheduleConfig,
  isUTC: boolean = false
): void {
  const utcTime = convertToUTC(
    schedule.hour,
    schedule.minute,
    schedule.timezone
  );

  // Calculate the actual day for UTC
  const utcDay = ((schedule.dayOfWeek - 1 + utcTime.dayOffset + 7) % 7) + 1;

  console.log(`📅 Schedule ${schedule.scheduleId}: ${schedule.description}`);
  console.log(`   Day: ${getDayName(schedule.dayOfWeek)}`);

  if (isUTC) {
    console.log(`   Time: ${formatTime(utcTime.hour, utcTime.minute)} UTC`);
    console.log(`   UTC Day: ${getDayName(utcDay)}`);
  } else {
    console.log(
      `   Time: ${formatTime(schedule.hour, schedule.minute)} ${
        schedule.timezone
      }`
    );
    console.log(
      `   UTC: ${formatTime(utcTime.hour, utcTime.minute)} UTC (${getDayName(
        utcDay
      )})`
    );
  }
}

/**
 * Read current schedules from the contract
 */
async function readSchedules() {
  const network = process.env.NETWORK || "local";
  const config = NETWORK_CONFIGS[network];

  if (!config) {
    console.error(`❌ Unknown network: ${network}`);
    console.log("Available networks:", Object.keys(NETWORK_CONFIGS).join(", "));
    process.exit(1);
  }

  console.log(`📖 Reading schedules from ${config.name} network\n`);

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(config.rpcUrl);
  const wallet = new ethers.Wallet(config.privateKey, provider);

  console.log(`📡 Connected to ${config.name} network`);
  console.log(`👤 Account: ${wallet.address}\n`);

  // Get contract address and ABI
  const salesAddress = await getContractAddress("Sales");
  const salesAbi = await getContractABI("Sales");

  if (!salesAddress || !salesAbi) {
    console.error("❌ Failed to load Sales contract information");
    process.exit(1);
  }

  console.log(`🏗️  Sales contract: ${salesAddress}\n`);

  // Create contract instance
  const salesContract = new ethers.Contract(salesAddress, salesAbi, provider);

  // Read current schedules
  console.log("🔍 Reading current schedules...");
  try {
    const currentSchedules = await salesContract.getActiveSchedules();

    console.log(`📊 Found ${currentSchedules[0].length} active schedules`);
    for (let i = 0; i < currentSchedules[0].length; i++) {
      const scheduleId = Number(currentSchedules[0][i]);
      const dayOfWeek = Number(currentSchedules[1][i]);
      const hour = Number(currentSchedules[2][i]);
      const minute = Number(currentSchedules[3][i]);

      console.log(
        `   Schedule ${scheduleId}: ${getDayName(dayOfWeek)} at ${formatTime(
          hour,
          minute
        )} UTC`
      );
    }
  } catch (error) {
    console.log(
      "⚠️  Could not fetch current schedules (contract may not be deployed)"
    );
    console.log("Error:", error);
  }

  console.log("\n✅ Schedule reading complete!");
}

/**
 * Main function to configure schedules
 */
async function configureSchedules() {
  const network = process.env.NETWORK || "local";
  const config = NETWORK_CONFIGS[network];

  if (!config) {
    console.error(`❌ Unknown network: ${network}`);
    console.log("Available networks:", Object.keys(NETWORK_CONFIGS).join(", "));
    process.exit(1);
  }

  console.log(`🚀 Configuring schedules for ${config.name} network\n`);

  // Validate configurations
  console.log("🔍 Validating schedule configurations...");
  let hasErrors = false;

  for (const schedule of config.schedules) {
    const errors = validateSchedule(schedule);
    if (errors.length > 0) {
      console.error(`❌ Errors in schedule ${schedule.scheduleId}:`);
      errors.forEach((error) => console.error(`   ${error}`));
      hasErrors = true;
    }
  }

  if (hasErrors) {
    console.error("\n❌ Configuration validation failed");
    process.exit(1);
  }

  console.log("✅ All schedule configurations are valid\n");

  // Display schedules
  console.log("📋 Schedule Configuration:");
  for (const schedule of config.schedules) {
    displaySchedule(schedule);
    console.log("");
  }

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(config.rpcUrl);
  const wallet = new ethers.Wallet(config.privateKey, provider);

  // Get contract addresses and ABI
  const salesAddress = await getContractAddress("Sales");
  const salesAbi = await getContractABI("Sales");

  if (!salesAddress || !salesAbi) {
    console.error("❌ Failed to load Sales contract information");
    process.exit(1);
  }

  console.log(`📡 Connected to ${config.name} network`);
  console.log(`🏗️  Sales contract: ${salesAddress}`);
  console.log(`👤 Account: ${wallet.address}\n`);

  // Create contract instance
  const salesContract = new ethers.Contract(salesAddress, salesAbi, wallet);

  // Check current schedules
  console.log("🔍 Checking current schedules...");
  try {
    const currentSchedules = await salesContract.getActiveSchedules();

    console.log(`📊 Found ${currentSchedules[0].length} active schedules`);
    for (let i = 0; i < currentSchedules[0].length; i++) {
      const scheduleId = Number(currentSchedules[0][i]);
      const dayOfWeek = Number(currentSchedules[1][i]);
      const hour = Number(currentSchedules[2][i]);
      const minute = Number(currentSchedules[3][i]);

      console.log(
        `   Schedule ${scheduleId}: ${getDayName(dayOfWeek)} at ${formatTime(
          hour,
          minute
        )} UTC`
      );
    }
    console.log("");
  } catch (error) {
    console.log(
      "⚠️  Could not fetch current schedules (contract may not be deployed)"
    );
    console.log("");
  }

  // Prepare schedule data
  const scheduleIds: number[] = [];
  const daysOfWeek: number[] = [];
  const hourValues: number[] = [];
  const minuteValues: number[] = [];

  for (const schedule of config.schedules) {
    const utcTime = convertToUTC(
      schedule.hour,
      schedule.minute,
      schedule.timezone
    );

    // Calculate the actual day for UTC based on day offset
    const utcDay = ((schedule.dayOfWeek - 1 + utcTime.dayOffset + 7) % 7) + 1;

    scheduleIds.push(schedule.scheduleId);
    daysOfWeek.push(utcDay);
    hourValues.push(utcTime.hour);
    minuteValues.push(utcTime.minute);
  }

  // Display what will be set
  console.log("🎯 Schedules to be configured:");
  for (let i = 0; i < scheduleIds.length; i++) {
    const schedule = config.schedules[i];
    const utcTime = convertToUTC(
      schedule.hour,
      schedule.minute,
      schedule.timezone
    );

    console.log(
      `   ID ${scheduleIds[i]}: ${getDayName(daysOfWeek[i])} at ${formatTime(
        utcTime.hour,
        utcTime.minute
      )} UTC`
    );
    console.log(
      `      (${formatTime(schedule.hour, schedule.minute)} ${
        schedule.timezone
      } → ${getDayName(daysOfWeek[i])} ${formatTime(
        utcTime.hour,
        utcTime.minute
      )} UTC)`
    );
  }
  console.log("");

  // Ask for confirmation
  const readline = require("readline");
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const answer = await new Promise<string>((resolve) => {
    rl.question(
      "🤔 Proceed with configuring these schedules? (y/N): ",
      resolve
    );
  });
  rl.close();

  if (answer.toLowerCase() !== "y" && answer.toLowerCase() !== "yes") {
    console.log("❌ Operation cancelled");
    process.exit(0);
  }

  // Execute the transaction
  console.log("\n🚀 Executing schedule configuration...");

  try {
    const tx = await salesContract.setSchedules(
      scheduleIds,
      daysOfWeek,
      hourValues,
      minuteValues
    );

    console.log(`✅ Transaction submitted: ${tx.hash}`);

    // Wait for confirmation
    console.log("⏳ Waiting for confirmation...");
    const receipt = await tx.wait();

    if (receipt && receipt.status === 1) {
      console.log("✅ Schedules configured successfully!");
      console.log(`📋 Transaction hash: ${tx.hash}`);
      console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    } else {
      console.error("❌ Transaction failed");
    }
  } catch (error) {
    console.error("❌ Failed to configure schedules:", error);
    process.exit(1);
  }

  // Verify the configuration
  console.log("\n🔍 Verifying configuration...");
  try {
    const updatedSchedules = await salesContract.getActiveSchedules();

    console.log(`📊 Updated schedules (${updatedSchedules[0].length} total):`);
    for (let i = 0; i < updatedSchedules[0].length; i++) {
      const scheduleId = Number(updatedSchedules[0][i]);
      const dayOfWeek = Number(updatedSchedules[1][i]);
      const hour = Number(updatedSchedules[2][i]);
      const minute = Number(updatedSchedules[3][i]);

      console.log(
        `   Schedule ${scheduleId}: ${getDayName(dayOfWeek)} at ${formatTime(
          hour,
          minute
        )} UTC`
      );
    }

    // Check if our new schedules are there
    const newScheduleIds = new Set(scheduleIds);
    const foundSchedules = updatedSchedules[0].filter((id: any) =>
      newScheduleIds.has(Number(id))
    );

    if (foundSchedules.length === scheduleIds.length) {
      console.log("\n✅ All new schedules are active!");
    } else {
      console.log("\n⚠️  Some schedules may not be active yet");
    }
  } catch (error) {
    console.log("⚠️  Could not verify schedules:", error);
  }

  console.log("\n🎉 Schedule configuration complete!");
}

/**
 * Delete schedules from the contract
 */
async function deleteSchedules() {
  const network = process.env.NETWORK || "local";
  const config = NETWORK_CONFIGS[network];

  if (!config) {
    console.error(`❌ Unknown network: ${network}`);
    console.log("Available networks:", Object.keys(NETWORK_CONFIGS).join(", "));
    process.exit(1);
  }

  console.log(`🗑️  Deleting schedules from ${config.name} network\n`);

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(config.rpcUrl);
  const wallet = new ethers.Wallet(config.privateKey, provider);

  // Get contract addresses and ABI
  const salesAddress = await getContractAddress("Sales");
  const salesAbi = await getContractABI("Sales");

  if (!salesAddress || !salesAbi) {
    console.error("❌ Failed to load Sales contract information");
    process.exit(1);
  }

  console.log(`📡 Connected to ${config.name} network`);
  console.log(`🏗️  Sales contract: ${salesAddress}`);
  console.log(`👤 Account: ${wallet.address}\n`);

  // Create contract instance
  const salesContract = new ethers.Contract(salesAddress, salesAbi, wallet);

  // Check current schedules
  console.log("🔍 Checking current schedules...");
  let currentSchedules;
  try {
    currentSchedules = await salesContract.getActiveSchedules();

    if (currentSchedules[0].length === 0) {
      console.log("📊 No active schedules found");
      return;
    }

    console.log(`📊 Found ${currentSchedules[0].length} active schedules:`);
    for (let i = 0; i < currentSchedules[0].length; i++) {
      const scheduleId = Number(currentSchedules[0][i]);
      const dayOfWeek = Number(currentSchedules[1][i]);
      const hour = Number(currentSchedules[2][i]);
      const minute = Number(currentSchedules[3][i]);

      console.log(
        `   Schedule ${scheduleId}: ${getDayName(dayOfWeek)} at ${formatTime(
          hour,
          minute
        )} UTC`
      );
    }
    console.log("");
  } catch (error) {
    console.log("⚠️  Could not fetch current schedules:", error);
    return;
  }

  // Get schedule IDs to delete from command line arguments
  const scheduleIdsToDelete = process.argv
    .slice(3)
    .map((id) => parseInt(id))
    .filter((id) => !isNaN(id));

  if (scheduleIdsToDelete.length === 0) {
    console.log("❌ No schedule IDs provided for deletion");
    console.log("");
    console.log("Usage:");
    console.log(
      "  bun run script/configure-schedules.ts delete <id1> [id2] [id3] ..."
    );
    console.log("");
    console.log("Examples:");
    console.log("  bun run script/configure-schedules.ts delete 10");
    console.log("  bun run script/configure-schedules.ts delete 2 3 4");
    console.log(
      "  NETWORK=mainnet bun run script/configure-schedules.ts delete 10"
    );
    process.exit(1);
  }

  // Validate that the schedules exist
  const existingScheduleIds = currentSchedules[0].map((id: any) => Number(id));
  const validScheduleIds = scheduleIdsToDelete.filter((id) =>
    existingScheduleIds.includes(id)
  );
  const invalidScheduleIds = scheduleIdsToDelete.filter(
    (id) => !existingScheduleIds.includes(id)
  );

  if (invalidScheduleIds.length > 0) {
    console.log(
      `⚠️  Warning: The following schedule IDs do not exist: ${invalidScheduleIds.join(
        ", "
      )}`
    );
  }

  if (validScheduleIds.length === 0) {
    console.log("❌ No valid schedule IDs to delete");
    process.exit(1);
  }

  console.log(`🎯 Schedules to be deleted: ${validScheduleIds.join(", ")}`);

  // Ask for confirmation
  const readline = require("readline");
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const answer = await new Promise<string>((resolve) => {
    rl.question("🤔 Proceed with deleting these schedules? (y/N): ", resolve);
  });
  rl.close();

  if (answer.toLowerCase() !== "y" && answer.toLowerCase() !== "yes") {
    console.log("❌ Operation cancelled");
    process.exit(0);
  }

  // Execute the transaction
  console.log("\n🚀 Executing schedule deletion...");

  try {
    const tx = await salesContract.removeSchedules(validScheduleIds);

    console.log(`✅ Transaction submitted: ${tx.hash}`);

    // Wait for confirmation
    console.log("⏳ Waiting for confirmation...");
    const receipt = await tx.wait();

    if (receipt && receipt.status === 1) {
      console.log("✅ Schedules deleted successfully!");
      console.log(`📋 Transaction hash: ${tx.hash}`);
      console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);
    } else {
      console.error("❌ Transaction failed");
    }
  } catch (error) {
    console.error("❌ Failed to delete schedules:", error);
    process.exit(1);
  }

  // Verify the deletion
  console.log("\n🔍 Verifying deletion...");
  try {
    const updatedSchedules = await salesContract.getActiveSchedules();

    console.log(
      `📊 Remaining schedules (${updatedSchedules[0].length} total):`
    );
    for (let i = 0; i < updatedSchedules[0].length; i++) {
      const scheduleId = Number(updatedSchedules[0][i]);
      const dayOfWeek = Number(updatedSchedules[1][i]);
      const hour = Number(updatedSchedules[2][i]);
      const minute = Number(updatedSchedules[3][i]);

      console.log(
        `   Schedule ${scheduleId}: ${getDayName(dayOfWeek)} at ${formatTime(
          hour,
          minute
        )} UTC`
      );
    }

    // Check if our deleted schedules are gone
    const remainingScheduleIds = updatedSchedules[0].map((id: any) =>
      Number(id)
    );
    const stillExist = validScheduleIds.filter((id) =>
      remainingScheduleIds.includes(id)
    );

    if (stillExist.length === 0) {
      console.log("\n✅ All specified schedules have been deleted!");
    } else {
      console.log(
        `\n⚠️  Some schedules may still exist: ${stillExist.join(", ")}`
      );
    }
  } catch (error) {
    console.log("⚠️  Could not verify deletion:", error);
  }

  console.log("\n🎉 Schedule deletion complete!");
}

/**
 * Main execution function
 */
async function main() {
  const mode = process.argv[2] || "write"; // Default to write mode

  if (mode === "read") {
    await readSchedules();
  } else if (mode === "write") {
    await configureSchedules();
  } else if (mode === "delete") {
    await deleteSchedules();
  } else {
    console.error("❌ Invalid mode. Use 'read', 'write', or 'delete'");
    console.log("");
    console.log("Usage:");
    console.log(
      "  bun run script/configure-schedules.ts read                    # Read current schedules"
    );
    console.log(
      "  bun run script/configure-schedules.ts write                   # Configure new schedules (default)"
    );
    console.log(
      "  bun run script/configure-schedules.ts delete <id1> [id2] ...  # Delete schedules"
    );
    console.log("");
    console.log("Examples:");
    console.log("  NETWORK=mainnet bun run script/configure-schedules.ts read");
    console.log(
      "  NETWORK=testnet bun run script/configure-schedules.ts write"
    );
    console.log("  bun run script/configure-schedules.ts delete 10");
    console.log("  bun run script/configure-schedules.ts delete 2 3 4");
    process.exit(1);
  }
}

// Run the script
main().catch((error) => {
  console.error("❌ Script failed:", error);
  process.exit(1);
});
