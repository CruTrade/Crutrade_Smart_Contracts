// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import '@openzeppelin/contracts/access/IAccessControl.sol';

/**
 * @title IRoles
 * @notice Interface for role and permission management in the Crutrade ecosystem
 * @dev Extends standard AccessControl with additional role and contract management methods
 * @author Crutrade Team
 */
interface IRoles is IAccessControl {
    /**
     * @notice Checks if a contract has delegate role
     * @param _contract Contract address to check
     * @return Boolean indicating delegate status
     */
    function hasDelegateRole(address _contract) external view returns (bool);

    /**
     * @notice Checks if a payment method is allowed
     * @param _contract Payment contract address
     * @return Boolean indicating payment role status
     */
    function hasPaymentRole(address _contract) external view returns (bool);

    /**
     * @notice Retrieves the address assigned to a specific role
     * @param role Role identifier
     * @return Address assigned to the role
     */
    function getRoleAddress(bytes32 role) external view returns (address);

    /**
     * @notice Retrieves the default fiat payment token address
     * @return Address of the default fiat payment token
     */
    function getDefaultFiatPayment() external view returns (address);
}