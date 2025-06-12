// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/WhitelistBase.sol';
import './interfaces/IWhitelist.sol';

/**
 * @title Whitelist
 * @notice Manages whitelisted addresses in the Crutrade ecosystem
 * @dev Handles adding and removing addresses from the whitelist
 * @author Crutrade Team
 */
contract Whitelist is WhitelistBase, IWhitelist {
  /* INITIALIZATION */

  /**
   * @dev Prevents initialization of the implementation contract
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the contract with the roles contract address
   * @param _roles Address of the roles contract
   */
  function initialize(address _roles) public initializer {
    __WhitelistBase_init(_roles);
  }

  /* ADMIN FUNCTIONS */

  /**
   * @notice Updates the roles contract address
   * @param _roles Address of the new roles contract
   */
  function setRoles(address _roles) external onlyRole(OWNER) {
    roles = IRoles(_roles);
    emit RolesSet(_roles);
  }

  /**
   * @notice Pauses the contract
   * @dev Can only be called by an account with the PAUSER role
   */
  function pause() external onlyRole(PAUSER) {
    _pause();
  }

  /**
   * @notice Unpauses the contract
   * @dev Can only be called by an account with the PAUSER role
   */
  function unpause() external onlyRole(PAUSER) {
    _unpause();
  }

  /* PUBLIC FUNCTIONS */

  /**
   * @notice Adds multiple addresses to the whitelist
   * @param wallets Addresses to add to the whitelist
   * @dev Can only be called by an account with the OPERATIONAL role
   * @dev Contract must not be paused
   */
  function addToWhitelist(
    address[] calldata wallets
  ) external whenNotPaused onlyRole(OPERATIONAL) {
    _addToWhitelist(wallets);
  }

  /**
   * @notice Removes multiple addresses from the whitelist
   * @param wallets Addresses to remove from the whitelist
   * @dev Can only be called by an account with the OPERATIONAL role
   * @dev Contract must not be paused
   */
  function removeFromWhitelist(
    address[] calldata wallets
  ) external whenNotPaused onlyRole(OPERATIONAL) {
    _removeFromWhitelist(wallets);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Checks if an address is in the whitelist
   * @param wallet Address to check
   * @return True if the address is whitelisted
   */
  function isWhitelisted(address wallet) external view override returns (bool) {
    return _isWhitelisted(wallet);
  }

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}
}
