// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import '../interfaces/IRoles.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts/access/IAccessControl.sol';

/**
 * @title RolesBase
 * @notice Abstract base contract for role management in the Crutrade ecosystem
 * @dev Provides core functionality for managing roles, delegations, and payment configurations
 * @author Crutrade Team
 */
abstract contract RolesBase is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    /* CONSTANTS */

    /// @notice Pauser role identifier
    bytes32 internal constant PAUSER = keccak256('PAUSER');
    
    /// @notice Upgrader role identifier
    bytes32 internal constant UPGRADER = keccak256('UPGRADER');
    
    /// @notice Fiat role identifier
    bytes32 internal constant FIAT = keccak256('FIAT');

    /* STORAGE */

    /// @dev Maps tokens to their payment configurations
    mapping(address => Payment) internal _payments;

    /// @dev Maps contracts to their delegation status
    mapping(address => bool) internal _delegated;

    /// @dev Maps roles to their assigned addresses
    mapping(bytes32 => address) internal _addresses;

    /// @dev Address of the default fiat token
    address internal _defaultFiatToken;

    /* EVENTS */

    /**
     * @dev Emitted when a payment token is configured
     * @param token Address of the token
     * @param decimals Number of decimals for the token
     */
    event PaymentSet(address indexed token, uint8 decimals);

    /**
     * @dev Emitted when the default fiat token is set
     * @param token Address of the token
     */
    event DefaultFiatTokenSet(address indexed token);

    /**
     * @dev Emitted when a contract is granted delegation rights
     * @param contractAddress Address of the contract
     */
    event DelegateRoleGranted(address indexed contractAddress);

    /**
     * @dev Emitted when a contract's delegation rights are revoked
     * @param contractAddress Address of the contract
     */
    event DelegateRoleRevoked(address indexed contractAddress);

    /* ERRORS */

    /// @dev Thrown when a payment token is not configured
    error PaymentNotConfigured(address token);

    /// @dev Thrown when an invalid token address is provided
    error InvalidTokenAddress();

    /// @dev Thrown when an invalid role is provided
    error InvalidRole(bytes32 role);

    /// @dev Thrown when an invalid contract address is provided
    error InvalidContract(address contractAddress);

    /**
     * @dev Initializes the RolesBase contract
     * @param defaultAdmin Address of the default admin
     */
    function __RolesBase_init(address defaultAdmin) internal onlyInitializing {
        if (defaultAdmin == address(0)) revert InvalidContract(defaultAdmin);

        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _addresses[DEFAULT_ADMIN_ROLE] = defaultAdmin;
    }

    /* PAYMENT CONFIGURATION */

    /**
     * @notice Configures a payment token
     * @param token Address of the token
     * @param decimals Number of decimals for the token
     */
    function _setPayment(address token, uint8 decimals) internal {
        if (token == address(0)) revert InvalidTokenAddress();

        _payments[token] = Payment({ decimals: decimals, isConfigured: true });

        emit PaymentSet(token, decimals);
    }

    /**
     * @notice Sets the default fiat token
     * @param token Address of the token
     */
    function _setDefaultFiatToken(address token) internal {
        if (!_payments[token].isConfigured) revert PaymentNotConfigured(token);
        _defaultFiatToken = token;
        emit DefaultFiatTokenSet(token);
    }

    /* ROLE MANAGEMENT */

    /**
     * @notice Grants delegation rights to a contract
     * @param contractAddress Address of the contract
     */
    function _grantDelegateRole(address contractAddress) internal {
        if (contractAddress == address(0)) revert InvalidContract(contractAddress);
        _delegated[contractAddress] = true;
        emit DelegateRoleGranted(contractAddress);
    }

    /**
     * @notice Revokes delegation rights from a contract
     * @param contractAddress Address of the contract
     */
    function _revokeDelegateRole(address contractAddress) internal {
        if (contractAddress == address(0)) revert InvalidContract(contractAddress);
        _delegated[contractAddress] = false;
        emit DelegateRoleRevoked(contractAddress);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Gets the number of decimals for a token
     * @param token Address of the token
     * @return Number of decimals
     */
    function _getTokenDecimals(address token) internal view returns (uint8) {
        if (!_payments[token].isConfigured) revert PaymentNotConfigured(token);
        return _payments[token].decimals;
    }

    /**
     * @notice Gets the default fiat payment token address
     * @return Address of the token
     */
    function _getDefaultFiatPayment() internal view returns (address) {
        return _defaultFiatToken;
    }

    /**
     * @notice Gets the address assigned to a role
     * @param role Role identifier
     * @return Address assigned to the role
     */
    function _getRoleAddress(bytes32 role) internal view returns (address) {
        return _addresses[role];
    }

    /**
     * @notice Checks if a token is configured for payments
     * @param token Address of the token
     * @return True if the token is configured
     */
    function _hasPaymentRole(address token) internal view returns (bool) {
        return _payments[token].isConfigured;
    }

    /**
     * @notice Checks if a contract has delegation rights
     * @param contractAddress Address of the contract
     * @return True if the contract is delegated
     */
    function _hasDelegateRole(
        address contractAddress
    ) internal view returns (bool) {
        return _delegated[contractAddress];
    }
}