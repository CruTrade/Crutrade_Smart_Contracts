// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./ModifiersBase.sol";
import "../interfaces/IGift.sol";
import "../interfaces/IWrappers.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title GiftBase
 * @notice Base abstract contract for gift operations
 * @dev Contains core business logic for signature-based NFT gifting
 * @author Crutrade Team
 */
abstract contract GiftBase is
    Initializable,
    PausableUpgradeable,
    ModifiersBase
{
    /* CONSTANTS */

    /// @notice Gift contract domain name
    string internal constant GIFT_DOMAIN_NAME = "Crutrade Gift";

    /// @notice Typehash for gift messages
    bytes32 internal constant GIFT_TYPEHASH = keccak256(
        "CrutradeGiftMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,uint256 wrapperId,address to)"
    );

    /* STORAGE */

    /// @dev Whether the gift contract is enabled
    bool private _enabled;

    /* EVENTS */

    /**
     * @notice Emitted when an NFT is gifted
     * @param gifter Address of the gifter
     * @param to Address of the recipient
     * @param wrapperId ID of the wrapped NFT
     */
    event Gifted(address indexed gifter, address indexed to, uint256 indexed wrapperId);

    /**
     * @notice Emitted when the gift contract is enabled
     */
    event GiftEnabled();

    /**
     * @notice Emitted when the gift contract is disabled
     */
    event GiftDisabled();

    /* ERRORS */

    /// @dev Thrown when the gift contract is disabled
    error GiftContractDisabled();

    /**
     * @dev Initializes the GiftBase contract
     * @param _roles Address of the roles contract
     */
    function __GiftBase_init(address _roles) internal onlyInitializing {
        __Pausable_init();
        __ModifiersBase_init(_roles, GIFT_DOMAIN_NAME, DEFAULT_DOMAIN_VERSION);
        _enabled = true;
    }

    /* ENABLE/DISABLE MECHANISM */

    /**
     * @dev Modifier to check if the contract is enabled
     */
    modifier onlyWhenEnabled() {
        if (!_enabled) revert GiftContractDisabled();
        _;
    }

    /**
     * @notice Enables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function _enable() internal {
        _enabled = true;
        emit GiftEnabled();
    }

    /**
     * @notice Disables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function _disable() internal {
        _enabled = false;
        emit GiftDisabled();
    }

    /* SIGNATURE VERIFICATION */

    /**
     * @dev Helper function to create dataHash for gift operations
     * @param wrapperId ID of the wrapped NFT
     * @param to Recipient address
     * @return dataHash Hash of the gift parameters
     * @dev This dataHash is used with checkSignatureEIP712 modifier
     *      All gift-specific parameters are included to prevent tampering
     */
    function _getGiftDataHash(uint256 wrapperId, address to) internal pure returns (bytes32) {
        return keccak256(abi.encode(wrapperId, to));
    }

    /* GIFT PROCESSING */

    /**
     * @notice Processes a gift operation
     * @param gifter Address of the gifter
     * @param to Address of the recipient
     * @param wrapperId ID of the wrapped NFT
     */
    function _processGift(
        address gifter,
        address to,
        uint256 wrapperId
    ) internal {
        // Get wrappers contract
        address wrappersAddr = roles.getRoleAddress(WRAPPERS);
        IWrappers wrappers = IWrappers(wrappersAddr);

        // Verify ownership
        address currentOwner = IERC721(wrappersAddr).ownerOf(wrapperId);
        if (currentOwner != gifter) revert NotOwner(gifter, currentOwner);

        // Transfer wrapper
        wrappers.marketplaceTransfer(gifter, to, wrapperId);

        // Emit event
        emit Gifted(gifter, to, wrapperId);
    }
}

