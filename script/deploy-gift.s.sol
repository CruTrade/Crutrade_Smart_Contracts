// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '../src/Gift.sol';
import '../src/Roles.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

/**
 * @title DeployGift
 * @notice Deployment script for the Gift contract
 * @dev Deploys both implementation and proxy for the Gift contract
 * @author Crutrade Team
 */
contract DeployGift is Script {
    /// @notice Gift contract implementation
    Gift public giftImpl;
    
    /// @notice Gift contract proxy
    ERC1967Proxy public giftProxy;
    
    /// @notice Gift contract instance (proxy)
    Gift public giftContract;

    address private constant ANVIL_ADDRESS_1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant ANVIL_ADDRESS_1_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

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
        uint256 deployerPrivateKey = ANVIL_ADDRESS_1_PRIVATE_KEY;
        address rolesAddress = vm.envOr("ROLES_ADDRESS", ANVIL_ADDRESS_1);
        _deployGift(deployerPrivateKey, "local", rolesAddress);
    }

    function runTestnet() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address rolesAddress = vm.envAddress("ROLES_ADDRESS");
        _deployGift(deployerPrivateKey, "fuji", rolesAddress);
    }

    function runMainnet() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address rolesAddress = vm.envAddress("ROLES_ADDRESS");
        _deployGift(deployerPrivateKey, "mainnet", rolesAddress);
    }

    function _deployGift(uint256 deployerPrivateKey, string memory network, address rolesAddress) internal {
        require(rolesAddress != address(0), "Invalid roles address: address(0)");
        
        vm.startBroadcast(deployerPrivateKey);

        console.log('Deploying Gift Contract...');
        console.log('Network:', network);
        console.log('Roles address:', rolesAddress);

        // Step 1: Deploy implementation contract
        console.log('\nStep 1: Deploying Gift implementation...');
        giftImpl = new Gift();
        require(address(giftImpl) != address(0), "Failed to deploy Gift implementation");
        console.log('   Gift implementation deployed at:', address(giftImpl));

        // Step 2: Deploy proxy contract
        console.log('\nStep 2: Deploying Gift proxy...');
        bytes memory initData = abi.encodeCall(
            giftImpl.initialize,
            (rolesAddress)
        );

        giftProxy = new ERC1967Proxy(address(giftImpl), initData);
        giftContract = Gift(address(giftProxy));
        require(address(giftProxy) != address(0), "Failed to deploy Gift proxy");
        console.log('   Gift proxy deployed at:', address(giftProxy));

        // Step 3: Grant delegate role to Gift contract
        console.log('\nStep 3: Granting delegate role to Gift contract...');
        Roles roles = Roles(rolesAddress);
        
        // Check if contract already has delegate role
        bool alreadyHasRole = roles.hasDelegateRole(address(giftProxy));
        if (alreadyHasRole) {
            console.log('   Gift contract already has delegate role');
        } else {
            // Grant delegate role - will revert if it fails
            console.log('   Sending grantDelegateRole transaction...');
            roles.grantDelegateRole(address(giftProxy));
            console.log('   Delegate role grant transaction sent');
        }

        // Step 4: Verify delegate role was granted
        console.log('\nStep 4: Verifying delegate role...');
        bool hasRole = roles.hasDelegateRole(address(giftProxy));
        require(hasRole, "CRITICAL: Delegate role verification failed - Gift contract does not have delegate role after grant");
        console.log('   Delegate role verified successfully');

        vm.stopBroadcast();

        // Print summary
        console.log('\n========================================');
        console.log("Deployment complete for", network);
        console.log('========================================');
        console.log('Gift Contract addresses:');
        console.log('   - Implementation:', address(giftImpl));
        console.log('   - Proxy:', address(giftProxy));
        console.log('   - Roles Contract:', rolesAddress);
        console.log('   - Delegate Role: Granted and Verified');
        console.log('========================================\n');
    }
}




