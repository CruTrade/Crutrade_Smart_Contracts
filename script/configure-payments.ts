#!/usr/bin/env bun

/**
 * @title Payments Configuration Script
 * @notice Demonstrates how to use the payments configuration system
 * @dev This script shows how to validate and use payments configuration
 * @author Crutrade Team
 */

import {
  getPaymentsConfig,
  validatePaymentsConfig,
  printPaymentsConfig,
  type PaymentsConfig,
} from "./payments-config";

// Example usage of the payments configuration system
async function main() {
  console.log("🔧 Payments Configuration System Demo\n");

  // Example 1: Get configuration for different environments
  console.log("=== Environment Configurations ===");

  const environments = ["local", "testnet", "mainnet"];

  for (const env of environments) {
    console.log(`\n📋 ${env.toUpperCase()} Configuration:`);
    const config = getPaymentsConfig(env);
    printPaymentsConfig(config);

    const isValid = validatePaymentsConfig(config);
    console.log(`✅ Valid: ${isValid ? "Yes" : "No"}`);
  }

  // Example 2: Custom configuration
  console.log("\n=== Custom Configuration Example ===");

  const customConfig: PaymentsConfig = {
    treasuryAddress: "0x1234567890123456789012345678901234567890",
    fiatFeePercentage: 200, // 2%
    membershipFees: [
      {
        membershipId: 0,
        sellerFee: 400, // 4%
        buyerFee: 200, // 2%
      },
      {
        membershipId: 1,
        sellerFee: 200, // 2%
        buyerFee: 100, // 1%
      },
      {
        membershipId: 2,
        sellerFee: 50, // 0.5%
        buyerFee: 50, // 0.5%
      },
    ],
  };

  console.log("Custom Configuration:");
  printPaymentsConfig(customConfig);

  const customValid = validatePaymentsConfig(customConfig);
  console.log(`✅ Valid: ${customValid ? "Yes" : "No"}`);

  // Example 3: Invalid configuration
  console.log("\n=== Invalid Configuration Example ===");

  const invalidConfig: PaymentsConfig = {
    treasuryAddress: "0x0000000000000000000000000000000000000000", // Invalid: zero address
    fiatFeePercentage: 15000, // Invalid: > 100%
    membershipFees: [
      {
        membershipId: 0,
        sellerFee: 15000, // Invalid: > 100%
        buyerFee: 200,
      },
    ],
  };

  console.log("Invalid Configuration:");
  printPaymentsConfig(invalidConfig);

  const invalidValid = validatePaymentsConfig(invalidConfig);
  console.log(`✅ Valid: ${invalidValid ? "Yes" : "No"}`);

  // Example 4: Deployment preparation
  console.log("\n=== Deployment Preparation ===");

  const deploymentEnv = process.env.NETWORK || "local";
  const deploymentConfig = getPaymentsConfig(deploymentEnv);

  console.log(`Preparing deployment for ${deploymentEnv.toUpperCase()}:`);
  console.log(`Treasury Address: ${deploymentConfig.treasuryAddress}`);
  console.log(`Fiat Fee: ${deploymentConfig.fiatFeePercentage / 100}%`);
  console.log(`Membership Tiers: ${deploymentConfig.membershipFees.length}`);

  // Calculate total fees for transparency
  let totalSellerFees = 0;
  let totalBuyerFees = 0;

  for (const fee of deploymentConfig.membershipFees) {
    totalSellerFees += fee.sellerFee;
    totalBuyerFees += fee.buyerFee;
  }

  console.log(`\nFee Summary:`);
  console.log(
    `- Highest Seller Fee: ${
      Math.max(...deploymentConfig.membershipFees.map((f) => f.sellerFee)) / 100
    }%`
  );
  console.log(
    `- Highest Buyer Fee: ${
      Math.max(...deploymentConfig.membershipFees.map((f) => f.buyerFee)) / 100
    }%`
  );
  console.log(`- Total Seller Fees: ${totalSellerFees / 100}%`);
  console.log(`- Total Buyer Fees: ${totalBuyerFees / 100}%`);

  console.log("\n🚀 Ready for deployment!");
}

// Run the demo
main().catch(console.error);
