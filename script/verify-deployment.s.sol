// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '../src/Roles.sol';
import '../src/Brands.sol';
import '../src/Wrappers.sol';
import '../src/Whitelist.sol';
import '../src/Payments.sol';
import '../src/Sales.sol';
import '../src/Memberships.sol';
import '../src/interfaces/IRoles.sol';
import '../src/interfaces/IBrands.sol';
import '../src/interfaces/IWrappers.sol';
import '../src/interfaces/IWhitelist.sol';
import '../src/interfaces/IPayments.sol';
import '../src/interfaces/ISales.sol';
import '../src/interfaces/IMemberships.sol';

/**
 * @title DeploymentVerifier
 * @notice Comprehensive verification script for Crutrade ecosystem deployment
 * @dev Verifies all contracts are properly deployed and configured
 * @author Crutrade Team
 */
contract DeploymentVerifier is Script {
  /* CONSTANTS */

  /// @notice Expected role hashes (matching RolesBase.sol)
  bytes32 private constant PAUSER_ROLE = keccak256('PAUSER');
  bytes32 private constant UPGRADER_ROLE = keccak256('UPGRADER');
  bytes32 private constant FIAT_ROLE = keccak256('FIAT');
  bytes32 private constant OPERATIONAL_ROLE = keccak256('OPERATIONAL');
  bytes32 private constant OWNER_ROLE = keccak256('OWNER');
  bytes32 private constant TREASURY_ROLE = keccak256('TREASURY');
  bytes32 private constant BRANDS_ROLE = keccak256('BRANDS');
  bytes32 private constant WRAPPERS_ROLE = keccak256('WRAPPERS');
  bytes32 private constant WHITELIST_ROLE = keccak256('WHITELIST');
  bytes32 private constant PAYMENTS_ROLE = keccak256('PAYMENTS');
  bytes32 private constant SALES_ROLE = keccak256('SALES');
  bytes32 private constant MEMBERSHIPS_ROLE = keccak256('MEMBERSHIPS');

  /// @notice Expected USDC addresses by network
  address private constant FUJI_USDC = 0x5425890298aed601595a70AB815c96711a31Bc65;
  address private constant MAINNET_USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

  /* STATE VARIABLES */

  /// @notice Contract addresses to verify
  address public rolesAddress;
  address public brandsAddress;
  address public wrappersAddress;
  address public whitelistAddress;
  address public paymentsAddress;
  address public salesAddress;
  address public membershipsAddress;

  /// @notice Contract instances
  IRoles public roles;
  IBrands public brands;
  IWrappers public wrappers;
  IWhitelist public whitelist;
  IPayments public payments;
  ISales public sales;
  IMemberships public memberships;

  /// @notice Verification results
  bool public allChecksPassed = true;
  string[] public errors;
  string[] public warnings;

  /* MAIN VERIFICATION FUNCTION */

  /**
   * @notice Main verification function
   * @dev Executes all verification checks
   */
  function run() external {
    string memory network = vm.envOr("NETWORK", string("local"));

    console.log("=== Crutrade Deployment Verification ===");
    console.log("Network:", network);
    console.log("");

    // Load contract addresses from environment or broadcast files
    _loadContractAddresses();

    // Initialize contract instances
    _initializeContracts();

    // Run all verification checks
    _verifyContractDeployments();
    _verifyRolesConfiguration();
    _verifyBrandsSetup();
    _verifyContractRelationships();
    _verifyPaymentConfiguration();
    _verifyContractPermissions();
    _verifyNetworkSpecificChecks(network);

    // Print results
    _printResults();
  }

  /* CONTRACT ADDRESS LOADING */

  /**
   * @notice Loads contract addresses from environment variables or broadcast files
   */
  function _loadContractAddresses() private {
    // Try to load from environment variables first
    try vm.envAddress("ROLES_ADDRESS") returns (address addr) {
      rolesAddress = addr;
    } catch {
      _addError("Could not load ROLES_ADDRESS from environment. Please set it or ensure broadcast file exists.");
      return;
    }

    // Load other addresses from environment
    brandsAddress = vm.envOr("BRANDS_ADDRESS", address(0));
    wrappersAddress = vm.envOr("WRAPPERS_ADDRESS", address(0));
    whitelistAddress = vm.envOr("WHITELIST_ADDRESS", address(0));
    paymentsAddress = vm.envOr("PAYMENTS_ADDRESS", address(0));
    salesAddress = vm.envOr("SALES_ADDRESS", address(0));
    membershipsAddress = vm.envOr("MEMBERSHIPS_ADDRESS", address(0));

    // If any address is missing, try to load from broadcast file
    if (brandsAddress == address(0) || wrappersAddress == address(0) ||
        whitelistAddress == address(0) || paymentsAddress == address(0) ||
        salesAddress == address(0) || membershipsAddress == address(0)) {
      _loadAddressesFromBroadcast();
    }

    console.log("Contract Addresses:");
    console.log("  Roles:", rolesAddress);
    console.log("  Brands:", brandsAddress);
    console.log("  Wrappers:", wrappersAddress);
    console.log("  Whitelist:", whitelistAddress);
    console.log("  Payments:", paymentsAddress);
    console.log("  Sales:", salesAddress);
    console.log("  Memberships:", membershipsAddress);
    console.log("");
  }

  /**
   * @notice Loads contract addresses from Foundry broadcast files
   */
  function _loadAddressesFromBroadcast() private {
    string memory networkId = vm.envOr("NETWORK_ID", string("31337"));
    string memory broadcastPath = string.concat("./broadcast/deploy.s.sol/", networkId, "/run-latest.json");

    try vm.readFile(broadcastPath) returns (string memory jsonData) {
      // Parse the broadcast file to extract addresses
      // This is a simplified approach - in production you might want a more robust JSON parser
      console.log("  Loading addresses from broadcast file:", broadcastPath);

      // For now, we'll rely on environment variables being set by the TypeScript wrapper
      // The actual JSON parsing would be complex in Solidity
    } catch {
      _addWarning("Could not read broadcast file. Please ensure addresses are set in environment variables.");
    }
  }

  /**
   * @notice Initializes contract instances for verification
   */
  function _initializeContracts() private {
    roles = IRoles(rolesAddress);
    brands = IBrands(brandsAddress);
    wrappers = IWrappers(wrappersAddress);
    whitelist = IWhitelist(whitelistAddress);
    payments = IPayments(paymentsAddress);
    sales = ISales(salesAddress);
    memberships = IMemberships(membershipsAddress);
  }

  /* VERIFICATION CHECKS */

  /**
   * @notice Verifies that all contracts are deployed and accessible
   */
  function _verifyContractDeployments() private {
    console.log("1. Verifying Contract Deployments...");

    // Check if contracts exist and are accessible
    _checkContractExists("Roles", rolesAddress);
    _checkContractExists("Brands", brandsAddress);
    _checkContractExists("Wrappers", wrappersAddress);
    _checkContractExists("Whitelist", whitelistAddress);
    _checkContractExists("Payments", paymentsAddress);
    _checkContractExists("Sales", salesAddress);
    _checkContractExists("Memberships", membershipsAddress);

    console.log("");
  }

  /**
   * @notice Verifies roles configuration and assignments
   */
  function _verifyRolesConfiguration() private {
    console.log("2. Verifying Roles Configuration...");

    // Get expected admin address from environment
    address expectedAdmin = vm.envAddress("OWNER");

    // Check admin roles (these should all be assigned to the owner)
    _checkRoleAssignment("OWNER", expectedAdmin, OWNER_ROLE);
    _checkRoleAssignment("FIAT", expectedAdmin, FIAT_ROLE);
    _checkRoleAssignment("PAUSER", expectedAdmin, PAUSER_ROLE);
    _checkRoleAssignment("UPGRADER", expectedAdmin, UPGRADER_ROLE);
    _checkRoleAssignment("TREASURY", expectedAdmin, TREASURY_ROLE);

    // Check operational roles
    address operational1 = vm.envAddress("OPERATIONAL_1");
    address operational2 = vm.envAddress("OPERATIONAL_2");
    address operational3 = vm.envOr("OPERATIONAL_3", operational1);

    _checkRoleAssignment("OPERATIONAL_1", operational1, OPERATIONAL_ROLE);
    _checkRoleAssignment("OPERATIONAL_2", operational2, OPERATIONAL_ROLE);
    _checkRoleAssignment("OPERATIONAL_3", operational3, OPERATIONAL_ROLE);

    // Check contract roles
    _checkRoleAssignment("BRANDS", brandsAddress, BRANDS_ROLE);
    _checkRoleAssignment("WRAPPERS", wrappersAddress, WRAPPERS_ROLE);
    _checkRoleAssignment("WHITELIST", whitelistAddress, WHITELIST_ROLE);
    _checkRoleAssignment("PAYMENTS", paymentsAddress, PAYMENTS_ROLE);
    _checkRoleAssignment("SALES", salesAddress, SALES_ROLE);
    _checkRoleAssignment("MEMBERSHIPS", membershipsAddress, MEMBERSHIPS_ROLE);

    // Check delegate roles (these contracts should have delegate roles)
    _checkDelegateRole("Wrappers", wrappersAddress);
    _checkDelegateRole("Payments", paymentsAddress);
    _checkDelegateRole("Sales", salesAddress);

    console.log("");
  }

  /**
   * @notice Verifies brands setup and first brand creation
   */
  function _verifyBrandsSetup() private {
    console.log("3. Verifying Brands Setup...");

    // Check if first brand exists (should be brand ID 0)
    bool firstBrandValid = brands.isValidBrand(0);
    if (firstBrandValid) {
      address firstBrandOwner = brands.getBrandOwner(0);
      console.log("  + First brand (ID 0) exists and is valid");
      console.log("    Owner:", firstBrandOwner);

      // Check if owner matches expected admin
      address expectedAdmin = vm.envAddress("OWNER");
      if (firstBrandOwner == expectedAdmin) {
        console.log("    + Owner matches expected admin address");
      } else {
        _addWarning("First brand owner does not match expected admin address");
      }
    } else {
      _addError("First brand (ID 0) does not exist or is invalid");
    }

    console.log("");
  }

  /**
   * @notice Verifies contract relationships and cross-references
   */
  function _verifyContractRelationships() private {
    console.log("4. Verifying Contract Relationships...");

    // Check if all contracts reference the correct roles contract
    // This would require additional view functions in contracts to expose their roles address
    // For now, we'll verify that contracts can call roles functions successfully

    try roles.hasRole(OWNER_ROLE, vm.envAddress("OWNER")) returns (bool hasRole) {
      if (hasRole) {
        console.log("  + Roles contract is accessible and functional");
      } else {
        _addError("Roles contract is not accessible or not properly configured");
      }
    } catch {
      _addError("Roles contract is not accessible or not properly configured");
    }

    console.log("");
  }

  /**
   * @notice Verifies payment configuration
   */
  function _verifyPaymentConfiguration() private {
    console.log("5. Verifying Payment Configuration...");

    // Check default fiat payment token
    address defaultFiat = roles.getDefaultFiatPayment();
    console.log("  Default fiat payment token:", defaultFiat);

    // Check if it matches expected USDC address for current network
    uint256 chainId = block.chainid;
    address expectedUSDC;

    if (chainId == 43113) { // Fuji testnet
      expectedUSDC = FUJI_USDC;
    } else if (chainId == 43114) { // Avalanche mainnet
      expectedUSDC = MAINNET_USDC;
    } else {
      expectedUSDC = address(0); // Local network
    }

    if (expectedUSDC != address(0) && defaultFiat == expectedUSDC) {
      console.log("  + Default fiat token matches expected USDC for network");
    } else if (expectedUSDC == address(0)) {
      console.log("  + Local network - USDC address verification skipped");
    } else {
      _addWarning("Default fiat token does not match expected USDC for network");
    }

    // Check if payments contract has payment role
    bool hasPaymentRole = roles.hasPaymentRole(paymentsAddress);
    if (hasPaymentRole) {
      console.log("  + Payments contract has payment role");
    } else {
      _addError("Payments contract does not have payment role");
    }

    console.log("");
  }

  /**
   * @notice Verifies contract permissions and access control
   */
  function _verifyContractPermissions() private {
    console.log("6. Verifying Contract Permissions...");

    // Check if admin has DEFAULT_ADMIN_ROLE on roles contract
    address expectedAdmin = vm.envAddress("OWNER");
    bool hasDefaultAdmin = roles.hasRole(0x00, expectedAdmin);
    if (hasDefaultAdmin) {
      console.log("  + Admin has DEFAULT_ADMIN_ROLE on roles contract");
    } else {
      _addError("Admin does not have DEFAULT_ADMIN_ROLE on roles contract");
    }

    // Check if contracts are not paused (if they have pause functionality)
    // Note: This would require additional view functions in contracts
    console.log("  + Contract pause status verification requires additional view functions");

    console.log("");
  }

  /**
   * @notice Verifies network-specific configurations
   * @param network Network name
   */
  function _verifyNetworkSpecificChecks(string memory network) private {
    console.log("7. Verifying Network-Specific Configuration...");

    uint256 chainId = block.chainid;
    console.log("  Chain ID:", chainId);

    if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
      if (chainId == 43114) {
        console.log("  + Chain ID matches Avalanche mainnet");
      } else {
        _addError("Chain ID does not match Avalanche mainnet (expected 43114)");
      }
    } else if (keccak256(bytes(network)) == keccak256(bytes("fuji"))) {
      if (chainId == 43113) {
        console.log("  + Chain ID matches Avalanche Fuji testnet");
      } else {
        _addError("Chain ID does not match Avalanche Fuji testnet (expected 43113)");
      }
    } else {
      console.log("  + Local network verification completed");
    }

    console.log("");
  }

  /* HELPER FUNCTIONS */

  /**
   * @notice Checks if a contract exists and is accessible
   * @param name Contract name for logging
   * @param addr Contract address to check
   */
  function _checkContractExists(string memory name, address addr) private {
    if (addr == address(0)) {
      _addError(string.concat(name, " address is zero"));
      return;
    }

    uint256 codeSize;
    assembly {
      codeSize := extcodesize(addr)
    }

    if (codeSize > 0) {
      console.log("  +", name, "contract deployed at:", addr);
    } else {
      _addError(string.concat(name, " contract has no code at address: ", vm.toString(addr)));
    }
  }

  /**
   * @notice Checks if an address has a specific role
   * @param name Role name for logging
   * @param addr Address to check
   * @param role Role hash to check
   */
  function _checkRoleAssignment(string memory name, address addr, bytes32 role) private {
    if (addr == address(0)) {
      _addError(string.concat(name, " address is zero"));
      return;
    }

    bool hasRole = roles.hasRole(role, addr);
    if (hasRole) {
      console.log("  +", name, "role assigned to:", addr);
    } else {
      _addError(string.concat(name, " role not assigned to: ", vm.toString(addr)));
    }
  }

  /**
   * @notice Checks if a contract has delegate role
   * @param name Contract name for logging
   * @param addr Contract address to check
   */
  function _checkDelegateRole(string memory name, address addr) private {
    if (addr == address(0)) {
      _addError(string.concat(name, " address is zero"));
      return;
    }

    bool hasDelegate = roles.hasDelegateRole(addr);
    if (hasDelegate) {
      console.log("  +", name, "has delegate role");
    } else {
      _addError(string.concat(name, " does not have delegate role"));
    }
  }

  /**
   * @notice Adds an error message
   * @param message Error message
   */
  function _addError(string memory message) private {
    errors.push(message);
    allChecksPassed = false;
    console.log("  [ERROR]", message);
  }

  /**
   * @notice Adds a warning message
   * @param message Warning message
   */
  function _addWarning(string memory message) private {
    warnings.push(message);
    console.log("  [WARNING]", message);
  }

  /**
   * @notice Prints final verification results
   */
  function _printResults() private {
    console.log("=== Verification Results ===");

    if (allChecksPassed) {
      console.log("[SUCCESS] All verification checks passed!");
    } else {
      console.log("[FAILED] Some verification checks failed!");
    }

    if (errors.length > 0) {
      console.log("");
      console.log("Errors:");
      for (uint256 i = 0; i < errors.length; i++) {
        console.log("  ", i + 1, ".", errors[i]);
      }
    }

    if (warnings.length > 0) {
      console.log("");
      console.log("Warnings:");
      for (uint256 i = 0; i < warnings.length; i++) {
        console.log("  ", i + 1, ".", warnings[i]);
      }
    }

    console.log("");
    console.log("Summary:");
    console.log("  Total Errors:", errors.length);
    console.log("  Total Warnings:", warnings.length);
    console.log("  Overall Status:", allChecksPassed ? "PASSED" : "FAILED");
  }
}