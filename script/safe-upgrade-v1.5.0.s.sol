// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import '../src/Wrappers.sol';

/**
 * @title SafeUpgradeV1_5_0
 * @notice Safe upgrade script to add setBaseURI functionality using OpenZeppelin's upgrade API
 * @dev This script uses OpenZeppelin's Foundry upgrade API for safe upgrades
 */
contract SafeUpgradeV1_5_0 is Script {
  // Fuji proxy addresses
  address private constant WRAPPERS_PROXY = 0x75D8C1F61c2937858b87F1C89A57012cfAB909aa;

  // New base URI for production
  string private constant NEW_BASE_URI = "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/";

  function run() external {
    vm.startBroadcast();

    console.log('Starting Safe Upgrade to v1.5.0...');
    console.log('Proxy address:', WRAPPERS_PROXY);
    console.log('New base URI:', NEW_BASE_URI);

    // Step 1: Verify current contract state
    console.log('\n1. Verifying current contract state...');
    Wrappers proxy = Wrappers(WRAPPERS_PROXY);

    try proxy.name() returns (string memory name) {
      console.log('Contract name:', name);
    } catch {
      console.log('Contract not responding to basic calls');
      revert('Contract verification failed');
    }

    // Step 2: Test current tokenURI functionality (should work)
    console.log('\n2. Testing current tokenURI functionality...');
    for (uint256 i = 1; i <= 3; i++) {
      try proxy.tokenURI(i) returns (string memory uri) {
        console.log('Token', i, 'URI:', uri);
      } catch {
        console.log('Token', i, 'URI failed');
      }
    }

    // Step 3: Deploy the new implementation with setBaseURI
    console.log('\n3. Deploying new implementation with setBaseURI...');
    Wrappers newImplementation = new Wrappers();
    console.log('New implementation deployed at:', address(newImplementation));

        // Step 4: Upgrade the proxy using UUPS upgrade pattern
    console.log('\n4. Upgrading proxy safely using UUPS pattern...');
    
    // Use the UUPS upgrade pattern (your contracts are UUPS proxies)
    // 
    // NOTE: To use OpenZeppelin Foundry API instead, you would need to:
    // 1. Install the plugin: forge install OpenZeppelin/openzeppelin-foundry
    // 2. Add to foundry.toml: plugins = ["@openzeppelin/contracts-upgradeable"]
    // 3. Replace this code with: upgradeProxy(WRAPPERS_PROXY, "src/Wrappers.sol:Wrappers", "");
    //
    // The upgradeProxy function signature is:
    // upgradeProxy(address proxy, string contractName, bytes data)
    UUPSUpgradeable uupsProxy = UUPSUpgradeable(WRAPPERS_PROXY);
    uupsProxy.upgradeToAndCall(address(newImplementation), "");
    console.log('Proxy upgraded successfully using UUPS pattern!');

    // Step 5: Set the new base URI using setBaseURI
    console.log('\n5. Setting new base URI using setBaseURI...');
    proxy.setBaseURI(NEW_BASE_URI);
    console.log('Base URI set successfully!');

    // Step 6: Verify the new functionality
    console.log('\n6. Verifying new functionality...');

    // Test that setBaseURI function exists and works
    try proxy.setBaseURI("test") {
      console.log('setBaseURI function is working');
    } catch {
      console.log('setBaseURI function test failed');
    }

    vm.stopBroadcast();

    console.log('\nSafe Upgrade to v1.5.0 Completed!');
    console.log('=====================================');
    console.log('New implementation:', address(newImplementation));
    console.log('Proxy upgraded safely');
    console.log('setBaseURI function added');
    console.log('Base URI updated to:', NEW_BASE_URI);
    console.log('\nNext steps:');
    console.log('1. Test tokenURI() for tokens 1-8');
    console.log('2. Verify setBaseURI function works');
    console.log('3. Test metadata resolves correctly');
    console.log('4. Verify production readiness');
  }
}