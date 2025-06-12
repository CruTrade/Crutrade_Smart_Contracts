// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import '../interfaces/IRoles.sol';
import '../interfaces/IBrands.sol';
import '../interfaces/IWhitelist.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/access/IAccessControl.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';

/**
 * @title ModifiersBase
 * @notice Abstract base contract providing common security modifiers for the Crutrade ecosystem
 * @dev Provides reusable security modifiers, validation, and access control patterns
 * @author Crutrade Team
 */
abstract contract ModifiersBase is Initializable {
  /* CONSTANTS */

  /// @notice Owner role identifier
  bytes32 internal constant OWNER = keccak256('OWNER');

  /// @notice Pauser role identifier
  bytes32 internal constant PAUSER = keccak256('PAUSER');

  /// @notice Upgrader role identifier
  bytes32 internal constant UPGRADER = keccak256('UPGRADER');

  /// @notice Operational role identifier
  bytes32 internal constant OPERATIONAL = keccak256('OPERATIONAL');

  /// @notice Brands role identifier
  bytes32 internal constant BRANDS = keccak256('BRANDS');

  /// @notice Wrappers role identifier
  bytes32 internal constant WRAPPERS = keccak256('WRAPPERS');

  /// @notice Whitelist role identifier
  bytes32 internal constant WHITELIST = keccak256('WHITELIST');

  /// @notice Treasury role identifier
  bytes32 internal constant TREASURY = keccak256('TREASURY');

  /// @notice Fiat role identifier
  bytes32 internal constant FIAT = keccak256('FIAT');

  /* STORAGE */

  /// @dev Interface to the roles contract
  IRoles internal roles;

  /// @dev Used hash tracking to prevent replay attacks
  mapping(bytes32 => bool) private _usedHashes;

  /* EVENTS */

  /**
   * @dev Event emitted when roles contract is updated
   * @param roles New roles contract address
   */
  event RolesSet(address indexed roles);

  /* ERRORS */

  /// @dev Thrown when attempting to use a hash that was already used
  error HashAlreadyUsed(bytes32 hash);

  /// @dev Thrown when an invalid brand ID is provided
  error InvalidBrand(uint256 brandId);

  /// @dev Thrown when an address is not in the whitelist
  error NotWhitelisted(address wallet);

  /// @dev Thrown when a payment method is not allowed
  error PaymentNotAllowed(address payment);

  /// @dev Thrown when a contract is not allowed to act as a delegate
  error NotAllowedDelegate(address account);

  /// @dev Thrown when an account does not have the required role
  error NotAllowed(bytes32 role, address account);

  /// @dev Thrown when the claimer is not the owner
  error NotOwner(address claimer, address actualOwner);

  /// @dev Thrown when signature verification fails
  error InvalidSignature(address expected, address actual);

  /// @dev Thrown when address validation fails
  error ZeroAddress();

  /**
   * @dev Initializes the Modifiers contract
   * @param _roles Address of the Roles contract
   */
  function __ModifiersBase_init(address _roles) internal onlyInitializing {
    if (_roles == address(0)) revert ZeroAddress();
    roles = IRoles(_roles);
  }

  /**
   * @dev Modifier to verify the signature of a message
   * @param wallet Address of the signer
   * @param hash Hash of the message
   * @param signature Signature to verify
   */
  modifier checkSignature(
    address wallet,
    bytes32 hash,
    bytes calldata signature
  ) {
    // Check if hash has been used before
    if (_usedHashes[hash]) revert HashAlreadyUsed(hash);

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(
      MessageHashUtils.toEthSignedMessageHash(hash),
      signature
    );

    // Verify signature matches expected signer
    if (recoveredSigner != wallet)
      revert InvalidSignature(wallet, recoveredSigner);

    // Mark hash as used to prevent replay
    _usedHashes[hash] = true;
    _;
  }

  /**
   * @dev Modifier to verify signature with expiration
   * @param wallet Address of the signer
   * @param hash Hash of the message
   * @param signature Signature to verify
   * @param expiry Timestamp when the signature expires
   */
  modifier checkSignatureWithExpiry(
    address wallet,
    bytes32 hash,
    bytes calldata signature,
    uint256 expiry
  ) {
    // Verify timestamp has not expired
    require(block.timestamp <= expiry, 'Signature expired');

    // Create full hash including expiry
    bytes32 fullHash = keccak256(abi.encodePacked(hash, expiry));

    // Check if hash has been used before
    if (_usedHashes[fullHash]) revert HashAlreadyUsed(fullHash);

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(
      MessageHashUtils.toEthSignedMessageHash(fullHash),
      signature
    );

    // Verify signature matches expected signer
    if (recoveredSigner != wallet)
      revert InvalidSignature(wallet, recoveredSigner);

    // Mark hash as used to prevent replay
    _usedHashes[fullHash] = true;
    _;
  }

  /**
   * @dev Modifier to restrict access to accounts with a specific role
   * @param role The role required to access the function
   */
  modifier onlyRole(bytes32 role) {
    address sender = msg.sender;
    if (!roles.hasRole(role, sender)) revert NotAllowed(role, sender);
    _;
  }

  /**
   * @dev Modifier to restrict access to delegated roles
   * Only contracts with delegation rights can call functions with this modifier
   */
  modifier onlyDelegatedRole() {
    address sender = msg.sender;
    if (!roles.hasDelegateRole(sender) && sender.code.length > 0)
      revert NotAllowedDelegate(sender);
    _;
  }

  /**
   * @dev Modifier to check if an address is non-zero
   * @param user Address to check
   */
  modifier checkAddressZero(address user) {
    if (user == address(0)) revert ZeroAddress();
    _;
  }

  /**
   * @dev Modifier to restrict access to whitelisted addresses
   * @param wallet Address to check for whitelist status
   */
  modifier onlyWhitelisted(address wallet) {
    if (!IWhitelist(roles.getRoleAddress(WHITELIST)).isWhitelisted(wallet))
      revert NotWhitelisted(wallet);
    _;
  }

  /**
   * @dev Modifier to check if a brand ID is valid
   * @param brandId The ID of the brand to check
   */
  modifier onlyAllowedBrand(uint256 brandId) {
    if (!IBrands(roles.getRoleAddress(BRANDS)).isValidBrand(brandId))
      revert InvalidBrand(brandId);
    _;
  }

  /**
   * @dev Modifier to check if a payment method is allowed
   * @param payment Address of the payment method
   */
  modifier onlyValidPayment(address payment) {
    if (payment != address(0) && !roles.hasPaymentRole(payment))
      revert PaymentNotAllowed(payment);
    _;
  }

  /**
   * @dev Modifier to restrict access to the owner of a specific token
   * @param wallet Address claiming to be the owner
   * @param tokenId ID of the token
   */
  modifier onlyTokenOwner(address wallet, uint256 tokenId) {
    address actualOwner = IERC721(roles.getRoleAddress(WRAPPERS)).ownerOf(
      tokenId
    );
    if (actualOwner != wallet) revert NotOwner(wallet, actualOwner);
    _;
  }

  /**
   * @dev Helper function to verify a brand owner
   * @param brandId ID of the brand
   * @param claimedOwner Address claiming to be the owner
   * @return True if the address is the brand owner
   */
  function _isBrandOwner(
    uint256 brandId,
    address claimedOwner
  ) internal view returns (bool) {
    IBrands brands = IBrands(roles.getRoleAddress(BRANDS));
    if (!brands.isValidBrand(brandId)) revert InvalidBrand(brandId);
    return brands.getBrandOwner(brandId) == claimedOwner;
  }
}
