// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './ModifiersBase.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';

/**
 * @title MembershipsBase
 * @notice Abstract base contract for managing memberships
 * @dev Provides functionality for assigning and tracking membership IDs
 * @author Crutrade Team
 */
abstract contract MembershipsBase is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ModifiersBase
{
    /* STORAGE */

    /// @dev Maps user addresses to their membership IDs
    mapping(address => uint256) internal _memberships;

    /* EVENTS */

    /**
     * @dev Emitted when members join with a membership ID
     * @param members Addresses of the members
     * @param membershipId Membership ID assigned to the members
     */
    event Joined(address[] members, uint256 indexed membershipId);

    /**
     * @dev Emitted when a membership is updated
     * @param member Address of the member
     * @param oldId Previous membership ID
     * @param newId New membership ID
     */
    event MembershipUpdated(address indexed member, uint256 oldId, uint256 newId);

    /**
     * @dev Emitted when a membership is revoked
     * @param member Address of the member
     * @param membershipId ID of the revoked membership
     */
    event MembershipRevoked(address indexed member, uint256 membershipId);

    /* ERRORS */

    /// @dev Thrown when an invalid membership ID is provided
    error InvalidMembership(uint256 membershipId);

    /// @dev Thrown when a membership is not found for an address
    error MembershipNotFound(address member);

    /// @dev Thrown when an invalid membership operation is attempted
    error InvalidMembershipOperation();

    /**
     * @dev Initializes the MembershipsBase contract
     * @param _roles Address of the roles contract
     */
    function __MembershipsBase_init(address _roles) internal onlyInitializing {
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ModifiersBase_init(_roles, MEMBERSHIPS_DOMAIN_NAME, DEFAULT_DOMAIN_VERSION);
    }

    /* MEMBERSHIP MANAGEMENT */

    /**
     * @notice Sets membership ID for a single member
     * @param member Address of the member
     * @param id Membership ID to assign
     */
    function _setMembership(address member, uint256 id) internal {
        uint256 oldId = _memberships[member];
        _memberships[member] = id;

        if (oldId != 0 && oldId != id) {
            emit MembershipUpdated(member, oldId, id);
        } else {
            address[] memory members = new address[](1);
            members[0] = member;
            emit Joined(members, id);
        }
    }

    /**
     * @notice Sets membership ID for multiple members
     * @param members Array of member addresses
     * @param id Membership ID to assign
     */
    function _setMemberships(address[] calldata members, uint256 id) internal {
        uint256 length = members.length;
        address[] memory newMembers = new address[](length);
        uint256 newMembersCount = 0;
        for (uint256 i = 0; i < length; i++) {
            uint256 oldId = _memberships[members[i]];
            _memberships[members[i]] = id;
            if (oldId != 0 && oldId != id) {
                emit MembershipUpdated(members[i], oldId, id);
            } else if (oldId == 0) {
                newMembers[newMembersCount] = members[i];
                newMembersCount++;
            }
        }
        if (newMembersCount > 0) {
            // Create a properly sized array for the event
            address[] memory finalNewMembers = new address[](newMembersCount);
            for (uint256 i = 0; i < newMembersCount; i++) {
                finalNewMembers[i] = newMembers[i];
            }
            emit Joined(finalNewMembers, id);
        }
    }

    /**
     * @notice Revokes membership for a member
     * @param member Address of the member
     */
    function _revokeMembership(address member) internal {
        uint256 id = _memberships[member];
        if (id == 0) revert MembershipNotFound(member);

        delete _memberships[member];
        emit MembershipRevoked(member, id);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Retrieves the current membership ID for a given account
     * @param account Address of the account
     * @return Membership ID for the account
     */
    function _getMembership(address account) internal view returns (uint256) {
        return _memberships[account];
    }

    /**
     * @notice Retrieves membership IDs for multiple accounts
     * @param accounts Array of account addresses
     * @return Array of membership IDs corresponding to the provided accounts
     */
    function _getMemberships(
        address[] calldata accounts
    ) internal view returns (uint256[] memory) {
        uint256 length = accounts.length;
        uint256[] memory memberships = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            memberships[i] = _memberships[accounts[i]];
        }

        return memberships;
    }
}