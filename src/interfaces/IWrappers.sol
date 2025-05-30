// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IWrappers
 * @notice Interface for wrapped NFT management in the Crutrade ecosystem
 * @dev Defines core structures and method signatures for wrapper operations
 * @author Crutrade Team
 */
interface IWrappers {
    /* TYPES */
    
    /**
     * @notice Wrapper metadata structure
     * @dev Represents a wrapped NFT with its associated metadata
     * @param uri URI for wrapper metadata
     * @param metaKey Unique metadata key
     * @param amount Associated amount or quantity
     * @param tokenId Original token ID
     * @param brandId Associated brand identifier
     * @param collection Collection identifier
     * @param active Wrapper active status
     */
    struct WrapperData {
        string uri;
        string metaKey;
        uint256 amount;
        uint256 tokenId;
        uint256 brandId;
        bytes32 collection;
        bool active;
    }

    /**
     * @notice Import/Export data structure
     * @dev Captures essential information for wrapper import/export operations
     * @param metaKey Metadata key
     * @param sku Stock Keeping Unit
     * @param tokenId Original token ID
     * @param wrapperId Generated wrapper ID
     */
    struct ImportOutput {
        string metaKey;
        bytes32 sku;
        uint256 tokenId;
        uint256 wrapperId;
    }

    /* FUNCTIONS */
    
    /**
     * @notice Retrieves wrapper data by ID
     * @param wrapperId Unique identifier for the wrapper
     * @return Wrapper details
     */
    function getWrapperData(
        uint256 wrapperId
    ) external view returns (WrapperData memory);

    /**
     * @notice Retrieves all wrappers for a specific collection
     * @param collection Collection identifier
     * @return Array of Wrapper data
     */
    function getCollectionData(
        bytes32 collection
    ) external view returns (WrapperData[] memory);

    /**
     * @notice Performs a marketplace transfer of a wrapper
     * @param from Sender address
     * @param to Recipient address
     * @param wrapperId Wrapper to transfer
     */
    function marketplaceTransfer(
        address from,
        address to,
        uint256 wrapperId
    ) external;

    /**
     * @notice Checks if a wrapper belongs to a specific collection
     * @param collection Collection identifier
     * @param wrapperId Wrapper ID to check
     * @return Boolean indicating collection membership
     */
    function checkCollection(
        bytes32 collection,
        uint256 wrapperId
    ) external view returns (bool);

    /**
     * @notice Validates a collection
     * @param collection Collection identifier
     * @return Boolean indicating collection validity
     */
    function isValidCollection(bytes32 collection) external view returns (bool);
}