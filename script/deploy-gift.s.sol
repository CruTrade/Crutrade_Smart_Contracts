// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import 'forge-std/Script.sol';
import 'forge-std/console.sol';

import '../src/Gift.sol';
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
        vm.startBroadcast(deployerPrivateKey);

        console.log('Deploying Gift Contract...');
        console.log('Roles address:', rolesAddress);

        // Step 1: Deploy implementation contract
        giftImpl = new Gift();
        console.log('Gift implementation deployed at:', address(giftImpl));

        // Step 2: Deploy proxy contract
        bytes memory initData = abi.encodeCall(
            giftImpl.initialize,
            (rolesAddress)
        );

        giftProxy = new ERC1967Proxy(address(giftImpl), initData);
        giftContract = Gift(address(giftProxy));
        
        console.log('Gift proxy deployed at:', address(giftProxy));

        vm.stopBroadcast();

        // Print summary
        console.log("Deployment complete for", network);
        console.log('Gift Contract addresses:');
        console.log('   - Implementation:', address(giftImpl));
        console.log('   - Proxy:', address(giftProxy));
    }
}




