// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IWhitelist
 * @notice Interface for whitelist management in the Crutrade ecosystem
 * @dev Defines methods for interacting with the Whitelist contract
 * @author Crutrade Team
 */
interface IWhitelist {
    /**
     * @notice Checks if an address is whitelisted
     * @param wallet Address to check
     * @return Whitelist status
     */
    function isWhitelisted(address wallet) external view returns (bool);
}