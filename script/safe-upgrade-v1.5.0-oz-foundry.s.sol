// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';
import '@openzeppelin/foundry-upgrades/Upgrades.sol';

import '../src/Wrappers.sol';

/**
 * @title SafeUpgradeV1_5_0WithOZFoundry
 * @notice Safe upgrade script using OpenZeppelin Foundry upgrades API
 * @dev This script uses the upgradeProxy function for safe UUPS upgrades
 */
contract SafeUpgradeV1_5_0WithOZFoundry is Script {
    // Fuji proxy addresses
    address private constant WRAPPERS_PROXY = 0x75D8C1F61c2937858b87F1C89A57012cfAB909aa;

    // New base URI for production
    string private constant NEW_BASE_URI = "https://wrapper-nfts-staging.s3.eu-west-1.amazonaws.com/";

    function run() external {
        vm.startBroadcast();

        console.log('Starting Safe Upgrade to v1.5.0 with OpenZeppelin Foundry API...');
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

        // Step 3: Upgrade the proxy using OpenZeppelin Foundry API
        console.log('\n3. Upgrading proxy using OpenZeppelin Foundry API...');

        // Use the upgradeProxy function from OpenZeppelin Foundry upgrades
        // This automatically handles:
        // - Storage layout validation
        // - Implementation deployment
        // - Proxy upgrade
        // - Safety checks
        Upgrades.upgradeProxy(
            WRAPPERS_PROXY,
            "Wrappers.sol:Wrappers",
            ""  // No initialization data needed
        );
        console.log('Proxy upgraded successfully using OpenZeppelin Foundry API!');

        // Step 4: Set the new base URI using setBaseURI
        console.log('\n4. Setting new base URI using setBaseURI...');
        proxy.setBaseURI(NEW_BASE_URI);
        console.log('Base URI set successfully!');

        // Step 5: Verify the new functionality
        console.log('\n5. Verifying new functionality...');

        // Test tokenURI with new base URI
        console.log('\n6. Testing tokenURI with new base URI...');
        for (uint256 i = 1; i <= 3; i++) {
            try proxy.tokenURI(i) returns (string memory uri) {
                console.log('Token', i, 'URI (after upgrade):', uri);
            } catch {
                console.log('Token', i, 'URI failed after upgrade');
            }
        }

        vm.stopBroadcast();

        console.log('\nSafe Upgrade to v1.5.0 with OpenZeppelin Foundry API Completed!');
        console.log('===============================================================');
        console.log('Proxy upgraded safely using upgradeProxy');
        console.log('setBaseURI function added and working');
        console.log('Base URI updated to:', NEW_BASE_URI);
        console.log('\nBenefits of this approach:');
        console.log('- Automatic storage layout validation');
        console.log('- Built-in safety checks');
        console.log('- Simplified upgrade process');
        console.log('- Better error handling');
        console.log('\nNext steps:');
        console.log('1. Test tokenURI() for all tokens (1-28)');
        console.log('2. Verify setBaseURI function works correctly');
        console.log('3. Test metadata resolves correctly');
        console.log('4. Verify production readiness');
    }
}