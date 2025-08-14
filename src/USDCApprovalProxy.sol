// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import './abstracts/ModifiersBase.sol';

/**
 * @title USDCApprovalProxy
 * @notice Proxy contract for USDC permit operations
 * @dev Processes USDC permits on behalf of users using their signatures
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract USDCApprovalProxy is ModifiersBase, UUPSUpgradeable {
  /* CONSTANTS */
  
  /// @notice Domain name for EIP-712 signatures
  string internal constant USDC_PROXY_DOMAIN_NAME = "USDCApprovalProxy";

  /* STATE VARIABLES */

  /// @notice Address of the USDC token contract
  address public usdcToken;

  /// @notice Address of the main Payments contract that users approve
  address public paymentsContract;

  /* EVENTS */



  /**
   * @notice Emitted when a permit is processed through the proxy
   * @param owner Address of the token owner
   * @param spender Address being approved to spend tokens
   * @param value Amount approved
   * @param success Whether the permit was successful
   */
  event USDCPermitForwarded(
    address indexed owner,
    address indexed spender,
    uint256 value,
    bool success
  );

  /**
   * @notice Emitted when USDC token address is updated
   * @param oldToken Previous USDC token address
   * @param newToken New USDC token address
   */
  event USDCTokenUpdated(address indexed oldToken, address indexed newToken);

  /**
   * @notice Emitted when payments contract address is updated
   * @param oldPayments Previous payments contract address
   * @param newPayments New payments contract address
   */
  event PaymentsContractUpdated(address indexed oldPayments, address indexed newPayments);

  /* ERRORS */

  /// @notice Thrown when USDC token is not set
  error USDCTokenNotSet();

  /// @notice Thrown when payments contract is not set
  error PaymentsContractNotSet();

  /// @notice Thrown when permit deadline has expired
  error PermitExpired();

  /// @notice Thrown when permit signature is invalid
  error InvalidPermitSignature();

  /* INITIALIZATION */

  /**
   * @dev Prevents initialization of the implementation contract
   */
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initializes the proxy contract
   * @param _roles Address of the roles contract
   * @param _usdcToken Address of the USDC token contract
   * @param _paymentsContract Address of the payments contract
   */
  function initialize(
    address _roles,
    address _usdcToken,
    address _paymentsContract
  ) public initializer {
    if (_usdcToken == address(0)) revert ZeroAddress();
    if (_paymentsContract == address(0)) revert ZeroAddress();

    __ModifiersBase_init(_roles, USDC_PROXY_DOMAIN_NAME, DEFAULT_DOMAIN_VERSION);
    __UUPSUpgradeable_init();
    
    usdcToken = _usdcToken;
    paymentsContract = _paymentsContract;
  }

  /* CONFIGURATION FUNCTIONS */

  /**
   * @notice Updates the USDC token address
   * @param _newUsdcToken New USDC token address
   * @dev Can only be called by an account with the OWNER role
   */
  function setUSDCToken(address _newUsdcToken) external onlyRole(OWNER) {
    if (_newUsdcToken == address(0)) revert ZeroAddress();
    
    address oldToken = usdcToken;
    usdcToken = _newUsdcToken;
    
    emit USDCTokenUpdated(oldToken, _newUsdcToken);
  }

  /**
   * @notice Updates the payments contract address
   * @param _newPaymentsContract New payments contract address
   * @dev Can only be called by an account with the OWNER role
   */
  function setPaymentsContract(address _newPaymentsContract) external onlyRole(OWNER) {
    if (_newPaymentsContract == address(0)) revert ZeroAddress();
    
    address oldPayments = paymentsContract;
    paymentsContract = _newPaymentsContract;
    
    emit PaymentsContractUpdated(oldPayments, _newPaymentsContract);
  }

  /* CORE PERMIT FUNCTIONS */

  /**
   * @notice Processes USDC permit through the proxy
   * @param owner Address of the token owner
   * @param spender Address to approve for spending
   * @param value Amount to approve
   * @param deadline Deadline for the permit
   * @param v Signature v component
   * @param r Signature r component
   * @param s Signature s component
   * @dev Actually calls USDC.permit() to increase allowance
   */
  function permitUSDC(
    address owner,
    address spender, 
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    if (usdcToken == address(0)) revert USDCTokenNotSet();
    if (block.timestamp > deadline) revert PermitExpired();
    
    // Actually call USDC.permit() - this increases allowance
    IERC20Permit(usdcToken).permit(owner, spender, value, deadline, v, r, s);
    
    // Emit monitoring event
    emit USDCPermitForwarded(owner, spender, value, true);
  }

  /* CONVENIENCE FUNCTIONS FOR PAYMENTS */

  /**
   * @notice Processes USDC permit for the payments contract
   * @param owner Address of the token owner
   * @param value Amount to approve
   * @param deadline Deadline for the permit
   * @param v Signature v component
   * @param r Signature r component
   * @param s Signature s component
   * @dev Convenience function that calls permitUSDC with payments contract
   */
  function permitForPayments(
    address owner,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    if (paymentsContract == address(0)) revert PaymentsContractNotSet();
    this.permitUSDC(owner, paymentsContract, value, deadline, v, r, s);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Gets the current allowance for a spender
   * @param owner Owner of the tokens
   * @param spender Address approved to spend
   * @return allowance Current allowance amount
   */
  function allowance(address owner, address spender) external view returns (uint256) {
    if (usdcToken == address(0)) revert USDCTokenNotSet();
    return IERC20(usdcToken).allowance(owner, spender);
  }

  /**
   * @notice Gets the current allowance for the payments contract
   * @param owner Owner of the tokens
   * @return allowance Current allowance amount for payments contract
   */
  function paymentsAllowance(address owner) external view returns (uint256) {
    if (paymentsContract == address(0)) revert PaymentsContractNotSet();
    return this.allowance(owner, paymentsContract);
  }

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}
}