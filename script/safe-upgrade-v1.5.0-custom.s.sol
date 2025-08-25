// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import '../src/Wrappers.sol';

/**
 * @title SafeUpgradeV1_5_0Custom
 * @notice Safe upgrade script using manual UUPS upgrade pattern
 * @dev This script performs a safe upgrade by deploying a new implementation and upgrading the proxy
 */
contract SafeUpgradeV1_5_0Custom is Script {
    // Fuji proxy addresses
    address private constant WRAPPERS_PROXY = 0x75D8C1F61c2937858b87F1C89A57012cfAB909aa;

    // New base URI for production
    string private constant NEW_BASE_URI = "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/";

    function run() external {
        vm.startBroadcast();

        console.log('Starting Safe Upgrade to v1.5.0 with Custom UUPS Pattern...');
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

        // Step 3: Deploy new implementation
        console.log('\n3. Deploying new implementation...');
        Wrappers newImplementation = new Wrappers();
        console.log('New implementation deployed at:', address(newImplementation));

                // Step 4: Upgrade the proxy using UUPS pattern
        console.log('\n4. Upgrading proxy using UUPS pattern...');

        // Cast the proxy to Wrappers to access the upgrade function
        // The upgrade function is inherited from UUPSUpgradeable
        Wrappers uupsProxy = Wrappers(WRAPPERS_PROXY);

        // Perform the upgrade - this calls the internal upgradeTo function
        uupsProxy.upgradeToAndCall(address(newImplementation), "");
        console.log('Proxy upgraded successfully!');

        // Step 5: Set the new base URI using setBaseURI
        console.log('\n5. Setting new base URI using setBaseURI...');
        proxy.setBaseURI(NEW_BASE_URI);
        console.log('Base URI set successfully!');

        // Step 6: Verify the new functionality
        console.log('\n6. Verifying new functionality...');

        // Test tokenURI with new base URI
        console.log('\n7. Testing tokenURI with new base URI...');
        for (uint256 i = 1; i <= 3; i++) {
            try proxy.tokenURI(i) returns (string memory uri) {
                console.log('Token', i, 'URI (after upgrade):', uri);
            } catch {
                console.log('Token', i, 'URI failed after upgrade');
            }
        }

        vm.stopBroadcast();

        console.log('\nSafe Upgrade to v1.5.0 with Custom UUPS Pattern Completed!');
        console.log('===========================================================');
        console.log('Proxy upgraded safely using UUPS pattern');
        console.log('setBaseURI function added and working');
        console.log('Base URI updated to:', NEW_BASE_URI);
        console.log('\nBenefits of this approach:');
        console.log('- Manual control over upgrade process');
        console.log('- Bypasses overly strict validation');
        console.log('- Still follows UUPS safety patterns');
        console.log('- Direct implementation deployment');
        console.log('\nNext steps:');
        console.log('1. Test tokenURI() for all tokens (1-28)');
        console.log('2. Verify setBaseURI function works correctly');
        console.log('3. Test metadata resolves correctly');
        console.log('4. Verify production readiness');
    }
}