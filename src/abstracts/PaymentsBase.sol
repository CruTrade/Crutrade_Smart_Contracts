// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './ModifiersBase.sol';
import '../interfaces/IPayments.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';

/**
 * @title PaymentsBase
 * @notice Abstract base contract for payment processing with fee management
 * @dev Implements core functionality for fee calculation and payment splitting
 * @author Crutrade Team
 */
abstract contract PaymentsBase is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ModifiersBase,
    IPayments
{
    using SafeERC20 for IERC20;

    /* CONSTANTS */

    /// @dev Basis points for fee calculations (10000 = 100%)
    uint256 internal constant BPS = 10000;

    /* STORAGE */

    /// @dev Percentage fee applied to fiat transactions
    uint256 internal _fiatFeePercentage;

    /// @dev Array of fee configurations
    Fee[] internal _fees;

    /// @dev Maps fee names to their indices in the _fees array (1-based index for gas optimization)
    mapping(bytes32 => uint256) internal _feeIndices;

    /// @dev Maps operations to their service fees
    mapping(bytes32 => uint256) internal _serviceFees;

    /// @dev Maps membership IDs to their fee percentages
    mapping(uint256 => MembershipFees) internal _membershipFees;

    /* EVENTS */

    /**
     * @dev Emitted when a new fee is added
     * @param name Name of the fee
     * @param percentage Percentage of the fee
     * @param wallet Wallet to receive the fee
     */
    event FeeAdded(bytes32 indexed name, uint256 percentage, address wallet);

    /**
     * @dev Emitted when a fee is removed
     * @param name Name of the fee
     */
    event FeeRemoved(bytes32 indexed name);

    /**
     * @dev Emitted when a fee is updated
     * @param name Name of the fee
     * @param percentage New percentage of the fee
     * @param wallet New wallet to receive the fee
     */
    event FeeUpdated(bytes32 indexed name, uint256 percentage, address wallet);

    /**
     * @dev Emitted when fees are processed
     * @param transactionId ID of the transaction
     * @param fees Details of the fees processed
     */
    event FeesProcessed(uint256 indexed transactionId, TransactionFees fees);

    /**
     * @dev Emitted when a payment is processed
     * @param from Address sending the payment
     * @param to Address receiving the payment
     * @param amount Amount of the payment
     */
    event PaymentProcessed(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Emitted when tokens are sent
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount sent
     */
    event Send(address from, address to, uint amount);

    /**
     * @dev Emitted when the fiat fee percentage is updated
     * @param oldPercentage Previous percentage
     * @param newPercentage New percentage
     */
    event FiatFeePercentageUpdated(uint256 oldPercentage, uint256 newPercentage);

    /**
     * @dev Emitted when membership fees are updated
     * @param membershipId Membership ID
     * @param sellerFee Seller fee percentage
     * @param buyerFee Buyer fee percentage
     */
    event MembershipFeesUpdated(uint256 indexed membershipId, uint256 sellerFee, uint256 buyerFee);

    /* ERRORS */

    /// @dev Thrown when a fee is not found
    error FeeNotFound(bytes32 name);

    /// @dev Thrown when attempting to add a duplicate fee
    error DuplicateFee(bytes32 name);

    /// @dev Thrown when the total percentage exceeds the limit
    error TotalPercentageExceedsLimit();

    /// @dev Thrown when an invalid percentage is provided
    error InvalidPercentage(uint256 percentage);

    /// @dev Thrown when a transfer fails
    error TransferFailed();

    /// @dev Thrown when the provided payment amount is insufficient
    error InsufficientPayment(uint256 required, uint256 provided);

    /// @dev Thrown when an invalid payment token is used
    error InvalidPaymentToken(address token);

    /// @dev Thrown when a payment operation fails
    error PaymentFailed(address token, uint256 amount);

    /// @dev Thrown when an invalid token address is provided
    error InvalidTokenAddress();

    /**
     * @dev Initializes the base payment contract
     */
    function __PaymentBase_init() internal onlyInitializing {
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /* FEE MANAGEMENT FUNCTIONS */

    /**
     * @notice Adds a new fee
     * @param name Name of the fee
     * @param percentage Percentage of the fee (in basis points)
     * @param wallet Wallet to receive the fee
     */
    function _addFee(
        bytes32 name,
        uint256 percentage,
        address wallet
    ) internal virtual {
        if (percentage > BPS) revert InvalidPercentage(percentage);
        if (_feeIndices[name] != 0) revert DuplicateFee(name);
        if (wallet == address(0)) revert ZeroAddress();

        _fees.push(Fee(name, percentage, wallet));
        _feeIndices[name] = _fees.length;

        if (!_checkTotalPercentage()) revert TotalPercentageExceedsLimit();

        emit FeeAdded(name, percentage, wallet);
    }

    /**
     * @notice Removes a fee
     * @param name Name of the fee to remove
     */
    function _removeFee(bytes32 name) internal virtual {
        uint256 index = _feeIndices[name];
        if (index == 0) revert FeeNotFound(name);

        uint256 lastIndex = _fees.length - 1;
        // If not the last element, swap with the last element to maintain array density
        if (index - 1 != lastIndex) {
            Fee memory lastFee = _fees[lastIndex];
            _fees[index - 1] = lastFee;
            _feeIndices[lastFee.name] = index;
        }

        _fees.pop();
        delete _feeIndices[name];

        emit FeeRemoved(name);
    }

    /**
     * @notice Updates an existing fee
     * @param name Name of the fee
     * @param percentage New percentage of the fee (in basis points)
     * @param wallet New wallet to receive the fee
     */
    function _updateFee(
        bytes32 name,
        uint256 percentage,
        address wallet
    ) internal virtual {
        if (percentage > BPS) revert InvalidPercentage(percentage);
        if (wallet == address(0)) revert ZeroAddress();

        uint256 index = _feeIndices[name];
        if (index == 0) revert FeeNotFound(name);

        _fees[index - 1] = Fee(name, percentage, wallet);

        if (!_checkTotalPercentage()) revert TotalPercentageExceedsLimit();

        emit FeeUpdated(name, percentage, wallet);
    }

    /**
     * @notice Sets the fiat fee percentage
     * @param newPercentage New percentage (in basis points)
     */
    function _setFiatFeePercentage(uint256 newPercentage) internal virtual {
        if (newPercentage > BPS) revert InvalidPercentage(newPercentage);
        uint256 oldPercentage = _fiatFeePercentage;
        _fiatFeePercentage = newPercentage;
        emit FiatFeePercentageUpdated(oldPercentage, newPercentage);
    }

    /**
     * @notice Sets the service fee for an operation
     * @param operation Type of operation
     * @param fee New fee amount
     */
    function _setServiceFee(bytes32 operation, uint256 fee) internal virtual {
        _serviceFees[operation] = fee;
    }

    /**
     * @notice Sets fee percentages for a membership tier
     * @param membershipId Membership ID
     * @param sellerFee Fee percentage for sellers
     * @param buyerFee Fee percentage for buyers
     */
    function _setMembershipFees(
        uint256 membershipId,
        uint256 sellerFee,
        uint256 buyerFee
    ) internal virtual {
        if (sellerFee > BPS) revert InvalidPercentage(sellerFee);
        if (buyerFee > BPS) revert InvalidPercentage(buyerFee);

        _membershipFees[membershipId] = MembershipFees({
            sellerFee: sellerFee,
            buyerFee: buyerFee
        });

        emit MembershipFeesUpdated(membershipId, sellerFee, buyerFee);
    }

    /* PAYMENT SPLITTING FUNCTIONS */

    /**
     * @notice Calculates service fee for an operation
     * @param operation Operation type
     * @param isFiat Whether the payment is in fiat
     * @return ServiceFee structure with fee details
     */
    function _calculateServiceFee(
        bytes32 operation,
        bool isFiat
    ) internal view virtual returns (ServiceFee memory) {
        ServiceFee memory serviceFee = ServiceFee({
            operation: operation,
            serviceFees: _serviceFees[operation],
            fiatFees: 0
        });

        if (isFiat && serviceFee.serviceFees > 0) {
            serviceFee.fiatFees = (serviceFee.serviceFees * _fiatFeePercentage) / BPS;
        }

        return serviceFee;
    }

    /**
     * @notice Calculates percentage-based fees
     * @param amount Base amount
     * @param fromPercentage Percentage for sender
     * @param toPercentage Percentage for receiver
     * @return fromFee Fee for the sender
     * @return toFee Fee for the receiver
     */
    function _calculatePercentageFees(
        uint256 amount,
        uint256 fromPercentage,
        uint256 toPercentage
    ) internal pure virtual returns (uint256 fromFee, uint256 toFee) {
        // Gas optimization with unchecked for simple calculations that cannot overflow with Solidity 0.8.x
        unchecked {
            fromFee = (amount * fromPercentage) / BPS;
            toFee = (amount * toPercentage) / BPS;
        }
        return (fromFee, toFee);
    }

    /**
     * @notice Processes fee transfers
     * @param erc20 Token address
     * @param from Address sending the payment
     * @param to Address receiving the payment
     * @param amount Total amount
     * @param fees TransactionFees structure with fee details
     */
    function _processTransfers(
        address erc20,
        address from,
        address to,
        uint256 amount,
        TransactionFees memory fees
    ) internal virtual {
        // Transfer to recipient (net amount after fees)
        uint256 toAmount = amount - fees.toFee;
        IERC20(erc20).safeTransferFrom(from, to, toAmount);

        // Transfer fees to recipients
        uint256 totalFees = fees.fromFee + fees.toFee;
        uint256 feesLength = fees.fees.length;

        // Process fee distribution
        for (uint256 i = 0; i < feesLength; i++) {
            Fee memory fee = fees.fees[i];
            uint256 feeAmount = (totalFees * fee.percentage) / BPS;

            if (feeAmount > 0) {
                IERC20(erc20).safeTransferFrom(from, fee.wallet, feeAmount);
            }
        }

        // Process service fees
        _processServiceFeeTransfers(erc20, from, fees.serviceFee);
    }

    /**
     * @notice Processes service fee transfers
     * @param erc20 Token address
     * @param from Address sending the payment
     * @param serviceFee Service fee details
     */
    function _processServiceFeeTransfers(
        address erc20,
        address from,
        ServiceFee memory serviceFee
    ) internal virtual {
        if (serviceFee.serviceFees == 0 && serviceFee.fiatFees == 0) {
            return; // Skip if no fees
        }

        // Gas optimization: cache treasury address
        address treasury = _fees[0].wallet;

        // Process service fees if applicable
        if (serviceFee.serviceFees > 0) {
            IERC20(erc20).safeTransferFrom(from, treasury, serviceFee.serviceFees);
        }

        // Process fiat fees if applicable
        if (serviceFee.fiatFees > 0) {
            IERC20(erc20).safeTransferFrom(from, treasury, serviceFee.fiatFees);
        }
    }

    /**
     * @notice Checks if the total percentage of fees is valid
     * @return True if total is within limits
     */
    function _checkTotalPercentage() internal view virtual returns (bool) {
        uint256 total;
        uint256 feesLength = _fees.length;

        for (uint256 i = 0; i < feesLength; i++) {
            total += _fees[i].percentage;
        }

        return total <= BPS;
    }
}