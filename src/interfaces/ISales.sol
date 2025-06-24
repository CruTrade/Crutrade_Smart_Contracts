// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISales
 * @notice Interface for sales operations in the Crutrade ecosystem
 * @dev Defines structures and methods for interacting with the Sales contract
 * @author Crutrade Team
 */
interface ISales {
    /* TYPES */

    /**
     * @dev Date struct definition for sales
     * @param expireListDate Expiration date for listing
     * @param expireUpcomeDate Upcoming expiration date
     */
    struct Date {
        uint256 expireListDate;
        uint256 expireUpcomeDate;
    }

    /**
     * @dev Sale struct definition
     * @param end End timestamp of the sale
     * @param start Start timestamp of the sale
     * @param price Sale price
     * @param seller Address of the seller
     * @param wrapperId ID of the wrapped NFT
     * @param active Whether the sale is active
     */
    struct Sale {
        uint256 end;
        uint256 start;
        uint256 price;
        uint256 wrapperId;
        address seller;
        bool active;
    }

    /* FUNCTIONS */

    /**
     * @notice Retrieves a specific sale
     * @param saleId Sale identifier
     * @return Sale details
     */
    function getSale(uint256 saleId) external view returns (Sale memory);

    /**
     * @notice Retrieves sales for a specific collection
     * @param collection Collection identifier
     * @return Sales in the collection
     */
    function getSalesByCollection(
        bytes32 collection
    ) external view returns (Sale[] memory);
}