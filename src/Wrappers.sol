// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/WrapperBase.sol';
import './interfaces/IWrappers.sol';

/**
 * @title Wrappers
 * @notice Manages wrapped NFTs in the Crutrade ecosystem
 * @dev Implements a wrapper system for NFTs with brand and category management
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Wrappers is WrapperBase {
  /* INITIALIZATION */

  /**
   * @dev Prevents initialization of the implementation contract
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the contract with the roles contract address
   * @param _roles Address of the roles contract
   */
  function initialize(address _roles) public initializer {
    if (_roles == address(0)) revert ZeroAddress();
    __WrapperBase_init(
      _roles,
      'Crutrade Wrappers',
      'CRUW',
      'https://cdn.crutrade.io/'
    );
  }

  /* ADMIN FUNCTIONS */

  /**
   * @notice Sets the HTTPS base URI
   * @param url New base URI
   * @dev Can only be called by an account with the OWNER role
   */
  function setHttpsBaseURI(string calldata url) external onlyRole(OWNER) {
    _httpsBaseURI = url;
  }

  /**
   * @notice Sets the base URI for token metadata
   * @param newBaseURI New base URI
   * @dev Can only be called by an account with the OWNER role
   */
  function setBaseURI(string calldata newBaseURI) external onlyRole(OWNER) {
    _baseURIString = newBaseURI;
  }

  /**
   * @notice Sets the roles contract address
   * @param _roles Address of the new roles contract
   * @dev Can only be called by an account with the OWNER role
   */
  function setRoles(
    address _roles
  ) external onlyRole(OWNER) checkAddressZero(_roles) {
    roles = IRoles(_roles);
    emit RolesSet(_roles);
  }

  /**
   * @notice Pauses the contract
   * @dev Can only be called by the PAUSER role
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   * @dev Can only be called by the PAUSER role
   */
  function unpause() external onlyRole(PAUSER) {
    _unpause();
  }

  /* WRAPPER MANAGEMENT */

  /**
   * @notice Imports wrappers
   * @param user Address of the user
   * @param wrappers Array of wrapper data to import
   * @dev Can only be called by an account with the OPERATIONAL role
   */
  function imports(
    address user,
    WrapperData[] calldata wrappers
  )
    external
    whenNotPaused
    onlyRole(OPERATIONAL)
    onlyWhitelisted(user)
    checkAddressZero(user)
  {
    uint256 length = wrappers.length;
    if (length == 0) revert EmptyInput();

    ImportOutput[] memory data = new ImportOutput[](length);

    for (uint256 i; i < length; i++) {
      (, ImportOutput memory wrapperData) = _processSingleImport(
        user,
        wrappers[i]
      );
      data[i] = wrapperData;
    }

    emit Import(user, data);
  }

  /**
   * @notice Exports wrappers
   * @param user Address of the user
   * @param wrapperIds IDs of the wrappers to export
   * @dev Can only be called by an account with the OPERATIONAL role
   */
  function exports(
    address user,
    uint[] calldata wrapperIds
  )
    external
    whenNotPaused
    onlyRole(OPERATIONAL)
    onlyWhitelisted(user)
    checkAddressZero(user)
  {
    uint256 length = wrapperIds.length;
    if (length == 0) revert EmptyInput();

    for (uint256 i; i < length; i++) {
      _processSingleExport(wrapperIds[i]);
    }

    emit Export(user, wrapperIds);
  }

  /**
   * @notice Transfers a wrapper between marketplace participants
   * @param from Address to transfer from
   * @param to Address to transfer to
   * @param wrapperId ID of the wrapper
   * @dev Can only be called by contracts with delegation rights
   */
  function marketplaceTransfer(
    address from,
    address to,
    uint wrapperId
  )
    external
    override
    whenNotPaused
    onlyDelegatedRole
    checkAddressZero(from)
    checkAddressZero(to)
  {
    _marketplaceTransfer(from, to, wrapperId);
  }

  /**
   * @notice Transfers multiple wrappers
   * @param to Address to transfer to
   * @param wrapperIds IDs of the wrappers
   * @dev Can only be called by an account with the OWNER role
   */
  function batchTransfer(
    address to,
    uint256[] calldata wrapperIds
  ) external whenNotPaused onlyRole(OWNER) checkAddressZero(to) {
    uint256 length = wrapperIds.length;
    if (length == 0) revert EmptyInput();

    address owner = roles.getRoleAddress(OWNER);
    for (uint256 i; i < length; i++) {
      if (_wrappersById[wrapperIds[i]].collection == bytes32(0))
        revert WrapperNotFound(wrapperIds[i]);
      _update(to, wrapperIds[i], owner);
    }

    emit BatchTransfer(owner, to, wrapperIds);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Gets data for a specific wrapper
   * @param wrapperId ID of the wrapper
   * @return wrapper Wrapper data
   */
  function getWrapperData(
    uint256 wrapperId
  ) external view override returns (WrapperData memory) {
    return _getWrapperData(wrapperId);
  }

  /**
   * @notice Gets all wrappers for a specific collection
   * @param collection Collection identifier
   * @return Array of Wrapper data
   */
  function getCollectionData(
    bytes32 collection
  ) external view override returns (WrapperData[] memory) {
    return _getCollectionData(collection);
  }

  /**
   * @notice Checks if a wrapper belongs to a collection
   * @param collection Collection identifier
   * @param wrapperId Wrapper ID
   * @return True if the wrapper belongs to the collection
   */
  function checkCollection(
    bytes32 collection,
    uint256 wrapperId
  ) external view override returns (bool) {
    return _checkCollection(collection, wrapperId);
  }

  /**
   * @notice Checks if a collection is valid
   * @param collection Collection identifier
   * @return True if the collection is valid
   */
  function isValidCollection(
    bytes32 collection
  ) external view override returns (bool) {
    return _isValidCollection(collection);
  }

  /**
   * @notice Gets the HTTPS token URI
   * @param tokenId ID of the token
   * @return URI string
   */
  function httpsTokenURI(
    uint256 tokenId
  ) external view returns (string memory) {
    return _httpsTokenURI(tokenId);
  }

  /* OVERRIDES */

  /**
   * @dev Checks if the contract supports an interface
   * @param interfaceId ID of the interface
   * @return True if the interface is supported
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721Upgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   * @dev Can only be called by an account with the UPGRADER role
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}
}