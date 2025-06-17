// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/PaymentsBase.sol';
import './interfaces/IMemberships.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title Payments
 * @notice Manages payment operations in the Crutrade ecosystem
 * @dev Handles fee calculations, fee splitting, and payment processing with membership levels
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Payments is PaymentsBase {
  using SafeERC20 for IERC20;

  /* CONSTANTS */

  /// @dev Role identifier for membership contract
  bytes32 internal constant MEMBERSHIPS = keccak256('MEMBERSHIPS');

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
   * @dev Sets up initial fee structure and configuration
   */
  function initialize(address _roles) public initializer {
    __PaymentBase_init();
    __ModifiersBase_init(_roles);

    // Initialize fee percentages and service fees
    _fiatFeePercentage = 300; // 3%

    // Initialize treasury fee (100%)
    _fees.push(
      Fee(TREASURY, 10000, 0xd6ef21b20D3Bb4012808695c96A60f6032e14FB6)
    );
    _feeIndices[TREASURY] = _fees.length;

    // Initialize membership fee structure
    _initializeFees();
  }

  /**
   * @dev Initializes the fee structure for different membership levels
   */
  function _initializeFees() private {
    // Set fee percentages for first 2 membership tiers
    _setMembershipFees(0, 600, 400); // 6% seller, 4% buyer
    _setMembershipFees(1, 100, 100); // 1% seller, 1% buyer
  }

  /* FEE MANAGEMENT FUNCTIONS */

  /**
   * @notice Adds a new fee
   * @param name Name of the fee
   * @param percentage Percentage of the fee (in basis points)
   * @param wallet Wallet to receive the fee
   * @dev Can only be called by an account with the OWNER role
   */
  function addFee(
    bytes32 name,
    uint256 percentage,
    address wallet
  ) external onlyRole(OWNER) {
    _addFee(name, percentage, wallet);
  }

  /**
   * @notice Removes a fee
   * @param name Name of the fee to remove
   * @dev Can only be called by an account with the OWNER role
   */
  function removeFee(bytes32 name) external onlyRole(OWNER) {
    _removeFee(name);
  }

  /**
   * @notice Updates an existing fee
   * @param name Name of the fee
   * @param percentage New percentage of the fee (in basis points)
   * @param wallet New wallet to receive the fee
   * @dev Can only be called by an account with the OWNER role
   */
  function updateFee(
    bytes32 name,
    uint256 percentage,
    address wallet
  ) external onlyRole(OWNER) {
    _updateFee(name, percentage, wallet);
  }

  /**
   * @notice Sets the fiat fee percentage
   * @param newPercentage New percentage (in basis points)
   * @dev Can only be called by an account with the OWNER role
   */
  function setFiatFeePercentage(
    uint256 newPercentage
  ) external onlyRole(OWNER) {
    _setFiatFeePercentage(newPercentage);
  }

  /**
   * @notice Sets the service fee for an operation
   * @param operation Type of operation
   * @param fee New fee amount
   * @dev Can only be called by an account with the OWNER role
   */
  function setServiceFee(
    bytes32 operation,
    uint256 fee
  ) external onlyRole(OWNER) {
    _setServiceFee(operation, fee);
  }

  /**
   * @notice Sets fee percentages for a membership tier
   * @param membershipId Membership ID
   * @param sellerFee Fee percentage for sellers
   * @param buyerFee Fee percentage for buyers
   * @dev Can only be called by an account with the OWNER role
   */
  function setMembershipFees(
    uint256 membershipId,
    uint256 sellerFee,
    uint256 buyerFee
  ) external onlyRole(OWNER) {
    _setMembershipFees(membershipId, sellerFee, buyerFee);
  }

  /* PAYMENT OPERATIONS */

  /**
   * @notice Sends tokens from one address to another
   * @param hash Hash of the transaction data
   * @param signature Sender's signature
   * @param erc20 Token address
   * @param from Address sending the tokens
   * @param to Address receiving the tokens
   * @param amount Amount to send
   * @dev Can only be called by an account with the OPERATIONAL role
   */
  function send(
    bytes32 hash,
    bytes calldata signature,
    address erc20,
    address from,
    address to,
    uint amount
  )
    external
    onlyRole(OPERATIONAL)
    onlyWhitelisted(from)
    checkSignature(from, hash, signature)
  {
    if (erc20 == address(0)) revert InvalidTokenAddress();
    if (from == address(0) || to == address(0)) revert ZeroAddress();

    // Using SafeERC20 to handle tokens that don't return boolean values
    IERC20(erc20).safeTransferFrom(from, to, amount);

    emit Send(from, to, amount);
  }

  /* PAYMENT SPLITTING FUNCTIONS */

  /**
   * @notice Calculates and processes service fee for an operation
   * @param operation Type of operation
   * @param wallet Wallet address
   * @param erc20 Token address
   * @return ServiceFee structure with fee details
   * @dev Can only be called by contracts with delegation rights
   */
  function splitServiceFee(
    bytes32 operation,
    address wallet,
    address erc20
  )
    external
    override
    whenNotPaused
    onlyDelegatedRole
    onlyValidPayment(erc20)
    returns (ServiceFee memory)
  {
    bool isFiat = erc20 == address(0);
    address tokenAddress = isFiat ? roles.getDefaultFiatPayment() : erc20;
    address from = isFiat ? roles.getRoleAddress(FIAT) : wallet;

    // Calculate service fees
    ServiceFee memory serviceFee = _calculateServiceFee(operation, isFiat);

    // Process fee transfers
    _processServiceFeeTransfers(tokenAddress, from, serviceFee);

    return serviceFee;
  }

  /**
   * @notice Calculates and processes transaction fees
   * @param erc20 Token address
   * @param transactionId Transaction ID
   * @param from Address sending the payment
   * @param to Address receiving the payment
   * @param amount Transaction amount
   * @return TransactionFees structure with fee details
   * @dev Can only be called by contracts with delegation rights
   */
  function splitFees(
    address erc20,
    uint256 transactionId,
    address from,
    address to,
    uint256 amount
  )
    external
    override
    whenNotPaused
    onlyDelegatedRole
    onlyValidPayment(erc20)
    returns (TransactionFees memory)
  {
    bool isFiat = erc20 == address(0);
    address tokenAddress = isFiat ? roles.getDefaultFiatPayment() : erc20;
    address payer = isFiat ? roles.getRoleAddress(FIAT) : from;

    // Get membership information for fee calculation - gas optimization
    address[] memory users = new address[](2);
    users[0] = from;
    users[1] = to;

    // Get memberships from Memberships contract
    address membershipContract = roles.getRoleAddress(MEMBERSHIPS);
    uint256[] memory memberships = IMemberships(membershipContract)
      .getMemberships(users);

    // Get membership fees
    MembershipFees memory fromMembershipFees = _membershipFees[memberships[0]];
    MembershipFees memory toMembershipFees = _membershipFees[memberships[1]];

    // Calculate percentage-based fees
    (uint256 fromFee, uint256 toFee) = _calculatePercentageFees(
      amount,
      fromMembershipFees.sellerFee,
      toMembershipFees.buyerFee
    );

    // Create TransactionFees structure
    TransactionFees memory fees = TransactionFees({
      fromFee: fromFee,
      toFee: toFee,
      fees: new Fee[](_fees.length),
      serviceFee: ServiceFee({
        operation: bytes32(0),
        serviceFees: 0,
        fiatFees: 0
      })
    });

    // Copy all system fees to transaction fees
    for (uint i = 0; i < _fees.length; i++) {
      fees.fees[i] = _fees[i];
    }

    // Calculate fiat fees if applicable
    if (isFiat) {
      fees.serviceFee.fiatFees = (amount * _fiatFeePercentage) / BPS;
    }

    // Process transfers using checks-effects-interactions pattern
    _processTransfers(tokenAddress, payer, to, amount, fees);

    emit FeesProcessed(transactionId, fees);

    return fees;
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Gets all fees
   * @return Array of all fees
   */
  function getFees() external view returns (Fee[] memory) {
    return _fees;
  }

  /**
   * @notice Gets a specific fee by name
   * @param name Name of the fee
   * @return Fee details
   */
  function getFee(bytes32 name) external view returns (Fee memory) {
    uint256 index = _feeIndices[name];
    if (index == 0) revert FeeNotFound(name);
    return _fees[index - 1];
  }

  /**
   * @notice Gets the fee percentages for a membership tier
   * @param membershipId Membership ID
   * @return sellerFee Fee percentage for sellers
   * @return buyerFee Fee percentage for buyers
   */
  function getMembershipFees(
    uint256 membershipId
  ) external view returns (uint256 sellerFee, uint256 buyerFee) {
    MembershipFees memory fees = _membershipFees[membershipId];
    return (fees.sellerFee, fees.buyerFee);
  }

  /* ADMIN FUNCTIONS */

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

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   * @dev Can only be called by an account with the UPGRADER role
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}
}