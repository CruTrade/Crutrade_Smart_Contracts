// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IMemberships
 * @notice Interface for membership management in the Crutrade ecosystem
 * @dev Defines methods for interacting with the Memberships contract
 * @author Crutrade Team
 */
interface IMemberships {
    /**
     * @notice Retrieves membership ID for a specific account
     * @param account Address to check
     * @return Membership ID
     */
    function getMembership(address account) external view returns (uint256);

    /**
     * @notice Retrieves membership IDs for multiple accounts
     * @param accounts Array of addresses to check
     * @return Array of membership IDs
     */
    function getMemberships(
        address[] calldata accounts
    ) external view returns (uint256[] memory);
}