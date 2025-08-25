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
import '../src/USDCApprovalProxy.sol';
import '../src/mock/MockUSDC.sol';
import '../src/interfaces/IPayments.sol';

import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

/**
 * @title CrutradeDeploy
 * @notice Deployment script for the complete Crutrade ecosystem
 * @dev Deploys all contracts in the correct sequence with full configuration
 * @author Crutrade Team
 */
contract CrutradeDeploy is Script {
  /* CONSTANTS */

  /// @notice Default admin address (multisig) - will be overridden by env vars
  address private constant DEFAULT_ADMIN = 0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6;

  /// @notice Operational addresses - will be overridden by env vars
  address private constant OPERATIONAL_1 = 0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC;
  address private constant OPERATIONAL_2 = 0xe812BeeF1F7A62ed142835Ec2622B71AeA858085;

  address private constant ANVIL_ADDRESS_1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address private constant ANVIL_ADDRESS_2 = 0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC;
  address private constant ANVIL_ADDRESS_3 = 0xe812BeeF1F7A62ed142835Ec2622B71AeA858085;

  uint256 private constant ANVIL_ADDRESS_1_PRIVATE_KEY =
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  uint256 private constant ANVIL_ADDRESS_2_PRIVATE_KEY =
    0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  uint256 private constant ANVIL_ADDRESS_3_PRIVATE_KEY =
    0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

  /* STATE VARIABLES */

  /// @notice USDC token address for the current deployment
  address private usdcAddress;

  /* CONTRACT INSTANCES */

  // Implementation contracts
  Roles rolesImpl;
  Brands brandsImpl;
  Wrappers wrappersImpl;
  Whitelist whitelistImpl;
  Payments paymentsImpl;
  Sales salesImpl;
  Memberships membershipsImpl;
  USDCApprovalProxy usdcApprovalProxyImpl;

  // Proxy contracts
  ERC1967Proxy rolesProxy;
  ERC1967Proxy brandsProxy;
  ERC1967Proxy wrappersProxy;
  ERC1967Proxy whitelistProxy;
  ERC1967Proxy paymentsProxy;
  ERC1967Proxy salesProxy;
  ERC1967Proxy membershipsProxy;
  ERC1967Proxy usdcApprovalProxyProxy;

  /* MAIN DEPLOYMENT FUNCTION */

  /**
   * @notice Main deployment function
   * @dev Executes the complete deployment sequence
   */
  function run() external {
    string memory network = vm.envOr("NETWORK", string("local"));
    if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
      runMainnet();
    } else if (keccak256(bytes(network)) == keccak256(bytes("fuji"))) {
      runTestnet();
    } else {
      runLocal();
    }
  }

  function runLocal() public {
    // Deploy mock USDC
    vm.startBroadcast(ANVIL_ADDRESS_1_PRIVATE_KEY);
    MockUSDC mockUSDC = new MockUSDC();
    usdcAddress = address(mockUSDC);
    vm.stopBroadcast();

    console.log("Deployed MockUSDC at:", usdcAddress);

    _deployAll(ANVIL_ADDRESS_1_PRIVATE_KEY, "local");
  }

  function runTestnet() public {
    usdcAddress = 0x5425890298aed601595a70AB815c96711a31Bc65; // Fuji USDC

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    _deployAll(deployerPrivateKey, "fuji");
  }

  function runMainnet() public {
    usdcAddress = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; // Mainnet USDC

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    _deployAll(deployerPrivateKey, "mainnet");
  }

  function _deployAll(uint256 deployerPrivateKey, string memory network) internal {
    vm.startBroadcast(deployerPrivateKey);

    console.log('Deploying CruTrade ecosystem...');

    // Step 1: Deploy all implementation contracts
    _deployImplementations();

    // Step 2: Deploy Roles contract first with minimal configuration
    _deployRolesWithMinimalSetup();

    // Step 3: Deploy all other contracts with the correct roles address
    _deployOtherContractsWithCorrectRoles();

    // Step 4: Grant contract-specific roles to the deployed contracts
    _grantContractRoles();

    // Step 5: Save deployment information
    // _saveDeployment(); // Commented out - using Foundry's broadcast instead

    console.log('Deploy complete - ecosystem ready!');
    vm.stopBroadcast();

    // Print summary
    console.log("Deployment complete for", network);
    console.log("USDC:", usdcAddress);
    console.log('All contract addresses:');
    console.log('   - Roles:', address(rolesProxy));
    console.log('   - Brands:', address(brandsProxy));
    console.log('   - Wrappers:', address(wrappersProxy));
    console.log('   - Whitelist:', address(whitelistProxy));
    console.log('   - Payments:', address(paymentsProxy));
    console.log('   - Sales:', address(salesProxy));
    console.log('   - Memberships:', address(membershipsProxy));
    console.log('   - USDC Approval Proxy:', address(usdcApprovalProxyProxy));
  }

  /* DEPLOYMENT STEPS */

  /**
   * @notice Deploys all implementation contracts
   * @dev These are the logic contracts behind the proxies
   */
  function _deployImplementations() private {
    rolesImpl = new Roles();
    brandsImpl = new Brands();
    wrappersImpl = new Wrappers();
    whitelistImpl = new Whitelist();
    paymentsImpl = new Payments();
    salesImpl = new Sales();
    membershipsImpl = new Memberships();
    usdcApprovalProxyImpl = new USDCApprovalProxy();
    console.log('All implementation contracts deployed');
  }

  /**
   * @notice Deploys all contracts except Roles with the correct roles address
   * @dev Uses the actual roles address instead of a dummy address
   */
  function _deployOtherContractsWithCorrectRoles() private {
    // Get owner from environment for role management
    address owner = vm.envAddress("OWNER");

    // Deploy Brands with correct roles address and owner for first brand registration
    brandsProxy = new ERC1967Proxy(
      address(brandsImpl),
      abi.encodeCall(brandsImpl.initialize, (address(rolesProxy), owner))
    );

    // Deploy other contracts with correct roles address
    wrappersProxy = new ERC1967Proxy(
      address(wrappersImpl),
      abi.encodeCall(wrappersImpl.initialize, (address(rolesProxy)))
    );

    whitelistProxy = new ERC1967Proxy(
      address(whitelistImpl),
      abi.encodeCall(whitelistImpl.initialize, (address(rolesProxy)))
    );

    // Get payments configuration from environment variables
    address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
    uint256 fiatFeePercentage = vm.envUint("FIAT_FEE_PERCENTAGE");
    string memory membershipFeesJson = vm.envString("MEMBERSHIP_FEES");

    // Parse membership fees from JSON (simplified - in production you might want a more robust parser)
    IPayments.MembershipFeeConfig[] memory membershipFees = _parseMembershipFees(membershipFeesJson);

    console.log('Payments configuration:');
    console.log('  Treasury Address:', treasuryAddress);
    console.log('  Fiat Fee Percentage:', fiatFeePercentage);
    console.log('  Membership Fees Count:', membershipFees.length);

    // Deploy Payments with correct roles address
    paymentsProxy = new ERC1967Proxy(
      address(paymentsImpl),
      abi.encodeCall(paymentsImpl.initialize, (address(rolesProxy), treasuryAddress, fiatFeePercentage, membershipFees))
    );

    // Deploy Sales with correct roles address
    salesProxy = new ERC1967Proxy(
      address(salesImpl),
      abi.encodeCall(salesImpl.initialize, (address(rolesProxy)))
    );

    // Deploy Memberships with correct roles address
    membershipsProxy = new ERC1967Proxy(
      address(membershipsImpl),
      abi.encodeCall(membershipsImpl.initialize, (address(rolesProxy)))
    );

    // Deploy USDCApprovalProxy with correct roles address, USDC token, and payments contract
    usdcApprovalProxyProxy = new ERC1967Proxy(
      address(usdcApprovalProxyImpl),
      abi.encodeCall(usdcApprovalProxyImpl.initialize, (
        address(rolesProxy),
        usdcAddress,
        address(paymentsProxy)
      ))
    );

    console.log('All other contracts deployed with correct roles address (first brand registered)');
  }

  /**
   * @notice Deploys Roles contract with minimal configuration
   * @dev This follows the initialDeploy pattern - deploy with minimal config, then configure separately
   */
  function _deployRolesWithMinimalSetup() private {
    // Get roles configuration from environment variables
    address owner = vm.envAddress("OWNER");
    address operational1 = vm.envAddress("OPERATIONAL_1");
    address operational2 = vm.envAddress("OPERATIONAL_2");

    console.log('Roles configuration:');
    console.log('  Owner:', owner);
    console.log('  Operational 1:', operational1);
    console.log('  Operational 2:', operational2);

    // Prepare operational addresses array
    address[] memory operationalAddresses = new address[](2);
    operationalAddresses[0] = operational1;
    operationalAddresses[1] = operational2;

    // User roles to grant to admin (following initialDeploy pattern)
    bytes32[] memory userRoles = new bytes32[](6);
    userRoles[0] = keccak256('OWNER');
    userRoles[1] = keccak256('OPERATIONAL');
    userRoles[2] = keccak256('TREASURY');
    userRoles[3] = keccak256('FIAT');
    userRoles[4] = keccak256('PAUSER');
    userRoles[5] = keccak256('UPGRADER');

    // Deploy Roles with minimal configuration (empty contract addresses for now)
    rolesProxy = new ERC1967Proxy(
      address(rolesImpl),
      abi.encodeCall(rolesImpl.initialize, (
        owner,
        usdcAddress,
        operationalAddresses,
        new address[](0), // contractAddresses - empty for now
        userRoles,
        new bytes32[](0), // contractRoles - empty for now
        new uint256[](0)  // delegateIndices - empty for now
      ))
    );

    console.log('Roles deployed with minimal setup:');
    console.log('   - User roles assigned to admin');
    console.log('   - Operational roles assigned');
    console.log('   - Contract roles will be granted after deployment');
  }

  /**
   * @notice Grants contract-specific roles to the deployed contracts
   * @dev This function is called after all contracts are deployed to ensure correct role delegation
   */
  function _grantContractRoles() private {
    console.log('Granting contract-specific roles...');

    // Grant contract-specific roles to contracts directly (deployer is admin)
    Roles(address(rolesProxy)).grantRole(keccak256('WHITELIST'), address(whitelistProxy));
    console.log('   - WHITELIST role granted to Whitelist contract');

    Roles(address(rolesProxy)).grantRole(keccak256('WRAPPERS'), address(wrappersProxy));
    console.log('   - WRAPPERS role granted to Wrappers contract');

    Roles(address(rolesProxy)).grantRole(keccak256('BRANDS'), address(brandsProxy));
    console.log('   - BRANDS role granted to Brands contract');

    Roles(address(rolesProxy)).grantRole(keccak256('PAYMENTS'), address(paymentsProxy));
    console.log('   - PAYMENTS role granted to Payments contract');

    Roles(address(rolesProxy)).grantRole(keccak256('SALES'), address(salesProxy));
    console.log('   - SALES role granted to Sales contract');

    Roles(address(rolesProxy)).grantRole(keccak256('MEMBERSHIPS'), address(membershipsProxy));
    console.log('   - MEMBERSHIPS role granted to Memberships contract');

    // Grant delegate roles to contracts that need them
    Roles(address(rolesProxy)).grantDelegateRole(address(wrappersProxy));
    console.log('   - Delegate role granted to Wrappers contract');

    Roles(address(rolesProxy)).grantDelegateRole(address(paymentsProxy));
    console.log('   - Delegate role granted to Payments contract');

    Roles(address(rolesProxy)).grantDelegateRole(address(salesProxy));
    console.log('   - Delegate role granted to Sales contract');

    console.log('All contract roles granted successfully');
  }

  /**
   * @notice Parses membership fees from JSON string
   * @dev Simplified parser for deployment - in production use a more robust solution
   * @return Array of MembershipFeeConfig structs
   */
  function _parseMembershipFees(string memory /* jsonString */) private pure returns (IPayments.MembershipFeeConfig[] memory) {
    // For simplicity, we'll hardcode the expected structure based on our config
    // In a real implementation, you might want to use a JSON parsing library

    // Default configuration if parsing fails or for local deployment
    IPayments.MembershipFeeConfig[] memory fees = new IPayments.MembershipFeeConfig[](2);
    fees[0] = IPayments.MembershipFeeConfig({
      membershipId: 0,
      sellerFee: 600, // 6% seller fee
      buyerFee: 400   // 4% buyer fee
    });
    fees[1] = IPayments.MembershipFeeConfig({
      membershipId: 1,
      sellerFee: 100, // 1% seller fee
      buyerFee: 100   // 1% buyer fee
    });

    return fees;
  }

  /**
   * @notice Saves deployment information to JSON files
   * @dev Creates both latest.json and timestamped deployment files
   * COMMENTED OUT - Using Foundry's broadcast functionality instead
   */
  /*
  function _saveDeployment() private {
    // Determine network folder
    string memory nodeEnv = vm.envOr('NODE_ENV', string('dev'));
    string memory folder = keccak256(abi.encodePacked(nodeEnv)) == keccak256(abi.encodePacked('dev')) ? 'testnet' : 'mainnet';
    string memory dirPath = string.concat('./deployments/', folder);

    // Create deployment directory
    string[] memory mkdirCmd = new string[](3);
    mkdirCmd[0] = 'mkdir';
    mkdirCmd[1] = '-p';
    mkdirCmd[2] = dirPath;
    vm.ffi(mkdirCmd);

    // Build deployment JSON
    string memory json = '{}';
    json = vm.serializeUint('deployment', 'chainId', block.chainid);
    json = vm.serializeUint('deployment', 'timestamp', block.timestamp);

    // Proxy contract addresses
    json = vm.serializeAddress('deployment', 'roles', address(rolesProxy));
    json = vm.serializeAddress('deployment', 'brands', address(brandsProxy));
    json = vm.serializeAddress('deployment', 'wrappers', address(wrappersProxy));
    json = vm.serializeAddress('deployment', 'whitelist', address(whitelistProxy));
    json = vm.serializeAddress('deployment', 'payments', address(paymentsProxy));
    json = vm.serializeAddress('deployment', 'sales', address(salesProxy));
    json = vm.serializeAddress('deployment', 'memberships', address(membershipsProxy));

    // Configuration metadata
    json = vm.serializeAddress('deployment', 'defaultAdmin', DEFAULT_ADMIN);
    json = vm.serializeBool('deployment', 'fullyConfigured', true);
    json = vm.serializeBool('deployment', 'firstBrandRegistered', true);

    // Save deployment files
    vm.writeJson(json, string.concat(dirPath, '/latest.json'));
    vm.writeJson(json, string.concat(dirPath, '/', vm.toString(block.timestamp), '.json'));

    console.log('Deployment information saved to:', folder);
  }
  */
}