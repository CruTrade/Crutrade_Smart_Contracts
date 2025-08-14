// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import './abstracts/ModifiersBase.sol';

/**
 * @title USDCApprovalProxy
 * @notice Registry contract for monitoring USDC approvals
 * @dev Records and emits events when users approve USDC for our contracts
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract USDCApprovalProxy is ModifiersBase {
  /* CONSTANTS */
  
  /// @notice Domain name for EIP-712 signatures
  string internal constant USDC_PROXY_DOMAIN_NAME = "USDCApprovalProxy";
  
  /// @notice Domain version for EIP-712 signatures
  string internal constant DEFAULT_DOMAIN_VERSION = "1";

  /* STATE VARIABLES */

  /// @notice Address of the USDC token contract
  address public usdcToken;

  /// @notice Address of the main Payments contract that users approve
  address public paymentsContract;

  /* EVENTS */

  /**
   * @notice Emitted when a user approves USDC through the proxy
   * @param user Address of the user making the approval
   * @param spender Address being approved to spend tokens
   * @param amount Amount approved
   * @param success Whether the approval was successful
   */
  event USDCApprovalForwarded(
    address indexed user,
    address indexed spender, 
    uint256 amount,
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

  /// @notice Thrown when trying to set zero address
  error ZeroAddress();

  /// @notice Thrown when USDC token is not set
  error USDCTokenNotSet();

  /// @notice Thrown when payments contract is not set
  error PaymentsContractNotSet();

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

  /* MONITORING FUNCTIONS */

  /**
   * @notice Records and verifies a user's USDC approval, emitting monitoring event
   * @param spender Address that was approved for spending
   * @param amount Amount that was approved
   * @dev Call this after making a direct USDC approval to register it for monitoring
   */
  function recordUSDCApproval(address spender, uint256 amount) external {
    if (usdcToken == address(0)) revert USDCTokenNotSet();
    
    // Verify that the approval actually exists
    uint256 currentAllowance = IERC20(usdcToken).allowance(msg.sender, spender);
    require(currentAllowance >= amount, "Approval not found or insufficient");
    
    // Emit monitoring event
    emit USDCApprovalForwarded(msg.sender, spender, amount, true);
  }

  /**
   * @notice Records approval for the payments contract after user makes direct USDC approval
   * @param amount Amount that was approved
   * @dev Call this after you've approved USDC for the payments contract directly
   */
  function recordPaymentsApproval(uint256 amount) external {
    if (paymentsContract == address(0)) revert PaymentsContractNotSet();
    recordUSDCApproval(paymentsContract, amount);
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
}