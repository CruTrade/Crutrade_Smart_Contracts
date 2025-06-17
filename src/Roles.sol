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
   * @notice Initializes the contract with complete ecosystem setup
   * @dev Sets up all roles, delegates, and payment configuration in one call
   * @param defaultAdmin Address of the default admin (multisig)
   * @param usdtAddress Address of the USDT token for payments
   * @param operationalAddresses Array of addresses to grant OPERATIONAL role
   * @param contractAddresses Array of contract addresses for role assignment
   * @param userRoles Array of role hashes to grant to defaultAdmin
   * @param contractRoles Array of role hashes to grant to contracts (matches contractAddresses order)
   * @param delegateIndices Array of indices indicating which contracts get delegate roles
   */
  function initialize(
    address defaultAdmin,
    address usdtAddress,
    address[] calldata operationalAddresses,
    address[] calldata contractAddresses,
    bytes32[] calldata userRoles,
    bytes32[] calldata contractRoles,
    uint256[] calldata delegateIndices
  ) public initializer {
    __RolesBase_init(defaultAdmin);
    
    // Grant all user roles to admin (FIAT, OWNER, PAUSER, UPGRADER, TREASURY)
    for (uint256 i = 0; i < userRoles.length; i++) {
      _grantRole(userRoles[i], defaultAdmin);
    }
    
    // Grant operational roles to specified addresses
    bytes32 operationalRole = keccak256('OPERATIONAL');
    for (uint256 i = 0; i < operationalAddresses.length; i++) {
      _grantRole(operationalRole, operationalAddresses[i]);
    }
    
    // Grant delegate roles to contracts that need them (payments, sales, wrappers)
    for (uint256 i = 0; i < delegateIndices.length; i++) {
      if (delegateIndices[i] < contractAddresses.length) {
        _grantDelegateRole(contractAddresses[delegateIndices[i]]);
      }
    }
    
    // Grant contract-specific roles (BRANDS, WRAPPERS, WHITELIST, etc.)
    for (uint256 i = 0; i < contractAddresses.length && i < contractRoles.length; i++) {
      _grantRole(contractRoles[i], contractAddresses[i]);
    }
    
    // Configure USDT as payment token with 6 decimals
    _setPayment(usdtAddress, 6);
    _setDefaultFiatToken(usdtAddress);
  }

  /* PAYMENT CONFIGURATION */

  /**
   * @notice Configures a payment token
   * @param token Address of the token
   * @param decimals Number of decimals for the token
   */
  function setPayment(address token, uint8 decimals) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPayment(token, decimals);
  }

  /**
   * @notice Sets the default fiat token
   * @param token Address of the token
   */
  function setDefaultFiatToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setDefaultFiatToken(token);
  }

  /* ROLE MANAGEMENT */

  /**
   * @notice Grants delegation rights to a contract
   * @param contractAddress Address of the contract
   */
  function grantDelegateRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantDelegateRole(contractAddress);
  }

  /**
   * @notice Revokes delegation rights from a contract
   * @param contractAddress Address of the contract
   */
  function revokeDelegateRole(address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeDelegateRole(contractAddress);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Checks if a contract has delegate role
   * @param _contract Contract address to check
   * @return Boolean indicating delegate status
   */
  function hasDelegateRole(address _contract) external view override returns (bool) {
    return _delegated[_contract];
  }

  /**
   * @notice Checks if a payment method is allowed
   * @param _contract Payment contract address
   * @return Boolean indicating payment role status
   */
  function hasPaymentRole(address _contract) external view override returns (bool) {
    return _payments[_contract].isConfigured;
  }

  /**
   * @notice Retrieves the address assigned to a specific role
   * @param role Role identifier
   * @return Address assigned to the role
   */
  function getRoleAddress(bytes32 role) external view override returns (address) {
    return _addresses[role];
  }

  /**
   * @notice Retrieves the default fiat payment token address
   * @return Address of the default fiat payment token
   */
  function getDefaultFiatPayment() external view override returns (address) {
    return _defaultFiatToken;
  }

  /* ADMIN FUNCTIONS */

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

  /* OVERRIDES */

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER) {
    if (newImplementation == address(0)) revert InvalidContract(newImplementation);
  }
}