// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './abstracts/MembershipsBase.sol';
import './interfaces/IMemberships.sol';

/**
 * @title Memberships
 * @notice Manages partner memberships in the Crutrade ecosystem
 * @dev Assigns and tracks membership IDs for users with associated benefits
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Memberships is MembershipsBase, IMemberships {
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
   */
  function initialize(address _roles) public initializer {
    __MembershipsBase_init(_roles);
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
   * @notice Updates the roles contract address
   * @param _roles Address of the new roles contract
   * @dev Can only be called by an account with the OWNER role
   */
  function setRoles(address _roles) external onlyRole(OWNER) {
    if (_roles == address(0)) revert ZeroAddress();
    roles = IRoles(_roles);
    emit RolesSet(_roles);
  }

  /* PUBLIC FUNCTIONS */

  /**
   * @notice Sets the membership ID for multiple members
   * @param members Array of member addresses
   * @param id Membership ID to assign
   * @dev Can only be called by an account with the OPERATIONAL role
   */
  function setMemberships(
    address[] calldata members,
    uint256 id
  ) external whenNotPaused onlyRole(OPERATIONAL) {
    if (members.length == 0) revert InvalidMembershipOperation();
    _setMemberships(members, id);
  }

  /**
   * @notice Revokes membership for a member
   * @param member Address of the member
   * @dev Can only be called by an account with the OPERATIONAL role
   */
  function revokeMembership(
    address member
  ) external whenNotPaused onlyRole(OPERATIONAL) {
    if (member == address(0)) revert ZeroAddress();
    _revokeMembership(member);
  }

  /* VIEW FUNCTIONS */

  /**
   * @notice Retrieves the current membership ID for a given account
   * @param account Address of the account
   * @return Membership ID for the account
   */
  function getMembership(
    address account
  ) external view override returns (uint256) {
    return _getMembership(account);
  }

  /**
   * @notice Retrieves membership IDs for multiple accounts
   * @param accounts Array of account addresses
   * @return Array of membership IDs corresponding to the provided accounts
   */
  function getMemberships(
    address[] calldata accounts
  ) external view override returns (uint256[] memory) {
    return _getMemberships(accounts);
  }

  /**
   * @dev Authorizes an upgrade to a new implementation
   * @param newImplementation Address of the new implementation
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyRole(UPGRADER) checkAddressZero(newImplementation) {}
}
