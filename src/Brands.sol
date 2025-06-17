// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/BrandsBase.sol';
import './interfaces/IBrands.sol';

/**
 * @title Brands
 * @notice Manages brand data in the Crutrade ecosystem as soulbound NFTs
 * @dev Handles brand registration, burning and brand data retrieval
 * @author Crutrade Team
 */
contract Brands is BrandsBase, IBrands {
  /* INITIALIZATION */

  /**
   * @dev Prevents initialization of the implementation contract
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with roles contract address and registers first brand
   * @param _roles Address of the roles contract
   * @param firstBrandOwner Address to register as first brand owner
   */
  function initialize(address _roles, address firstBrandOwner) public initializer {
    __BrandsBase_init(
      _roles,
      'Crutrade Brands',
      'CRUB',
      'https://metadata.crutrade.io/brands/'
    );
    
    // Register first brand automatically
    _register(firstBrandOwner);
  }

  /* BRAND MANAGEMENT */

  /**
   * @notice Registers a new brand
   * @param owner Owner of the brand
   * @return brandId ID of the newly created brand
   */
  function register(address owner) external onlyRole(OWNER) returns (uint256) {
    return _register(owner);
  }

  /**
   * @notice Burns a brand token
   * @param brandId ID of the brand to burn
   */
  function burn(uint256 brandId) external onlyRole(OWNER) {
    _unregister(brandId);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Checks if a brand ID is valid and active
   * @param brandId ID of the brand to check
   * @return True if the brand is active, false otherwise
   */
  function isValidBrand(uint256 brandId) external view override returns (bool) {
    return _isValidBrand(brandId);
  }

  /**
   * @notice Gets the owner of a brand
   * @param brandId ID of the brand
   * @return Address of the brand owner
   */
  function getBrandOwner(
    uint256 brandId
  ) external view override returns (address) {
    return _getBrandOwner(brandId);
  }

  /* ADMIN FUNCTIONS */

  /**
   * @notice Sets the base URI for token metadata
   * @param newBaseURI New base URI
   */
  function setBaseURI(
    string calldata newBaseURI
  ) external onlyRole(OPERATIONAL) {
    _baseURIString = newBaseURI;
  }

  /**
   * @notice Pauses the contract
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   */
  function unpause() external onlyRole(PAUSER) {
    _unpause();
  }

  /**
   * @notice Sets the roles contract address
   * @param _roles New roles contract address
   */
  function setRoles(address _roles) external onlyRole(OPERATIONAL) {
    roles = IRoles(_roles);
    emit RolesSet(_roles);
  }

  /* OVERRIDES */

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721Upgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
