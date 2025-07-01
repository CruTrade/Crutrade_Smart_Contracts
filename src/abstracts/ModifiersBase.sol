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

  /* DOMAIN CONSTANTS */

  /// @notice Default domain name for contracts that don't need signature validation
  string internal constant DEFAULT_DOMAIN_NAME = "Crutrade";

  /// @notice Default domain version
  string internal constant DEFAULT_DOMAIN_VERSION = "1";

  /// @notice Sales contract domain name
  string internal constant SALES_DOMAIN_NAME = "Crutrade Sales";

  /// @notice Payments contract domain name
  string internal constant PAYMENTS_DOMAIN_NAME = "Crutrade Payments";

  /// @notice Brands contract domain name
  string internal constant BRANDS_DOMAIN_NAME = "Crutrade Brands";

  /// @notice Wrappers contract domain name
  string internal constant WRAPPERS_DOMAIN_NAME = "Crutrade Wrappers";

  /// @notice Whitelist contract domain name
  string internal constant WHITELIST_DOMAIN_NAME = "Crutrade Whitelist";

  /// @notice Memberships contract domain name
  string internal constant MEMBERSHIPS_DOMAIN_NAME = "Crutrade Memberships";

  /* EIP-712 TYPEHASHES */

  /// @notice Typehash for list messages
  bytes32 internal constant LIST_TYPEHASH = keccak256(
    "CrutradeListMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,uint256 wrapperId,uint256 directSaleId,bool isFiat,uint256 price,uint256 expireType)"
  );

  /// @notice Typehash for buy messages
  bytes32 internal constant BUY_TYPEHASH = keccak256(
    "CrutradeBuyMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,uint256 directSaleId,uint256 saleId,bool isFiat)"
  );

  /// @notice Typehash for withdraw messages
  bytes32 internal constant WITHDRAW_TYPEHASH = keccak256(
    "CrutradeWithdrawMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,uint256 directSaleId,uint256 saleId,bool isFiat)"
  );

  /// @notice Typehash for renew messages
  bytes32 internal constant RENEW_TYPEHASH = keccak256(
    "CrutradeRenewMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,uint256 directSaleId,uint256 saleId,bool isFiat,uint256 expireType)"
  );

  /* STORAGE */

  /// @dev Interface to the roles contract
  IRoles internal roles;

  /// @dev Used hash tracking to prevent replay attacks
  mapping(bytes32 => bool) private _usedHashes;

  /// @dev Nonce tracking per user to prevent replay attacks
  mapping(address => uint256) private _nonces;

  /// @dev EIP-712 domain separator
  bytes32 private _domainSeparator;

  /* EVENTS */

  /**
   * @dev Event emitted when roles contract is updated
   * @param roles New roles contract address
   */
  event RolesSet(address indexed roles);

  /**
   * @dev Event emitted when a nonce is used
   * @param user Address of the user
   * @param nonce Nonce that was used
   */
  event NonceUsed(address indexed user, uint256 nonce);

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

  /// @dev Thrown when nonce is invalid
  error InvalidNonce(uint256 expected, uint256 provided);

  /// @dev Thrown when signature has expired
  error SignatureExpired(uint256 expiry, uint256 current);

  /**
   * @dev Initializes the Modifiers contract
   * @param _roles Address of the Roles contract
   * @param domainName Domain name for EIP-712 (e.g., "Crutrade Sales", "Crutrade Payments")
   * @param domainVersion Domain version for EIP-712
   */
  function __ModifiersBase_init(address _roles, string memory domainName, string memory domainVersion) internal onlyInitializing {
    if (_roles == address(0)) revert ZeroAddress();
    roles = IRoles(_roles);

    // Initialize EIP-712 domain separator with contract-specific name and version
    _domainSeparator = keccak256(abi.encode(
      keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
      keccak256(bytes(domainName)),
      keccak256(bytes(domainVersion)),
      block.chainid,
      address(this)
    ));
  }

  /**
   * @dev Modifier to verify the signature of a message with EIP-712 domain separation
   * @param wallet Address of the signer
   * @param functionSelector Function selector to prevent cross-function replay
   * @param nonce Nonce to prevent replay attacks
   * @param expiry Timestamp when signature expires
   * @param dataHash Hash of the transaction data to prevent parameter manipulation
   * @param signature Signature to verify
   */
  modifier checkSignatureEIP712(
    address wallet,
    bytes4 functionSelector,
    uint256 nonce,
    uint256 expiry,
    bytes32 dataHash,
    bytes calldata signature
  ) {
    // Check if signature has expired
    if (block.timestamp > expiry) revert SignatureExpired(expiry, block.timestamp);

    // Check if nonce is valid
    uint256 expectedNonce = _nonces[wallet];
    if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

    // Create the message hash with EIP-712 domain separation
    bytes32 messageHash = keccak256(abi.encodePacked(
      "\x19\x01",
      _domainSeparator,
      keccak256(abi.encode(
        keccak256("CrutradeMessage(bytes4 functionSelector,uint256 nonce,uint256 expiry,bytes32 dataHash)"),
        functionSelector,
        nonce,
        expiry,
        dataHash
      ))
    ));

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(messageHash, signature);

    // Verify signature matches expected signer
    if (recoveredSigner != wallet) revert InvalidSignature(wallet, recoveredSigner);

    // Increment nonce to prevent replay
    _nonces[wallet]++;

    emit NonceUsed(wallet, nonce);
    _;
  }

  /**
   * @dev Modifier to verify signatures for list operations with direct parameter validation
   * @param wallet Address of the signer
   * @param functionSelector Function selector
   * @param nonce Nonce to prevent replay attacks
   * @param expiry Timestamp when signature expires
   * @param wrapperId ID of the wrapped NFT
   * @param directSaleId Direct sale ID
   * @param isFiat Whether this is a fiat payment
   * @param price Sale price
   * @param expireType Duration type for the sale
   * @param signature Signature to verify
   */
  modifier checkListSignature(
    address wallet,
    bytes4 functionSelector,
    uint256 nonce,
    uint256 expiry,
    uint256 wrapperId,
    uint256 directSaleId,
    bool isFiat,
    uint256 price,
    uint256 expireType,
    bytes calldata signature
  ) {
    // Check if signature has expired
    if (block.timestamp > expiry) revert SignatureExpired(expiry, block.timestamp);

    // Check if nonce is valid
    uint256 expectedNonce = _nonces[wallet];
    if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

    // Create the struct hash
    bytes32 structHash = keccak256(abi.encode(
      LIST_TYPEHASH,
      functionSelector,
      nonce,
      expiry,
      wrapperId,
      directSaleId,
      isFiat,
      price,
      expireType
    ));

    // Create the message hash with EIP-712 domain separation
    bytes32 messageHash = keccak256(abi.encodePacked(
      "\x19\x01",
      _domainSeparator,
      structHash
    ));

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(messageHash, signature);

    // Verify signature matches expected signer
    if (recoveredSigner != wallet) revert InvalidSignature(wallet, recoveredSigner);

    // Increment nonce to prevent replay
    _nonces[wallet]++;

    emit NonceUsed(wallet, nonce);
    _;
  }

  /**
   * @dev Modifier to verify signatures for buy operations with direct parameter validation
   * @param wallet Address of the signer
   * @param functionSelector Function selector
   * @param nonce Nonce to prevent replay attacks
   * @param expiry Timestamp when signature expires
   * @param directSaleId Direct sale ID
   * @param saleId Sale ID to buy
   * @param isFiat Whether this is a fiat payment
   * @param signature Signature to verify
   */
  modifier checkBuySignature(
    address wallet,
    bytes4 functionSelector,
    uint256 nonce,
    uint256 expiry,
    uint256 directSaleId,
    uint256 saleId,
    bool isFiat,
    bytes calldata signature
  ) {
    // Check if signature has expired
    if (block.timestamp > expiry) revert SignatureExpired(expiry, block.timestamp);

    // Check if nonce is valid
    uint256 expectedNonce = _nonces[wallet];
    if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

    // Create the struct hash
    bytes32 structHash = keccak256(abi.encode(
      BUY_TYPEHASH,
      functionSelector,
      nonce,
      expiry,
      directSaleId,
      saleId,
      isFiat
    ));

    // Create the message hash with EIP-712 domain separation
    bytes32 messageHash = keccak256(abi.encodePacked(
      "\x19\x01",
      _domainSeparator,
      structHash
    ));

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(messageHash, signature);

    // Verify signature matches expected signer
    if (recoveredSigner != wallet) revert InvalidSignature(wallet, recoveredSigner);

    // Increment nonce to prevent replay
    _nonces[wallet]++;

    emit NonceUsed(wallet, nonce);
    _;
  }

  /**
   * @dev Modifier to verify signatures for withdraw operations with direct parameter validation
   * @param wallet Address of the signer
   * @param functionSelector Function selector
   * @param nonce Nonce to prevent replay attacks
   * @param expiry Timestamp when signature expires
   * @param directSaleId Direct sale ID
   * @param saleId Sale ID to withdraw
   * @param isFiat Whether this is a fiat payment
   * @param signature Signature to verify
   */
  modifier checkWithdrawSignature(
    address wallet,
    bytes4 functionSelector,
    uint256 nonce,
    uint256 expiry,
    uint256 directSaleId,
    uint256 saleId,
    bool isFiat,
    bytes calldata signature
  ) {
    // Check if signature has expired
    if (block.timestamp > expiry) revert SignatureExpired(expiry, block.timestamp);

    // Check if nonce is valid
    uint256 expectedNonce = _nonces[wallet];
    if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

    // Create the struct hash
    bytes32 structHash = keccak256(abi.encode(
      WITHDRAW_TYPEHASH,
      functionSelector,
      nonce,
      expiry,
      directSaleId,
      saleId,
      isFiat
    ));

    // Create the message hash with EIP-712 domain separation
    bytes32 messageHash = keccak256(abi.encodePacked(
      "\x19\x01",
      _domainSeparator,
      structHash
    ));

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(messageHash, signature);

    // Verify signature matches expected signer
    if (recoveredSigner != wallet) revert InvalidSignature(wallet, recoveredSigner);

    // Increment nonce to prevent replay
    _nonces[wallet]++;

    emit NonceUsed(wallet, nonce);
    _;
  }

  /**
   * @dev Modifier to verify signatures for renew operations with direct parameter validation
   * @param wallet Address of the signer
   * @param functionSelector Function selector
   * @param nonce Nonce to prevent replay attacks
   * @param expiry Timestamp when signature expires
   * @param directSaleId Direct sale ID
   * @param saleId Sale ID to renew
   * @param isFiat Whether this is a fiat payment
   * @param expireType New duration type for the renewal
   * @param signature Signature to verify
   */
  modifier checkRenewSignature(
    address wallet,
    bytes4 functionSelector,
    uint256 nonce,
    uint256 expiry,
    uint256 directSaleId,
    uint256 saleId,
    bool isFiat,
    uint256 expireType,
    bytes calldata signature
  ) {
    // Check if signature has expired
    if (block.timestamp > expiry) revert SignatureExpired(expiry, block.timestamp);

    // Check if nonce is valid
    uint256 expectedNonce = _nonces[wallet];
    if (nonce != expectedNonce) revert InvalidNonce(expectedNonce, nonce);

    // Create the struct hash
    bytes32 structHash = keccak256(abi.encode(
      RENEW_TYPEHASH,
      functionSelector,
      nonce,
      expiry,
      directSaleId,
      saleId,
      isFiat,
      expireType
    ));

    // Create the message hash with EIP-712 domain separation
    bytes32 messageHash = keccak256(abi.encodePacked(
      "\x19\x01",
      _domainSeparator,
      structHash
    ));

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(messageHash, signature);

    // Verify signature matches expected signer
    if (recoveredSigner != wallet) revert InvalidSignature(wallet, recoveredSigner);

    // Increment nonce to prevent replay
    _nonces[wallet]++;

    emit NonceUsed(wallet, nonce);
    _;
  }



  /**
   * @dev Modifier to verify frontend-style signatures (for backward compatibility)
   * @param wallet Address of the signer
   * @param contractAddress Contract address that should be in the signature
   * @param functionName Function name that should be in the signature
   * @param parameters Parameters that should be in the signature
   * @param timestamp Timestamp that should be in the signature
   * @param signature Signature to verify
   */
  modifier checkFrontendSignature(
    address wallet,
    address contractAddress,
    string memory functionName,
    string memory parameters,
    uint256 timestamp,
    bytes calldata signature
  ) {
    // Create the message that frontend signs
    bytes32 messageHash = keccak256(abi.encodePacked(
      "contract:", contractAddress,
      "function:", functionName,
      "parameters:", parameters,
      "timestamp:", timestamp
    ));

    // Check if this message has been used before
    if (_usedHashes[messageHash]) revert HashAlreadyUsed(messageHash);

    // Check if timestamp is not too old (e.g., 30 minutes)
    if (block.timestamp > timestamp + 30 minutes) revert SignatureExpired(timestamp, block.timestamp);

    // Recover signer address from signature
    address recoveredSigner = ECDSA.recover(
      MessageHashUtils.toEthSignedMessageHash(messageHash),
      signature
    );

    // Verify signature matches expected signer
    if (recoveredSigner != wallet)
      revert InvalidSignature(wallet, recoveredSigner);

    // Mark hash as used to prevent replay
    _usedHashes[messageHash] = true;
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
    if (!roles.hasDelegateRole(sender))
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

  /* VIEW FUNCTIONS */

  /**
   * @dev Gets the current nonce for a user
   * @param user Address of the user
   * @return Current nonce
   */
  function getNonce(address user) external view returns (uint256) {
    return _nonces[user];
  }

  /**
   * @dev Gets the EIP-712 domain separator
   * @return Domain separator
   */
  function getDomainSeparator() external view returns (bytes32) {
    return _domainSeparator;
  }
}
