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
 * @title TestVerification
 * @notice Simple test script to verify basic contract functionality
 * @dev Tests basic contract calls to ensure deployment is working
 * @author Crutrade Team
 */
contract TestVerification is Script {
  /* STATE VARIABLES */

  /// @notice Contract addresses
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

  /* MAIN TEST FUNCTION */

  /**
   * @notice Main test function
   * @dev Runs basic functionality tests
   */
  function run() external {
    console.log("=== Crutrade Basic Functionality Test ===");
    console.log("");

    // Load contract addresses
    _loadAddresses();

    // Initialize contract instances
    _initializeContracts();

    // Run basic tests
    _testRolesContract();
    _testBrandsContract();
    _testContractAccessibility();

    console.log("=== All Basic Tests Completed ===");
  }

  /* HELPER FUNCTIONS */

  /**
   * @notice Loads contract addresses from environment
   */
  function _loadAddresses() private {
    rolesAddress = vm.envAddress("ROLES_ADDRESS");
    brandsAddress = vm.envAddress("BRANDS_ADDRESS");
    wrappersAddress = vm.envAddress("WRAPPERS_ADDRESS");
    whitelistAddress = vm.envAddress("WHITELIST_ADDRESS");
    paymentsAddress = vm.envAddress("PAYMENTS_ADDRESS");
    salesAddress = vm.envAddress("SALES_ADDRESS");
    membershipsAddress = vm.envAddress("MEMBERSHIPS_ADDRESS");

    console.log("Testing contracts at addresses:");
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
   * @notice Initializes contract instances
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

  /**
   * @notice Tests basic Roles contract functionality
   */
  function _testRolesContract() private {
    console.log("Testing Roles Contract...");

    // Test basic role checks
    address owner = vm.envAddress("OWNER");

    try roles.hasRole(keccak256('OWNER'), owner) returns (bool hasRole) {
      if (hasRole) {
        console.log("  + Owner role check passed");
      } else {
        console.log("  [WARNING] Owner role not found");
      }
    } catch {
      console.log("  [ERROR] Could not check owner role");
    }

    // Test default fiat payment
    try roles.getDefaultFiatPayment() returns (address fiatToken) {
      console.log("  + Default fiat payment:", fiatToken);
    } catch {
      console.log("  [ERROR] Could not get default fiat payment");
    }

    // Test delegate role checks
    try roles.hasDelegateRole(wrappersAddress) returns (bool hasDelegate) {
      if (hasDelegate) {
        console.log("  + Wrappers has delegate role");
      } else {
        console.log("  [WARNING] Wrappers does not have delegate role");
      }
    } catch {
      console.log("  [ERROR] Could not check Wrappers delegate role");
    }

    try roles.hasDelegateRole(paymentsAddress) returns (bool hasDelegate) {
      if (hasDelegate) {
        console.log("  + Payments has delegate role");
      } else {
        console.log("  [WARNING] Payments does not have delegate role");
      }
    } catch {
      console.log("  [ERROR] Could not check Payments delegate role");
    }

    try roles.hasDelegateRole(salesAddress) returns (bool hasDelegate) {
      if (hasDelegate) {
        console.log("  + Sales has delegate role");
      } else {
        console.log("  [WARNING] Sales does not have delegate role");
      }
    } catch {
      console.log("  [ERROR] Could not check Sales delegate role");
    }

    console.log("");
  }

  /**
   * @notice Tests basic Brands contract functionality
   */
  function _testBrandsContract() private {
    console.log("Testing Brands Contract...");

    // Test first brand existence
    try brands.isValidBrand(1) returns (bool isValid) {
      if (isValid) {
        console.log("  + First brand (ID 1) exists");

        // Test brand owner
        try brands.getBrandOwner(1) returns (address owner) {
          console.log("  + First brand owner:", owner);

          // Check if brand owner matches expected BRAND_OWNER
          address expectedBrandOwner = vm.envAddress("BRAND_OWNER");
          if (owner == expectedBrandOwner) {
            console.log("  + Brand owner matches expected BRAND_OWNER");
          } else {
            console.log("  [WARNING] Brand owner does not match expected BRAND_OWNER");
            console.log("    Expected:", expectedBrandOwner);
            console.log("    Actual:", owner);
          }
        } catch {
          console.log("  [ERROR] Could not get first brand owner");
        }
      } else {
        console.log("  [WARNING] First brand (ID 1) does not exist");
      }
    } catch {
      console.log("  [ERROR] Could not check first brand validity");
    }

    console.log("");
  }

  /**
   * @notice Tests basic accessibility of other contracts
   */
  function _testContractAccessibility() private {
    console.log("Testing Contract Accessibility...");

    // Test that contracts can be called (basic accessibility)
    // We'll test with simple operations that should work if contracts are properly deployed

    // Test Wrappers contract - try to check if it's accessible
    try wrappers.isValidCollection(bytes32(0)) returns (bool) {
      console.log("  + Wrappers contract is accessible");
    } catch {
      console.log("  [ERROR] Wrappers contract is not accessible");
    }

    // Test Whitelist contract - try to check if it's accessible
    try whitelist.isWhitelisted(address(0)) returns (bool) {
      console.log("  + Whitelist contract is accessible");
    } catch {
      console.log("  [ERROR] Whitelist contract is not accessible");
    }

    // Test Payments contract - try to check if it's accessible using a view function
    try Payments(paymentsAddress).getFees() returns (IPayments.Fee[] memory) {
      console.log("  + Payments contract is accessible");
    } catch {
      console.log("  [ERROR] Payments contract is not accessible");
    }

    // Test Sales contract - try to check if it's accessible using a view function
    try Sales(salesAddress).getNextScheduleTime() returns (uint256) {
      console.log("  + Sales contract is accessible");
    } catch {
      console.log("  [ERROR] Sales contract is not accessible");
    }

    // Test Memberships contract - try to check if it's accessible
    try memberships.getMembership(address(0)) returns (uint256) {
      console.log("  + Memberships contract is accessible");
    } catch {
      console.log("  [ERROR] Memberships contract is not accessible");
    }

    console.log("");
  }
}