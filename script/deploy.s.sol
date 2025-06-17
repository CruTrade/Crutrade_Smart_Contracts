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

import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

/**
 * @title CrutradeDeploy
 * @notice Deployment script for the complete Crutrade ecosystem
 * @dev Deploys all contracts in the correct sequence with full configuration
 * @author Crutrade Team
 */
contract CrutradeDeploy is Script {
  /* CONSTANTS */
  
  /// @notice Default admin address (multisig)
  address private constant DEFAULT_ADMIN = 0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6;
  
  /// @notice Operational addresses
  address private constant OPERATIONAL_1 = 0x5Ad66a6D9D45a5229240D4d88d225969e10c92eC;
  address private constant OPERATIONAL_2 = 0xe812BeeF1F7A62ed142835Ec2622B71AeA858085;

  /* CONTRACT INSTANCES */
  
  // Implementation contracts
  Roles rolesImpl;
  Brands brandsImpl;
  Wrappers wrappersImpl;
  Whitelist whitelistImpl;
  Payments paymentsImpl;
  Sales salesImpl;
  Memberships membershipsImpl;

  // Proxy contracts
  ERC1967Proxy rolesProxy;
  ERC1967Proxy brandsProxy;
  ERC1967Proxy wrappersProxy;
  ERC1967Proxy whitelistProxy;
  ERC1967Proxy paymentsProxy;
  ERC1967Proxy salesProxy;
  ERC1967Proxy membershipsProxy;

  /* MAIN DEPLOYMENT FUNCTION */

  /**
   * @notice Main deployment function
   * @dev Executes the complete deployment sequence
   */
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    vm.startBroadcast(deployerPrivateKey);

    console.log('Deploying CruTrade ecosystem...');

    // Step 1: Deploy all implementation contracts
    _deployImplementations();
    
    // Step 2: Deploy all other contracts first (brands includes first brand registration)
    _deployOtherContracts();
    
    // Step 3: Deploy Roles last with everything configured
    _deployRolesWithFullSetup();
    
    // Step 4: Save deployment information
    _saveDeployment();

    console.log('Deploy complete - ecosystem ready!');
    vm.stopBroadcast();
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
    console.log('All implementation contracts deployed');
  }

  /**
   * @notice Deploys all contracts except Roles with temporary configuration
   * @dev Uses dummy roles address that will be updated when Roles is deployed
   */
  function _deployOtherContracts() private {
    // Temporary roles address for initialization
    address dummyRoles = address(0x1);

    // Deploy Brands with automatic first brand registration for admin
    brandsProxy = new ERC1967Proxy(
      address(brandsImpl),
      abi.encodeCall(brandsImpl.initialize, (dummyRoles, DEFAULT_ADMIN))
    );

    // Deploy other contracts with dummy roles
    wrappersProxy = new ERC1967Proxy(
      address(wrappersImpl),
      abi.encodeCall(wrappersImpl.initialize, (dummyRoles))
    );

    whitelistProxy = new ERC1967Proxy(
      address(whitelistImpl),
      abi.encodeCall(whitelistImpl.initialize, (dummyRoles))
    );

    paymentsProxy = new ERC1967Proxy(
      address(paymentsImpl),
      abi.encodeCall(paymentsImpl.initialize, (dummyRoles))
    );

    salesProxy = new ERC1967Proxy(
      address(salesImpl),
      abi.encodeCall(salesImpl.initialize, (dummyRoles))
    );

    membershipsProxy = new ERC1967Proxy(
      address(membershipsImpl),
      abi.encodeCall(membershipsImpl.initialize, (dummyRoles))
    );
    
    console.log('All other contracts deployed (first brand registered)');
  }

  /**
   * @notice Deploys Roles contract with complete ecosystem configuration
   * @dev This is the final step that configures all roles, delegates, and payments
   */
  function _deployRolesWithFullSetup() private {
    // Determine USDT address based on chain
    address usdtAddress = block.chainid == 43113 
      ? 0xd495C61A12f0E67E0F293E9DAC4772Acb457d287  // Fuji testnet
      : 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; // Avalanche mainnet
    
    // Prepare operational addresses array
    address[] memory operationalAddresses = new address[](2);
    operationalAddresses[0] = OPERATIONAL_1;
    operationalAddresses[1] = OPERATIONAL_2;

    // Prepare contract addresses in specific order
    address[] memory contractAddresses = new address[](6);
    contractAddresses[0] = address(brandsProxy);      // index 0
    contractAddresses[1] = address(wrappersProxy);    // index 1
    contractAddresses[2] = address(whitelistProxy);   // index 2
    contractAddresses[3] = address(paymentsProxy);    // index 3
    contractAddresses[4] = address(salesProxy);       // index 4
    contractAddresses[5] = address(membershipsProxy); // index 5

    // User roles to grant to admin (multisig)
    bytes32[] memory userRoles = new bytes32[](5);
    userRoles[0] = keccak256('FIAT');      // Financial operations
    userRoles[1] = keccak256('OWNER');     // Ownership functions
    userRoles[2] = keccak256('PAUSER');    // Emergency pause
    userRoles[3] = keccak256('UPGRADER');  // Contract upgrades
    userRoles[4] = keccak256('TREASURY');  // Treasury management

    // Contract-specific roles (matches contractAddresses order)
    bytes32[] memory contractRoles = new bytes32[](6);
    contractRoles[0] = keccak256('BRANDS');      // Brands contract role
    contractRoles[1] = keccak256('WRAPPERS');    // Wrappers contract role
    contractRoles[2] = keccak256('WHITELIST');   // Whitelist contract role
    contractRoles[3] = keccak256('PAYMENTS');    // Payments contract role
    contractRoles[4] = keccak256('SALES');       // Sales contract role
    contractRoles[5] = keccak256('MEMBERSHIPS'); // Memberships contract role

    // Indices of contracts that need delegate roles
    uint256[] memory delegateIndices = new uint256[](3);
    delegateIndices[0] = 1; // wrappers (index 1)
    delegateIndices[1] = 3; // payments (index 3)
    delegateIndices[2] = 4; // sales (index 4)

    // Deploy Roles with complete configuration
    rolesProxy = new ERC1967Proxy(
      address(rolesImpl),
      abi.encodeCall(rolesImpl.initialize, (
        DEFAULT_ADMIN,
        usdtAddress,
        operationalAddresses,
        contractAddresses,
        userRoles,
        contractRoles,
        delegateIndices
      ))
    );

    console.log('Roles deployed with complete ecosystem setup:');
    console.log('   - All user roles assigned to multisig');
    console.log('   - All contract roles assigned');
    console.log('   - All delegate roles granted');
    console.log('   - USDT payment configured');
  }

  /**
   * @notice Saves deployment information to JSON files
   * @dev Creates both latest.json and timestamped deployment files
   */
  function _saveDeployment() private {
    // Determine network folder
    string memory network = vm.envOr('NODE_ENV', string('dev'));
    string memory folder = keccak256(bytes(network)) == keccak256(bytes('dev')) ? 'testnet' : 'mainnet';
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
}