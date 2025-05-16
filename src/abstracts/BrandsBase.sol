// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './ModifiersBase.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol';

/**
 * @title BrandsBase
 * @notice Abstract base contract for managing brand data as soulbound NFTs
 * @dev Provides functionality for brand registration, burning, and data retrieval
 * @author Crutrade Team
 */
abstract contract BrandsBase is
    Initializable,
    ERC721PausableUpgradeable,
    UUPSUpgradeable,
    ModifiersBase
{
    /* STORAGE */

    /// @dev Counter for brand IDs
    uint256 internal _brandIdCounter;

    /// @dev Base URI for brand metadata
    string internal _baseURIString;

    /* EVENTS */

    /**
     * @dev Emitted when a brand is registered
     * @param owner Address of the brand owner
     * @param brandId ID of the registered brand
     */
    event BrandRegistered(address indexed owner, uint256 indexed brandId);

    /**
     * @dev Emitted when a brand is burned
     * @param brandId ID of the burned brand
     */
    event BrandBurned(uint256 indexed brandId);

    /* ERRORS */

    /// @dev Thrown when a transfer of a soulbound token is attempted
    error NotTransferable();

    /// @dev Thrown when a brand is not found
    error BrandNotFound(uint256 brandId);

    /// @dev Thrown when an invalid brand owner is provided
    error InvalidBrandOwner(address owner);

    /**
     * @dev Initializes the BrandsBase contract
     * @param _roles Address of the roles contract
     * @param name Name of the ERC721 token
     * @param symbol Symbol of the ERC721 token
     * @param baseURI Base URI for token metadata
     */
    function __BrandsBase_init(
        address _roles,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal onlyInitializing {
        __ERC721_init(name, symbol);
        __ERC721Pausable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ModifiersBase_init(_roles);

        _baseURIString = baseURI;
    }

    /* BRAND MANAGEMENT */

    /**
     * @notice Registers a new brand
     * @param owner Owner of the brand
     * @return brandId ID of the newly created brand
     */
    function _register(address owner) internal returns (uint256) {
        if (owner == address(0)) revert InvalidBrandOwner(owner);

        uint256 brandId = _brandIdCounter++;
        _safeMint(owner, brandId);

        emit BrandRegistered(owner, brandId);
        return brandId;
    }

    /**
     * @notice Burns a brand token
     * @param brandId ID of the brand to burn
     */
    function _unregister(uint256 brandId) internal {
        if (_ownerOf(brandId) == address(0)) revert BrandNotFound(brandId);

        super._burn(brandId);
        emit BrandBurned(brandId);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Checks if a brand ID is valid and active
     * @param brandId ID of the brand to check
     * @return True if the brand is active, false otherwise
     */
    function _isValidBrand(uint256 brandId) internal view returns (bool) {
        return _ownerOf(brandId) != address(0);
    }

    /**
     * @notice Gets the owner of a brand
     * @param brandId ID of the brand
     * @return Address of the brand owner
     */
    function _getBrandOwner(uint256 brandId) internal view returns (address) {
        address owner = _ownerOf(brandId);
        if (owner == address(0)) revert BrandNotFound(brandId);
        return owner;
    }

    /**
     * @dev Returns the base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIString;
    }

    /* OVERRIDES */

    /**
     * @dev Block transfers to make tokens soulbound
     * @param to Destination address
     * @param tokenId Token ID to update
     * @param auth Address authorized to make the transfer
     * @return Updated token address
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721PausableUpgradeable) returns (address) {
        address from = _ownerOf(tokenId);

        // Block transfers, allow only minting and burning
        if (from != address(0) && to != address(0)) {
            revert NotTransferable();
        }

        return super._update(to, tokenId, auth);
    }
}