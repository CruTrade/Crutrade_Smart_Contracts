// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './ModifiersBase.sol';
import '../interfaces/IWrappers.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol';

/**
 * @title WrapperBase
 * @notice Abstract base contract for managing wrapped NFTs
 * @dev Provides functionality for wrapping, unwrapping, and transferring NFTs
 * @author Crutrade Team
 */
abstract contract WrapperBase is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    ModifiersBase,
    IWrappers
{
    using EnumerableSet for EnumerableSet.UintSet;

    /* STORAGE */

    /// @dev Next wrapper ID counter
    uint256 internal _nextWrapperId;

    /// @dev Base URI for HTTPS metadata
    string internal _httpsBaseURI;

    /// @dev Maps wrapper IDs to their data
    mapping(uint256 => WrapperData) internal _wrappersById;

    /// @dev Maps collections to their wrapper IDs
    mapping(bytes32 => EnumerableSet.UintSet) internal _wrappersByCollection;

    /* EVENTS */

    /**
     * @dev Emitted when wrappers are imported
     * @param user Address of the user
     * @param importData Array of imported wrapper data
     */
    event Import(address indexed user, ImportOutput[] importData);

    /**
     * @dev Emitted when wrappers are exported
     * @param user Address of the user
     * @param wrapperIds Array of exported wrapper IDs
     */
    event Export(address indexed user, uint256[] wrapperIds);

    /**
     * @dev Emitted when multiple wrappers are transferred in a batch
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param tokenIds Array of token IDs
     */
    event BatchTransfer(address indexed from, address to, uint256[] tokenIds);

    /**
     * @dev Emitted when a wrapper is transferred in the marketplace
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param wrapperId ID of the wrapper
     */
    event MarketplaceTransfer(
        address indexed from,
        address indexed to,
        uint256 indexed wrapperId
    );

    /* ERRORS */

    /// @dev Thrown when a wrapper is not found
    error WrapperNotFound(uint256 wrapperId);

    /// @dev Thrown when a transfer is unauthorized
    error UnauthorizedTransfer(address from, address to);

    /// @dev Thrown when a collection is invalid
    error InvalidCollection(uint256 brandId, bytes32 collection);

    /// @dev Thrown when an empty input is provided
    error EmptyInput();

    /// @dev Thrown when an invalid token is provided
    error InvalidToken();

    /// @dev Thrown when a collection does not exist
    error CollectionNotFound(bytes32 collection);

    /**
     * @dev Initializes the WrapperBase contract
     * @param _roles Address of the roles contract
     * @param name Name of the ERC721 token
     * @param symbol Symbol of the ERC721 token
     * @param baseURI Base URI for token metadata
     */
    function __WrapperBase_init(
        address _roles,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal onlyInitializing {
        __ERC721Pausable_init();
        __UUPSUpgradeable_init();
        __ERC721_init(name, symbol);
        __ModifiersBase_init(_roles, WRAPPERS_DOMAIN_NAME, DEFAULT_DOMAIN_VERSION);
        _httpsBaseURI = baseURI;
        _nextWrapperId = 1; // Start from 1 to avoid confusion with default value
    }

    /* WRAPPER MANAGEMENT */

    /**
     * @notice Processes a single wrapper import
     * @param user Address of the user
     * @param wrapper Wrapper data to import
     * @return wrapperId ID of the imported wrapper
     * @return data Data entry for the imported wrapper
     */
    function _processSingleImport(
        address user,
        WrapperData calldata wrapper
    ) internal returns (uint256 wrapperId, ImportOutput memory data) {
        if (wrapper.active) revert InvalidToken();
        wrapperId = _nextWrapperId++;
        bytes32 collection = wrapper.collection;

        _wrappersById[wrapperId] = WrapperData(
            wrapper.uri,
            wrapper.metaKey,
            0,
            wrapper.tokenId,
            wrapper.brandId,
            collection,
            true
        );

        _wrappersByCollection[collection].add(wrapperId);

        data = ImportOutput({
            metaKey: wrapper.metaKey,
            sku: collection,
            tokenId: wrapper.tokenId,
            wrapperId: wrapperId
        });

        _safeMint(user, wrapperId);

        return (wrapperId, data);
    }

    /**
     * @notice Processes a single wrapper export
     * @param wrapperId ID of the wrapper to export
     */
    function _processSingleExport(uint256 wrapperId) internal {
        WrapperData storage wrapper = _wrappersById[wrapperId];
        if (!wrapper.active) revert InvalidToken();
        if (wrapper.collection == bytes32(0)) revert WrapperNotFound(wrapperId);
        wrapper.active = false;
        _wrappersByCollection[wrapper.collection].remove(wrapperId);
    }

    /**
     * @notice Transfers a wrapper between marketplace participants
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param wrapperId ID of the wrapper
     */
    function _marketplaceTransfer(
        address from,
        address to,
        uint256 wrapperId
    ) internal {
        if (_wrappersById[wrapperId].collection == bytes32(0))
            revert WrapperNotFound(wrapperId);
        _update(to, wrapperId, from);
        emit MarketplaceTransfer(from, to, wrapperId);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Gets data for a specific wrapper
     * @param wrapperId ID of the wrapper
     * @return wrapper Wrapper data
     */
    function _getWrapperData(
        uint256 wrapperId
    ) internal view returns (WrapperData memory wrapper) {
        wrapper = _wrappersById[wrapperId];
        if (wrapper.collection == bytes32(0)) revert WrapperNotFound(wrapperId);
        return wrapper;
    }

    /**
     * @notice Gets all wrappers for a specific collection
     * @param collection Collection identifier
     * @return Array of Wrapper data
     */
    function _getCollectionData(
        bytes32 collection
    ) internal view returns (WrapperData[] memory) {
        if (!_isValidCollection(collection)) revert CollectionNotFound(collection);

        uint256[] memory wrapperIds = _wrappersByCollection[collection].values();
        uint256 length = wrapperIds.length;

        WrapperData[] memory wrappers = new WrapperData[](length);

        // Gas optimization for bulk operations
        unchecked {
            for (uint256 i; i < length; i++) {
                wrappers[i] = _wrappersById[wrapperIds[i]];
            }
        }

        return wrappers;
    }

    /**
     * @notice Checks if a wrapper belongs to a collection
     * @param collection Collection identifier
     * @param wrapperId Wrapper ID
     * @return True if the wrapper belongs to the collection
     */
    function _checkCollection(
        bytes32 collection,
        uint256 wrapperId
    ) internal view returns (bool) {
        return _wrappersById[wrapperId].collection == collection;
    }

    /**
     * @notice Checks if a collection is valid
     * @param collection Collection identifier
     * @return True if the collection is valid
     */
    function _isValidCollection(bytes32 collection) internal view returns (bool) {
        return _wrappersByCollection[collection].length() != 0;
    }

    /* TOKEN URI FUNCTIONS */

    /**
     * @notice Gets the token URI
     * @param tokenId ID of the token
     * @return URI string
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (_wrappersById[tokenId].collection == bytes32(0))
            revert WrapperNotFound(tokenId);
        return string(abi.encodePacked(_baseURI(), _toString(tokenId), '.json'));
    }

    /**
     * @notice Gets the HTTPS token URI
     * @param tokenId ID of the token
     * @return URI string
     */
    function _httpsTokenURI(
        uint256 tokenId
    ) internal view returns (string memory) {
        if (_wrappersById[tokenId].collection == bytes32(0))
            revert WrapperNotFound(tokenId);

        return
            string(
                abi.encodePacked(_httpsBaseURI, _wrappersById[tokenId].metaKey, '.json')
            );
    }

    /**
     * @dev Convert a uint256 to its ASCII string decimal representation
     * @param value The uint256 value to convert
     * @return String representation of the value
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // Special case for 0
        if (value == 0) {
            return '0';
        }

        // Count the number of digits
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        // Allocate the string
        bytes memory buffer = new bytes(digits);

        // Fill the string from right to left
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    /* OVERRIDES */

    /**
     * @dev Updates token ownership
     * @param to Address to transfer to
     * @param tokenId ID of the token
     * @param auth Address authorized to make the transfer
     * @return Previous owner address
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
}