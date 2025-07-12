#!/usr/bin/env bun

/**
 * @title Roles Configuration Script
 * @notice Demonstrates how to use the roles configuration system
 * @dev This script shows how to validate and use roles configuration
 * @author Crutrade Team
 */

import {
  getRolesConfig,
  validateRolesConfig,
  printRolesConfig,
  checkSecurityIssues,
  getUniqueAddresses,
  getRolesForAddress,
  type RoleConfig,
} from "./roles-config";

// Example usage of the roles configuration system
async function main() {
  console.log("🔧 Roles Configuration System Demo\n");

  // Example 1: Get configuration for different environments
  console.log("=== Environment Configurations ===");

  const environments = ["local", "testnet", "mainnet"];

  for (const env of environments) {
    console.log(`\n📋 ${env.toUpperCase()} Configuration:`);
    const config = getRolesConfig(env);
    printRolesConfig(config, env);

    const isValid = validateRolesConfig(config, env);
    console.log(`✅ Valid: ${isValid ? "Yes" : "No"}`);

    if (isValid) {
      const securityWarnings = checkSecurityIssues(config);
      if (securityWarnings.length > 0) {
        console.log("🔒 Security Warnings:");
        securityWarnings.forEach((warning) => console.log(`  ${warning}`));
      }
    }
  }

  // Example 2: Custom configuration
  console.log("\n=== Custom Configuration Example ===");

  const customConfig: RoleConfig = {
    owner: "0x1234567890123456789012345678901234567890",
    operational1: "0x2345678901234567890123456789012345678901",
    operational2: "0x3456789012345678901234567890123456789012",
    treasury: "0x4567890123456789012345678901234567890123",
    fiat: "0x5678901234567890123456789012345678901234",
    pauser: "0x6789012345678901234567890123456789012345",
    upgrader: "0x7890123456789012345678901234567890123456",
    emergencyAdmin: "0x8901234567890123456789012345678901234567",
    governance: "0x9012345678901234567890123456789012345678",
    partner1: "0xa012345678901234567890123456789012345678",
    partner2: "0xb012345678901234567890123456789012345678",
  };

  console.log("Custom Configuration:");
  printRolesConfig(customConfig, "custom");

  const customValid = validateRolesConfig(customConfig, "custom");
  console.log(`✅ Valid: ${customValid ? "Yes" : "No"}`);

  if (customValid) {
    const securityWarnings = checkSecurityIssues(customConfig);
    if (securityWarnings.length > 0) {
      console.log("🔒 Security Warnings:");
      securityWarnings.forEach((warning) => console.log(`  ${warning}`));
    }
  }

  // Example 3: Invalid configuration
  console.log("\n=== Invalid Configuration Example ===");

  const invalidConfig: RoleConfig = {
    owner: "0x0000000000000000000000000000000000000000", // Invalid: zero address
    operational1: "0x2345678901234567890123456789012345678901",
    operational2: "0x3456789012345678901234567890123456789012",
    treasury: "0x4567890123456789012345678901234567890123",
    fiat: "0x5678901234567890123456789012345678901234",
    pauser: "0x6789012345678901234567890123456789012345",
    upgrader: "0x7890123456789012345678901234567890123456",
  };

  console.log("Invalid Configuration:");
  printRolesConfig(invalidConfig, "invalid");

  const invalidValid = validateRolesConfig(invalidConfig, "invalid");
  console.log(`✅ Valid: ${invalidValid ? "Yes" : "No"}`);

  // Example 4: Role analysis
  console.log("\n=== Role Analysis Example ===");

  const analysisConfig = getRolesConfig("local");
  const uniqueAddresses = getUniqueAddresses(analysisConfig);

  console.log(`Unique addresses: ${uniqueAddresses.length}`);
  uniqueAddresses.forEach((address) => {
    const roles = getRolesForAddress(analysisConfig, address);
    console.log(`  ${address}: ${roles.join(", ")}`);
  });

  // Example 5: Deployment preparation
  console.log("\n=== Deployment Preparation ===");

  const deploymentEnv = process.env.NETWORK || "local";
  const deploymentConfig = getRolesConfig(deploymentEnv);

  console.log(`Preparing deployment for ${deploymentEnv.toUpperCase()}:`);
  console.log(`Owner: ${deploymentConfig.owner}`);
  console.log(
    `Operational addresses: ${deploymentConfig.operational1}, ${deploymentConfig.operational2}`
  );
  console.log(`Treasury: ${deploymentConfig.treasury}`);
  console.log(`Fiat: ${deploymentConfig.fiat}`);

  // Check role distribution
  const ownerRoles = getRolesForAddress(
    deploymentConfig,
    deploymentConfig.owner
  );
  console.log(`\nOwner role distribution: ${ownerRoles.length} roles`);
  if (ownerRoles.length > 4) {
    console.log(
      "⚠️  Owner has many roles - consider distributing for better security"
    );
  }

  // Check for single point of failure
  const uniqueAddrs = getUniqueAddresses(deploymentConfig);
  if (uniqueAddrs.length < 3) {
    console.log("⚠️  Very few unique addresses - consider distributing roles");
  } else {
    console.log("✅ Good role distribution across multiple addresses");
  }

  console.log("\n🚀 Ready for deployment!");
}

// Run the demo
main().catch(console.error);
