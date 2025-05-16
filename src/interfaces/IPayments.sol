// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPayments
 * @notice Interface for payment operations in the Crutrade ecosystem
 * @dev Defines structures and functions for payment and fee operations
 * @author Crutrade Team
 */

/* TYPES */

/**
 * @dev Structure for fee configuration
 * @param name Name of the fee
 * @param percentage Percentage of the fee (in basis points)
 * @param wallet Wallet address to receive the fee
 */
struct Fee {
    bytes32 name;
    uint256 percentage;
    address wallet;
}

/**
 * @dev Structure for service fee
 * @param operation Type of operation
 * @param serviceFees Amount of service fees
 * @param fiatFees Amount of fiat fees
 */
struct ServiceFee {
    bytes32 operation;
    uint256 serviceFees;
    uint256 fiatFees;
}

/**
 * @dev Structure for transaction fees
 * @param fromFee Fee for the sender
 * @param toFee Fee for the receiver
 * @param serviceFee Service fee details
 * @param fees Array of fee configurations
 */
struct TransactionFees {
    uint256 fromFee;
    uint256 toFee;
    ServiceFee serviceFee;
    Fee[] fees;
}

/**
 * @notice Interface for payment operations
 */
interface IPayments {

    /* FUNCTIONS */
    
    /**
     * @notice Calculates and processes transaction fees
     * @param erc20 Token address
     * @param transactionId Transaction ID
     * @param from Address sending the payment
     * @param to Address receiving the payment
     * @param amount Transaction amount
     * @return TransactionFees structure with fee details
     */
    function splitFees(
        address erc20,
        uint256 transactionId,
        address from,
        address to,
        uint256 amount
    ) external returns (TransactionFees memory);

    /**
     * @notice Calculates and processes service fee for an operation
     * @param operation Type of operation
     * @param wallet Wallet address
     * @param erc20 Token address
     * @return ServiceFee structure with fee details
     */
    function splitServiceFee(
        bytes32 operation,
        address wallet,
        address erc20
    ) external returns (ServiceFee memory);
}