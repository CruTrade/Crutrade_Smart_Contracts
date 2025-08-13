/**
 * @title Payments Configuration
 * @notice Centralized configuration for Payments contract parameters
 * @dev This file contains all configurable parameters for the Payments contract
 * @author Crutrade Team
 */

export interface PaymentsConfig {
  treasuryAddress: string;
  fiatFeePercentage: number; // in basis points (100 = 1%)
  membershipFees: MembershipFeeConfig[];
}

export interface MembershipFeeConfig {
  membershipId: number;
  sellerFee: number; // in basis points
  buyerFee: number; // in basis points
}

/**
 * @notice Default configuration for development/testnet
 */
export const DEFAULT_PAYMENTS_CONFIG: PaymentsConfig = {
  treasuryAddress: "0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6", // Default admin/multisig
  fiatFeePercentage: 300, // 3%
  membershipFees: [
    {
      membershipId: 0,
      sellerFee: 600, // 6% seller fee
      buyerFee: 400, // 4% buyer fee
    },
    {
      membershipId: 1,
      sellerFee: 100, // 1% seller fee
      buyerFee: 100, // 1% buyer fee
    },
  ],
};

/**
 * @notice Configuration for mainnet deployment
 * @dev Uses hardcoded multisig address for treasury
 */
export const MAINNET_PAYMENTS_CONFIG: PaymentsConfig = {
  treasuryAddress: "0xE8c2E3Fb20810b5b65361A54e51b8B3F30e545E9", // Mainnet multisig
  fiatFeePercentage: 250, // 2.5% (lower for mainnet)
  membershipFees: [
    {
      membershipId: 0,
      sellerFee: 0, // 0% seller fee
      buyerFee: 0, // 0% buyer fee
    },
    {
      membershipId: 1,
      sellerFee: 150, // 1.5% seller fee
      buyerFee: 500, // 5% buyer fee
    },
  ],
};

/**
 * @notice Configuration for testnet deployment
 */
export const TESTNET_PAYMENTS_CONFIG: PaymentsConfig = {
  treasuryAddress: "0x45a0744065e5455CaAC18aACB99bBB64154F8cfb", // Default admin for testing
  fiatFeePercentage: 300, // 3%
  membershipFees: [
    {
      membershipId: 0,
      sellerFee: 0, // 0% seller fee
      buyerFee: 0, // 0% buyer fee
    },
    {
      membershipId: 1,
      sellerFee: 150, // 1.5% seller fee
      buyerFee: 500, // 5% buyer fee
    },
  ],
};

/**
 * @notice Get configuration based on environment
 * @param environment The deployment environment
 * @returns PaymentsConfig for the specified environment
 */
export function getPaymentsConfig(environment: string): PaymentsConfig {
  switch (environment.toLowerCase()) {
    case "mainnet":
      return MAINNET_PAYMENTS_CONFIG;
    case "testnet":
    case "fuji":
      return TESTNET_PAYMENTS_CONFIG;
    case "local":
    case "dev":
    default:
      return DEFAULT_PAYMENTS_CONFIG;
  }
}

/**
 * @notice Validate payments configuration
 * @param config The configuration to validate
 * @returns True if configuration is valid
 */
export function validatePaymentsConfig(config: PaymentsConfig): boolean {
  // Validate treasury address
  if (
    !config.treasuryAddress ||
    config.treasuryAddress === "0x0000000000000000000000000000000000000000"
  ) {
    console.error("Invalid treasury address");
    return false;
  }

  // Validate fiat fee percentage (must be <= 10000 basis points = 100%)
  if (config.fiatFeePercentage > 10000) {
    console.error(
      "Fiat fee percentage cannot exceed 100% (10000 basis points)"
    );
    return false;
  }

  // Validate membership fees
  for (const fee of config.membershipFees) {
    if (fee.sellerFee > 10000 || fee.buyerFee > 10000) {
      console.error(
        `Membership fee for ID ${fee.membershipId} cannot exceed 100%`
      );
      return false;
    }
  }

  return true;
}

/**
 * @notice Print configuration for verification
 * @param config The configuration to print
 */
export function printPaymentsConfig(config: PaymentsConfig): void {
  console.log("=== Payments Configuration ===");
  console.log(`Treasury Address: ${config.treasuryAddress}`);
  console.log(
    `Fiat Fee Percentage: ${config.fiatFeePercentage} basis points (${
      config.fiatFeePercentage / 100
    }%)`
  );
  console.log("Membership Fees:");
  for (const fee of config.membershipFees) {
    console.log(
      `  ID ${fee.membershipId}: Seller ${fee.sellerFee / 100}%, Buyer ${
        fee.buyerFee / 100
      }%`
    );
  }
  console.log("=============================");
}
