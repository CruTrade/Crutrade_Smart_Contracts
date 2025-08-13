/**
 * @title Roles Configuration
 * @notice Centralized configuration for role assignments across different networks
 * @dev This file contains all configurable role assignments for the Crutrade ecosystem
 * @author Crutrade Team
 */

export interface RoleConfig {
  // Core administrative roles
  owner: string;
  operational1: string;
  operational2: string;

  // Financial roles
  treasury: string;
  fiat: string;

  // Security roles
  pauser: string;
  upgrader: string;

  // Additional operational roles (optional)
  lister?: string;
  buyer?: string;
  renewer?: string;
  withdrawer?: string;

  // Emergency roles (optional)
  emergencyAdmin?: string;

  // Governance roles (optional)
  governance?: string;

  // Partner roles (optional)
  partner1?: string;
  partner2?: string;
}

export interface NetworkConfig {
  chainId: number;
  rpc: string;
  usdc: string;
  privateKey: string;
  forgeArgs: string;
  roles: RoleConfig;
}

/**
 * @notice Default configuration for local development
 */
export const LOCAL_ROLES_CONFIG: RoleConfig = {
  owner: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  operational1: "0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC",
  operational2: "0xe812BeeF1F7A62ed142835Ec2622B71AeA858085",
  treasury: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Same as owner for local
  fiat: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Same as owner for local
  pauser: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Same as owner for local
  upgrader: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Same as owner for local
};

const TESTNET_OWNER = "0x45a0744065e5455CaAC18aACB99bBB64154F8cfb";
const TESTNET_HOT_WALLET_1 = "0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC";
const TESTNET_HOT_WALLET_2 = "0xe812BeeF1F7A62ed142835Ec2622B71AeA858085";

/**
 * @notice Configuration for testnet deployment
 * @dev Uses environment variables for sensitive addresses
 */
export const TESTNET_ROLES_CONFIG: RoleConfig = {
  owner: TESTNET_OWNER,
  operational1: TESTNET_HOT_WALLET_1,
  operational2: TESTNET_HOT_WALLET_2,
  treasury: TESTNET_OWNER,
  fiat: TESTNET_HOT_WALLET_1,
  pauser: TESTNET_OWNER,
  upgrader: TESTNET_OWNER,
};

export const MAINNET_MULTISIG = "0xE8c2E3Fb20810b5b65361A54e51b8B3F30e545E9";
export const MAINNET_HOT_WALLET_1 =
  "0xd67E626Cc087477c80Aa48A68a304091537E9A56";
export const MAINNET_HOT_WALLET_2 =
  "0x4E19938Cc3a6cF0d4F0f1394813bb4a9aBa4b912";

/**
 * @notice Configuration for mainnet deployment
 * @dev Uses environment variables for all addresses - MUST be set before deployment
 */
export const MAINNET_ROLES_CONFIG: RoleConfig = {
  owner: MAINNET_MULTISIG,
  operational1: MAINNET_HOT_WALLET_1,
  operational2: MAINNET_HOT_WALLET_2,
  treasury: MAINNET_MULTISIG,
  fiat: MAINNET_HOT_WALLET_2,
  pauser: MAINNET_MULTISIG,
  upgrader: MAINNET_MULTISIG,
};

/**
 * @notice Get roles configuration for a specific environment
 * @param environment The deployment environment
 * @returns RoleConfig for the specified environment
 */
export function getRolesConfig(environment: string): RoleConfig {
  switch (environment.toLowerCase()) {
    case "mainnet":
      return MAINNET_ROLES_CONFIG;
    case "testnet":
    case "fuji":
      return TESTNET_ROLES_CONFIG;
    case "local":
    case "dev":
    default:
      return LOCAL_ROLES_CONFIG;
  }
}

/**
 * @notice Validate roles configuration
 * @param config The configuration to validate
 * @param environment The deployment environment
 * @returns True if configuration is valid
 */
export function validateRolesConfig(
  config: RoleConfig,
  environment: string
): boolean {
  // Required roles for all environments
  const requiredRoles = [
    "owner",
    "operational1",
    "operational2",
    "treasury",
    "fiat",
    "pauser",
    "upgrader",
  ];

  for (const role of requiredRoles) {
    const address = config[role as keyof RoleConfig] as string;
    if (!address || address === "0x0000000000000000000000000000000000000000") {
      console.error(`❌ Missing or invalid ${role} address`);
      return false;
    }

    if (!isValidAddress(address)) {
      console.error(`❌ Invalid ${role} address: ${address}`);
      return false;
    }
  }

  // Additional validation for mainnet
  if (environment.toLowerCase() === "mainnet") {
    if (!config.emergencyAdmin) {
      console.warn("⚠️  No emergency admin set for mainnet (recommended)");
    }

    if (!config.governance) {
      console.warn("⚠️  No governance address set for mainnet (recommended)");
    }
  }

  // Check for duplicate addresses (security risk)
  const addresses = new Set<string>();
  for (const role of requiredRoles) {
    const address = config[role as keyof RoleConfig] as string;
    if (addresses.has(address.toLowerCase())) {
      console.warn(`⚠️  Duplicate address found for role: ${role}`);
    }
    addresses.add(address.toLowerCase());
  }

  return true;
}

/**
 * @notice Print roles configuration for verification
 * @param config The configuration to print
 * @param environment The deployment environment
 */
export function printRolesConfig(
  config: RoleConfig,
  environment: string
): void {
  console.log("=== Roles Configuration ===");
  console.log(`Environment: ${environment.toUpperCase()}`);
  console.log("");

  // Core roles
  console.log("🔑 Core Administrative Roles:");
  console.log(`  Owner: ${config.owner}`);
  console.log(`  Operational 1: ${config.operational1}`);
  console.log(`  Operational 2: ${config.operational2}`);
  console.log("");

  // Financial roles
  console.log("💰 Financial Roles:");
  console.log(`  Treasury: ${config.treasury}`);
  console.log(`  Fiat: ${config.fiat}`);
  console.log("");

  // Security roles
  console.log("🔒 Security Roles:");
  console.log(`  Pauser: ${config.pauser}`);
  console.log(`  Upgrader: ${config.upgrader}`);
  console.log("");

  // Optional roles
  const optionalRoles = [
    { key: "emergencyAdmin", label: "Emergency Admin" },
    { key: "governance", label: "Governance" },
    { key: "partner1", label: "Partner 1" },
    { key: "partner2", label: "Partner 2" },
    { key: "lister", label: "Lister" },
    { key: "buyer", label: "Buyer" },
    { key: "renewer", label: "Renewer" },
    { key: "withdrawer", label: "Withdrawer" },
  ];

  const hasOptionalRoles = optionalRoles.some(
    (role) => config[role.key as keyof RoleConfig]
  );

  if (hasOptionalRoles) {
    console.log("⚙️  Optional Roles:");
    for (const role of optionalRoles) {
      const address = config[role.key as keyof RoleConfig] as string;
      if (address) {
        console.log(`  ${role.label}: ${address}`);
      }
    }
    console.log("");
  }

  console.log("===========================");
}

/**
 * @notice Check if an address is valid
 * @param address The address to validate
 * @returns True if address is valid
 */
function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

/**
 * @notice Get all unique addresses from a roles configuration
 * @param config The roles configuration
 * @returns Array of unique addresses
 */
export function getUniqueAddresses(config: RoleConfig): string[] {
  const addresses = new Set<string>();

  Object.values(config).forEach((value) => {
    if (
      typeof value === "string" &&
      value !== "0x0000000000000000000000000000000000000000"
    ) {
      addresses.add(value.toLowerCase());
    }
  });

  return Array.from(addresses);
}

/**
 * @notice Get role assignments for a specific address
 * @param config The roles configuration
 * @param address The address to check
 * @returns Array of role names assigned to the address
 */
export function getRolesForAddress(
  config: RoleConfig,
  address: string
): string[] {
  const roles: string[] = [];
  const targetAddress = address.toLowerCase();

  Object.entries(config).forEach(([role, addr]) => {
    if (typeof addr === "string" && addr.toLowerCase() === targetAddress) {
      roles.push(role);
    }
  });

  return roles;
}

/**
 * @notice Check for security issues in roles configuration
 * @param config The roles configuration
 * @returns Array of security warnings
 */
export function checkSecurityIssues(config: RoleConfig): string[] {
  const warnings: string[] = [];

  // Check for single point of failure
  const uniqueAddresses = getUniqueAddresses(config);
  if (uniqueAddresses.length < 3) {
    warnings.push(
      "⚠️  Very few unique addresses - consider distributing roles for better security"
    );
  }

  // Check if owner has too many roles
  const ownerRoles = getRolesForAddress(config, config.owner);
  if (ownerRoles.length > 4) {
    warnings.push(
      "⚠️  Owner has many roles - consider distributing for better security"
    );
  }

  // Check for missing emergency admin on mainnet
  if (!config.emergencyAdmin) {
    warnings.push("⚠️  No emergency admin set - recommended for production");
  }

  return warnings;
}

/**
 * @notice Generate environment variables for deployment
 * @param config The roles configuration
 * @returns Object with environment variables
 */
export function generateEnvVars(config: RoleConfig): Record<string, string> {
  return {
    OWNER: config.owner,
    OPERATIONAL_1: config.operational1,
    OPERATIONAL_2: config.operational2,
    TREASURY: config.treasury,
    FIAT: config.fiat,
    PAUSER: config.pauser,
    UPGRADER: config.upgrader,
    ...(config.emergencyAdmin && { EMERGENCY_ADMIN: config.emergencyAdmin }),
    ...(config.governance && { GOVERNANCE: config.governance }),
    ...(config.partner1 && { PARTNER_1: config.partner1 }),
    ...(config.partner2 && { PARTNER_2: config.partner2 }),
    ...(config.lister && { LISTER: config.lister }),
    ...(config.buyer && { BUYER: config.buyer }),
    ...(config.renewer && { RENEWER: config.renewer }),
    ...(config.withdrawer && { WITHDRAWER: config.withdrawer }),
  };
}
