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

contract CrutradeDeploy is Script {
  address private constant DEFAULT_ADMIN = 0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6;

  // Contract instances
  Roles rolesImpl;
  Brands brandsImpl;
  Wrappers wrappersImpl;
  Whitelist whitelistImpl;
  Payments paymentsImpl;
  Sales salesImpl;
  Memberships membershipsImpl;

  ERC1967Proxy rolesProxy;
  ERC1967Proxy brandsProxy;
  ERC1967Proxy wrappersProxy;
  ERC1967Proxy whitelistProxy;
  ERC1967Proxy paymentsProxy;
  ERC1967Proxy salesProxy;
  ERC1967Proxy membershipsProxy;

  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    vm.startBroadcast(deployerPrivateKey);

    console.log('Deploying CruTrade...');

    _deployImplementations();
    _deployProxies();
    _configureSystem();
    _saveDeployment();

    console.log('Deploy complete');
    vm.stopBroadcast();
  }

  function _deployImplementations() private {
    rolesImpl = new Roles();
    brandsImpl = new Brands();
    wrappersImpl = new Wrappers();
    whitelistImpl = new Whitelist();
    paymentsImpl = new Payments();
    salesImpl = new Sales();
    membershipsImpl = new Memberships();
    console.log('Implementations deployed');
  }

  function _deployProxies() private {
    rolesProxy = new ERC1967Proxy(
      address(rolesImpl),
      abi.encodeCall(rolesImpl.initialize, (DEFAULT_ADMIN))
    );

    brandsProxy = new ERC1967Proxy(
      address(brandsImpl),
      abi.encodeCall(brandsImpl.initialize, (address(rolesProxy)))
    );

    wrappersProxy = new ERC1967Proxy(
      address(wrappersImpl),
      abi.encodeCall(wrappersImpl.initialize, (address(rolesProxy)))
    );

    whitelistProxy = new ERC1967Proxy(
      address(whitelistImpl),
      abi.encodeCall(whitelistImpl.initialize, (address(rolesProxy)))
    );

    paymentsProxy = new ERC1967Proxy(
      address(paymentsImpl),
      abi.encodeCall(paymentsImpl.initialize, (address(rolesProxy)))
    );

    salesProxy = new ERC1967Proxy(
      address(salesImpl),
      abi.encodeCall(salesImpl.initialize, (address(rolesProxy)))
    );

    membershipsProxy = new ERC1967Proxy(
      address(membershipsImpl),
      abi.encodeCall(membershipsImpl.initialize, (address(rolesProxy)))
    );
    console.log('Proxies deployed');
  }

  function _configureSystem() private {
    Roles roles = Roles(address(rolesProxy));

    // Grant delegate roles
    roles.grantDelegateRole(address(paymentsProxy));
    roles.grantDelegateRole(address(salesProxy));
    roles.grantDelegateRole(address(wrappersProxy));

    // Set contract roles
    roles.grantRole(keccak256('BRANDS'), address(brandsProxy));
    roles.grantRole(keccak256('WRAPPERS'), address(wrappersProxy));
    roles.grantRole(keccak256('WHITELIST'), address(whitelistProxy));
    roles.grantRole(keccak256('PAYMENTS'), address(paymentsProxy));
    roles.grantRole(keccak256('MEMBERSHIPS'), address(membershipsProxy));
    roles.grantRole(keccak256('SALES'), address(salesProxy));
    console.log('System configured');
  }

  function _saveDeployment() private {
    string memory network = vm.envOr('NODE_ENV', string('dev'));
    string memory folder = keccak256(bytes(network)) == keccak256(bytes('dev')) ? 'testnet' : 'mainnet';
    string memory dirPath = string.concat('./deployments/', folder);

    // Create directory
    string[] memory mkdirCmd = new string[](3);
    mkdirCmd[0] = 'mkdir';
    mkdirCmd[1] = '-p';
    mkdirCmd[2] = dirPath;
    vm.ffi(mkdirCmd);

    // Build JSON
    string memory json = '{}';
    json = vm.serializeUint('deployment', 'chainId', block.chainid);
    json = vm.serializeUint('deployment', 'timestamp', block.timestamp);
    json = vm.serializeAddress('deployment', 'roles', address(rolesProxy));
    json = vm.serializeAddress('deployment', 'brands', address(brandsProxy));
    json = vm.serializeAddress('deployment', 'wrappers', address(wrappersProxy));
    json = vm.serializeAddress('deployment', 'whitelist', address(whitelistProxy));
    json = vm.serializeAddress('deployment', 'payments', address(paymentsProxy));
    json = vm.serializeAddress('deployment', 'sales', address(salesProxy));
    json = vm.serializeAddress('deployment', 'memberships', address(membershipsProxy));

    // Save files
    vm.writeJson(json, string.concat(dirPath, '/latest.json'));
    vm.writeJson(json, string.concat(dirPath, '/', vm.toString(block.timestamp), '.json'));

    console.log('Saved to deployments/', folder);
  }
}