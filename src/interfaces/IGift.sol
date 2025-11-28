// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IGift
 * @notice Interface for gift operations in the Crutrade ecosystem
 * @dev Defines methods for signature-based NFT gifting
 * @author Crutrade Team
 */
interface IGift {
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

    /* FUNCTIONS */

    /**
     * @notice Gifts a wrapper NFT to another address
     * @param gifter The gifter's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param wrapperId ID of the wrapped NFT
     * @param to Address of the recipient
     */
    function gift(
        address gifter,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 wrapperId,
        address to
    ) external;

    /**
     * @notice Enables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function enable() external;

    /**
     * @notice Disables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function disable() external;
}








