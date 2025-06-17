// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/RolesBase.sol';
import './interfaces/IRoles.sol';

/**
 * @title Roles
 * @notice Permission and role management system for the Crutrade ecosystem
 * @dev Manages role assignments, delegates, payment configurations, and access control
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Roles is RolesBase, IRoles {
  /* INITIALIZATION */

  /**
   * @dev Prevents initialization of the implementation contract
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the contract with the default admin address
   * @param defaultAdmin Address of the default admin
   */
  function initialize(address defaultAdmin) public initializer {
    __RolesBase_init(defaultAdmin);
  }

  /* PAYMENT CONFIGURATION */

  /**
   * @notice Configures a payment token
   * @param token Address of the token
   * @param decimals Number of decimals for the token
   */
  function setPayment(
    address token,
    uint8 decimals
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPayment(token, decimals);
  }

  /**
   * @notice Sets the default fiat token
   * @param token Address of the token
   */
  function setDefaultFiatToken(
    address token
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setDefaultFiatToken(token);
  }

  /* ROLE MANAGEMENT */

  /**
   * @notice Grants delegation rights to a contract
   * @param contractAddress Address of the contract
   */
  function grantDelegateRole(
    address contractAddress
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantDelegateRole(contractAddress);
  }

  /**
   * @notice Revokes delegation rights from a contract
   * @param contractAddress Address of the contract
   */
  function revokeDelegateRole(
    address contractAddress
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeDelegateRole(contractAddress);
  }

  /**
   * @notice Grants a role to an account
   * @param role Role identifier
   * @param account Address to grant the role to
   */
  function grantRole(
    bytes32 role,
    address account
  )
    public
    virtual
    override(AccessControlUpgradeable, IAccessControl)
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    _addresses[role] = account;
    _grantRole(role, account);
  }

  /**
   * @notice Revokes a role from an account
   * @param role Role identifier
   * @param account Address to revoke the role from
   */
  function revokeRole(
    bytes32 role,
    address account
  )
    public
    virtual
    override(AccessControlUpgradeable, IAccessControl)
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    delete _addresses[role];
    _revokeRole(role, account);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Gets the number of decimals for a token
   * @param token Address of the token
   * @return Number of decimals
   */
  function getTokenDecimals(address token) external view returns (uint8) {
    return _getTokenDecimals(token);
  }

  /**
   * @notice Gets the default fiat payment token address
   * @return Address of the token
   */
  function getDefaultFiatPayment() external view override returns (address) {
    return _getDefaultFiatPayment();
  }

  /**
   * @notice Gets the address assigned to a role
   * @param role Role identifier
   * @return Address assigned to the role
   */
  function getRoleAddress(
    bytes32 role
  ) external view override returns (address) {
    return _getRoleAddress(role);
  }

  /**
   * @notice Checks if a token is configured for payments
   * @param token Address of the token
   * @return True if the token is configured
   */
  function hasPaymentRole(address token) external view override returns (bool) {
    return _hasPaymentRole(token);
  }

  /**
   * @notice Checks if a contract has delegation rights
   * @param contractAddress Address of the contract
   * @return True if the contract is delegated
   */
  function hasDelegateRole(
    address contractAddress
  ) public view virtual override returns (bool) {
    return _hasDelegateRole(contractAddress);
  }

  /* ADMIN FUNCTIONS */

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

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal view override onlyRole(UPGRADER) {
    if (newImplementation == address(0)) revert InvalidContract(newImplementation);
  }
}