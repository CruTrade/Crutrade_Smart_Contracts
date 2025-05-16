// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import './ModifiersBase.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';

/**
 * @title WhitelistBase
 * @notice Abstract base contract for managing whitelisted addresses
 * @dev Provides functionality for adding and removing addresses from a whitelist
 * @author Crutrade Team
 */
abstract contract WhitelistBase is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ModifiersBase
{
    /* STORAGE */

    /// @dev Maps addresses to their whitelist status
    mapping(address => bool) internal _whitelisted;

    /* EVENTS */

    /**
     * @dev Emitted when addresses are added to the whitelist
     * @param wallets Addresses added to the whitelist
     */
    event Add(address[] wallets);

    /**
     * @dev Emitted when addresses are removed from the whitelist
     * @param wallets Addresses removed from the whitelist
     */
    event Remove(address[] wallets);

    /**
     * @dev Initializes the WhitelistBase contract
     * @param _roles Address of the roles contract
     */
    function __WhitelistBase_init(address _roles) internal onlyInitializing {
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ModifiersBase_init(_roles);
    }

    /* WHITELIST MANAGEMENT */

    /**
     * @notice Adds multiple addresses to the whitelist
     * @param wallets Addresses to add to the whitelist
     */
    function _addToWhitelist(address[] calldata wallets) internal {
        uint256 length = wallets.length;
        for (uint256 i; i < length; i++) {
            address wallet = wallets[i];
            _whitelisted[wallet] = true;
        }
        emit Add(wallets);
    }

    /**
     * @notice Removes multiple addresses from the whitelist
     * @param wallets Addresses to remove from the whitelist
     */
    function _removeFromWhitelist(address[] calldata wallets) internal {
        uint256 length = wallets.length;
        for (uint256 i; i < length; i++) {
            address wallet = wallets[i];
            _whitelisted[wallet] = false;
        }
        emit Remove(wallets);
    }

    /**
     * @notice Checks if an address is in the whitelist
     * @param wallet Address to check
     * @return True if the address is whitelisted
     */
    function _isWhitelisted(address wallet) internal view override returns (bool) {
        return _whitelisted[wallet];
    }
}