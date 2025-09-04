// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MockUSDC is ERC20Permit {
    constructor() ERC20Permit("Mock USDC") ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000 * 1e6); // 1M USDC, 6 decimals
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}