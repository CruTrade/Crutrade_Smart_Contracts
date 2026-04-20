// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./abstracts/GiftBase.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Gift
 * @notice Manages signature-based NFT gifting within the Crutrade ecosystem
 * @dev Provides interface for gifting wrapped NFTs using EIP-712 signatures
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Gift is GiftBase, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    /* INITIALIZATION */

    /**
     * @dev Prevents initialization of the implementation contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Gift contract
     * @param _roles The address of the roles contract
     */
    function initialize(address _roles) public initializer {
        __GiftBase_init(_roles);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /* GIFT OPERATIONS */

    /**
     * @notice Gifts a wrapper NFT to another address
     * @param gifter The gifter's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param wrapperId ID of the wrapped NFT
     * @param to Address of the recipient
     * @dev Uses checkSignatureEIP712 with dataHash containing wrapperId and to
     *      Signature format: CrutradeMessage(functionSelector, nonce, expiry, dataHash)
     *      where dataHash = keccak256(abi.encode(wrapperId, to))
     */
    function gift(
        address gifter,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 wrapperId,
        address to
    )
        external
        whenNotPaused
        onlyWhenEnabled
        nonReentrant
        onlyRole(OPERATIONAL)
        onlyWhitelisted(gifter)
        checkSignatureEIP712(
            gifter,
            this.gift.selector,
            nonce,
            expiry,
            _getGiftDataHash(wrapperId, to),
            signature
        )
    {
        _processGift(gifter, to, wrapperId);
    }

    /* ENABLE/DISABLE FUNCTIONS */

    /**
     * @notice Enables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function enable() external onlyRole(OWNER) {
        _enable();
    }

    /**
     * @notice Disables the gift contract
     * @dev Can only be called by an account with the OWNER role
     */
    function disable() external onlyRole(OWNER) {
        _disable();
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





















