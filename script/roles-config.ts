/**
 * @title Roles Configuration
 * @notice Centralized configuration for role assignments across different networks
 * @dev This file contains all configurable role assignments for the Crutrade ecosystem
 * @author Crutrade Team
 */

export interface RoleConfig {
  // Core administrative roles
  owner: string;
  operational1: string; // Server signing key (unfunded)
  operational2: string; // OpenZeppelin relayer 1 (funded)
  operational3?: string; // OpenZeppelin relayer 2 (funded) - optional
  operational4?: string; // Deployer or extra operational (optional)

  // Financial roles
  treasury: string;
  fiat: string;

  // Security roles
  pauser: string;
  upgrader: string;

  // Brand ownership
  brandOwner: string;

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

export const ANVIL_1_DEPLOYER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
export const ANVIL_2_MULTISIG = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
export const ANVIL_3_OPERATIONAL = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
export const ANVIL_4_OPERATIONAL = "0x90F79bf6EB2c4f870365E785982E1f101E93b906";
export const ANVIL_5_SIGNER = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";

/**
 * @notice Default configuration for local development
 */
export const LOCAL_ROLES_CONFIG: RoleConfig = {
  owner: ANVIL_1_DEPLOYER,
  operational1: ANVIL_1_DEPLOYER,
  operational2: ANVIL_3_OPERATIONAL,
  operational3: ANVIL_4_OPERATIONAL,
  operational4: ANVIL_5_SIGNER, // Deployer (same as owner for local)
  treasury: ANVIL_2_MULTISIG,
  fiat: ANVIL_3_OPERATIONAL,
  pauser: ANVIL_2_MULTISIG,
  upgrader: ANVIL_2_MULTISIG,
  brandOwner: ANVIL_2_MULTISIG, // Multisig owns the brand
};

// TODO: Replace these with your actual testnet addresses for testing gasless functionality
const TESTNET_MULTISIG = "0x45a0744065e5455CaAC18aACB99bBB64154F8cfb";
const TESTNET_SERVER_SIGNING_KEY = "0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC";
const TESTNET_OPENZEPPELIN_RELAYER_1 =
  "0xe812BeeF1F7A62ed142835Ec2622B71AeA858085";
const TESTNET_OPENZEPPELIN_RELAYER_2 =
  "0x742d35Cc6234C10B2C13A1b3B8F5D202F69B6F03"; // Add your second relayer
const TESTNET_DEPLOYER = "0x45a0744065e5455CaAC18aACB99bBB64154F8cfb";

/**
 * @notice Configuration for testnet deployment - Gasless Marketplace Testing
 * @dev Mirrors mainnet setup for testing gasless operations
 */
export const TESTNET_ROLES_CONFIG: RoleConfig = {
  // Multisig (for testing admin functions)
  owner: TESTNET_MULTISIG,
  pauser: TESTNET_MULTISIG,
  upgrader: TESTNET_MULTISIG,
  treasury: TESTNET_MULTISIG,
  brandOwner: TESTNET_MULTISIG, // Multisig owns the brand

  // Server signing key (unfunded, for signing)
  operational1: TESTNET_SERVER_SIGNING_KEY,

  // OpenZeppelin relayers (funded with testnet AVAX)
  operational2: TESTNET_OPENZEPPELIN_RELAYER_1,
  operational3: TESTNET_OPENZEPPELIN_RELAYER_2,
  operational4: TESTNET_DEPLOYER,

  // FIAT role
  fiat: TESTNET_SERVER_SIGNING_KEY,
};

// TODO: Replace these with your actual addresses
export const MAINNET_MULTISIG = "0xE8c2E3Fb20810b5b65361A54e51b8B3F30e545E9";
export const MAINNET_SERVER_SIGNING_KEY =
  "0xc4adA1C98770480655EFFE770813556880ff370e";
export const MAINNET_OPENZEPPELIN_RELAYER_1 =
  "0xd67E626Cc087477c80Aa48A68a304091537E9A56";
export const MAINNET_OPENZEPPELIN_RELAYER_2 =
  "0x4E19938Cc3a6cF0d4F0f1394813bb4a9aBa4b912";
const MAINNET_DEPLOYER = "0x45a0744065e5455CaAC18aACB99bBB64154F8cfb";

/**
 * @notice Configuration for mainnet deployment - Gasless Marketplace Setup
 * @dev Configured for gasless operations with OpenZeppelin relayers
 */
export const MAINNET_ROLES_CONFIG: RoleConfig = {
  // Multisig (Company Leaders) - Critical administrative functions
  owner: MAINNET_MULTISIG, // Fee management, treasury updates, role updates
  pauser: MAINNET_MULTISIG, // Emergency pause functionality
  upgrader: MAINNET_MULTISIG, // Contract upgrade authorization
  treasury: MAINNET_MULTISIG, // Receives platform fees
  brandOwner: MAINNET_MULTISIG, // Multisig owns the brand

  // Server Signing Key (Unfunded) - Signs gasless transactions
  operational1: MAINNET_SERVER_SIGNING_KEY,

  // OpenZeppelin Relayers (Funded with AVAX) - Submit transactions
  operational2: MAINNET_OPENZEPPELIN_RELAYER_1,
  operational3: MAINNET_OPENZEPPELIN_RELAYER_2,
  operational4: MAINNET_DEPLOYER,

  // FIAT role for off-chain payment settlements
  fiat: MAINNET_OPENZEPPELIN_RELAYER_1,
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
    "brandOwner", // Added brandOwner to required roles
  ];

  // Optional roles (check if present)
  const optionalRoles = ["operational3"];

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

  // Validate optional roles if present
  for (const role of optionalRoles) {
    const address = config[role as keyof RoleConfig] as string;
    if (address && !isValidAddress(address)) {
      console.error(`❌ Invalid ${role} address: ${address}`);
      return false;
    }
  }

  // Check for duplicate addresses (security risk)
  const addresses = new Set<string>();
  const allRoles = [...requiredRoles, ...optionalRoles];
  for (const role of allRoles) {
    const address = config[role as keyof RoleConfig] as string;
    if (address && address !== "0x0000000000000000000000000000000000000000") {
      if (addresses.has(address.toLowerCase())) {
        console.warn(`⚠️  Duplicate address found for role: ${role}`);
      }
      addresses.add(address.toLowerCase());
    }
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
  console.log(`  Operational 1 (Server Signing): ${config.operational1}`);
  console.log(`  Operational 2 (OZ Relayer 1): ${config.operational2}`);
  if (config.operational3) {
    console.log(`  Operational 3 (OZ Relayer 2): ${config.operational3}`);
  }
  if (config.operational4) {
    console.log(`  Operational 4 (Deployer): ${config.operational4}`);
  }
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

  // Brand ownership
  console.log("🏷️  Brand Ownership:");
  console.log(`  Brand Owner: ${config.brandOwner}`);
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
    ...(config.operational3 && { OPERATIONAL_3: config.operational3 }),
    ...(config.operational4 && { OPERATIONAL_4: config.operational4 }),
    TREASURY: config.treasury,
    FIAT: config.fiat,
    PAUSER: config.pauser,
    UPGRADER: config.upgrader,
    BRAND_OWNER: config.brandOwner,
    ...(config.emergencyAdmin && { EMERGENCY_ADMIN: config.emergencyAdmin }),
    ...(config.governance && { GOVERNANCE: config.governance }),
    ...(config.partner1 && { PARTNER_1: config.partner1 }),
    ...(config.partner2 && { PARTNER_2: config.partner2 }),
    // Additional relayer addresses for gasless marketplace
    ...(config.lister && { LISTER: config.lister }),
    ...(config.buyer && { BUYER: config.buyer }),
    ...(config.renewer && { RENEWER: config.renewer }),
    ...(config.withdrawer && { WITHDRAWER: config.withdrawer }),
  };
}
