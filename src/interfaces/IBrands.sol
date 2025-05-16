// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IBrands
 * @notice Interface for brand management in the Crutrade ecosystem
 * @dev Defines methods for interacting with the Brands contract
 * @author Crutrade Team
 */
interface IBrands {
    /**
     * @notice Checks if a brand is valid
     * @param brandId Brand identifier
     * @return Whether the brand is valid
     */
    function isValidBrand(uint256 brandId) external view returns (bool);

    /**
     * @notice Retrieves brand owner
     * @param brandId Brand identifier
     * @return Owner's address
     */
    function getBrandOwner(uint256 brandId) external view returns (address);
}