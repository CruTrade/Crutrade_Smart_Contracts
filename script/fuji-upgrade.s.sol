// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '../src/Wrappers.sol';

/**
 * @title FujiUpgrade
 * @notice Comprehensive upgrade script for Fuji testnet
 * @dev Deploys new implementation, upgrades proxy, and sets base URI
 */
contract FujiUpgrade is Script {
  // Fuji proxy addresses
  address private constant WRAPPERS_PROXY = 0x75D8C1F61c2937858b87F1C89A57012cfAB909aa;

  // New base URI for production
  string private constant NEW_BASE_URI = "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/";

  function run() external {
    vm.startBroadcast();

    console.log('Starting Fuji Wrappers Upgrade...');
    console.log('Proxy address:', WRAPPERS_PROXY);
    console.log('New base URI:', NEW_BASE_URI);

    // Step 1: Deploy new implementation
    console.log('\nDeploying new implementation...');
    Wrappers newImplementation = new Wrappers();
    console.log('New implementation deployed at:', address(newImplementation));

    // Step 2: Upgrade the proxy
    console.log('\nUpgrading proxy...');
    Wrappers proxy = Wrappers(WRAPPERS_PROXY);
    proxy.upgradeToAndCall(address(newImplementation), "");
    console.log('Proxy upgraded successfully!');

    // Step 3: Set new base URI
    console.log('\nSetting new base URI...');
    proxy.setBaseURI(NEW_BASE_URI);
    console.log('Base URI set successfully!');

    vm.stopBroadcast();

    console.log('\nFuji upgrade completed successfully!');
    console.log('=====================================');
    console.log('New implementation:', address(newImplementation));
    console.log('Proxy upgraded');
    console.log('Base URI updated to:', NEW_BASE_URI);
    console.log('\nNext steps:');
    console.log('1. Verify the upgrade on Fuji block explorer');
    console.log('2. Test tokenURI() on existing NFTs');
    console.log('3. Verify metadata resolves correctly');
  }
}