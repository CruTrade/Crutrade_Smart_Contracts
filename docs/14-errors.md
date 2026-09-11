# 14 — Errors

The contracts revert with Solidity custom errors almost everywhere; a handful of legacy `require`
strings remain. This chapter lists every declared error, where it is declared, and what triggers it.
Errors marked "declared, never thrown" are dead code kept in the ABI.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Shared — `src/abstracts/ModifiersBase.sol`

Inherited by every contract except `Roles`, so these appear in seven ABIs.

| Error | Thrown when |
| --- | --- |
| `ZeroAddress()` | a required address argument is zero (`checkAddressZero`, initializers) |
| `NotAllowed(bytes32 role, address account)` | `onlyRole` and the caller lacks the role |
| `NotAllowedDelegate(address account)` | `onlyDelegatedRole` and the caller has no delegation flag |
| `NotWhitelisted(address wallet)` | `onlyWhitelisted` and the address is not on the list |
| `PaymentNotAllowed(address payment)` | `onlyValidPayment` and the token is non-zero and unregistered |
| `NotOwner(address claimer, address actualOwner)` | the seller does not own the wrapper, or a withdraw/renew is attempted by a non-seller |
| `InvalidSignature(address expected, address actual)` | the recovered signer is not the claimed wallet |
| `InvalidNonce(uint256 expected, uint256 provided)` | the signed nonce is not the user's current nonce |
| `SignatureExpired(uint256 expiry, uint256 current)` | `block.timestamp > expiry` |
| `InvalidBrand(uint256 brandId)` | declared, never thrown (`onlyAllowedBrand` is unused) |
| `HashAlreadyUsed(bytes32 hash)` | declared, never thrown (`checkFrontendSignature` is unused) |

## Roles — `src/abstracts/RolesBase.sol`

| Error | Thrown when |
| --- | --- |
| `InvalidContract(address)` | zero admin in `__RolesBase_init`, zero address in `grantDelegateRole` / `revokeDelegateRole`, zero implementation in `_authorizeUpgrade` |
| `InvalidTokenAddress()` | `setPayment` with a zero token |
| `PaymentNotConfigured(address token)` | `setDefaultFiatToken` before `setPayment`, or `_getTokenDecimals` on an unknown token |
| `InvalidRole(bytes32 role)` | `setPrimaryAddress` for an account that does not hold the role |

`Roles` also surfaces OpenZeppelin's `AccessControlUnauthorizedAccount` and
`AccessControlBadConfirmation`.

## Sales — `src/abstracts/SalesBase.sol`

| Error | Thrown when |
| --- | --- |
| `InvalidSaleOperation(string reason)` | empty input array or length mismatch in `setSchedules`, `removeSchedules`, `setDurations` |
| `SaleNotFound(uint256 saleId)` | the stored seller is zero |
| `SaleNotActive(uint256 saleId)` | the sale was already bought or withdrawn |
| `SaleNotStarted(uint256 startTime)` | `buy` or `withdraw` before the scheduled start |
| `SaleExpired(uint256 endTime)` | `buy` or `withdraw` after the end |
| `SaleNotExpired(uint256 saleId)` | `renew` while the sale is still live |
| `InvalidSalePrice(uint256 price)` | listing at price 0 |
| `InvalidDurationId(uint256 durationId)` | `expireType` above `_maxDurationId`, or a duration of 0 |
| `InvalidTimestamp(uint256 timestamp)` | the computed next schedule time is not in the future |
| `InvalidSaleDuration(uint256 duration)` | declared, never thrown |

`ScheduleBase` adds `InvalidListingDelay(uint256 delay)` for a delay above 365 days.

Remaining `require` strings in this module: `"Invalid schedule parameters"`, `"Invalid schedule ID"`,
`"Duration must be positive"`, `"Duration exceeds maximum allowed"`, `"Invalid seller address"`,
`"Seller not whitelisted"` (in `_processSinglePurchase`).

## Payments — `src/abstracts/PaymentsBase.sol`

| Error | Thrown when |
| --- | --- |
| `FeeNotFound(bytes32 name)` | `getFee`, `updateFee`, `removeFee`, `updateTreasuryAddress` for an unknown fee |
| `DuplicateFee(bytes32 name)` | `addFee` with an existing name |
| `InvalidPercentage(uint256)` | any percentage above 10000 bps |
| `TotalPercentageExceedsLimit()` | the sum of `_fees[].percentage` would exceed 10000 bps |
| `InvalidTokenAddress()` | `send` with a zero token |
| `TransferFailed()`, `InsufficientPayment(...)`, `InvalidPaymentToken(address)`, `PaymentFailed(address,uint256)` | declared, never thrown |

ERC-20 failures surface as OpenZeppelin `SafeERC20FailedOperation`, or as the token's own revert
(`ERC20InsufficientAllowance`, `ERC20InsufficientBalance`).

## Wrappers — `src/abstracts/WrapperBase.sol`

| Error | Thrown when |
| --- | --- |
| `WrapperNotFound(uint256 wrapperId)` | the stored collection is zero |
| `EmptyInput()` | `imports`, `exports` or `batchTransfer` with an empty array |
| `InvalidToken()` | importing a record already flagged `active`, or exporting an inactive one |
| `CollectionNotFound(bytes32 collection)` | `getCollectionData` for a collection with no active wrappers |
| `UnauthorizedTransfer(address,address)`, `InvalidCollection(uint256,bytes32)` | declared, never thrown |

## Brands — `src/abstracts/BrandsBase.sol`

| Error | Thrown when |
| --- | --- |
| `NotTransferable()` | any ERC-721 transfer of a brand token |
| `BrandNotFound(uint256 brandId)` | `burn` or `getBrandOwner` for an unowned id |
| `InvalidBrandOwner(address owner)` | `register` with a zero owner |

## Memberships — `src/abstracts/MembershipsBase.sol`

| Error | Thrown when |
| --- | --- |
| `MembershipNotFound(address member)` | `revokeMembership` when the stored id is 0 |
| `InvalidMembershipOperation()` | `setMemberships` with an empty array |
| `InvalidMembership(uint256 membershipId)` | declared, never thrown |

## USDCApprovalProxy — `src/USDCApprovalProxy.sol`

| Error | Thrown when |
| --- | --- |
| `USDCTokenNotSet()` | `permitUSDC`, `allowance` before the token is configured |
| `PaymentsContractNotSet()` | `permitForPayments`, `paymentsAllowance` before the contract is configured |
| `PermitExpired()` | `block.timestamp > deadline` |
| `InvalidPermitSignature()` | declared, never thrown; the token's own revert surfaces instead |

## Proxy and pause errors

From OpenZeppelin, present in every ABI: `EnforcedPause`, `ExpectedPause`, `InvalidInitialization`,
`NotInitializing`, `UUPSUnauthorizedCallContext`, `UUPSUnsupportedProxiableUUID`, `ERC1967InvalidImplementation`,
`ERC1967NonPayable`, `FailedCall`. `Sales` additionally exposes `ReentrancyGuardReentrantCall`.

## Debugging a revert

Selectors are the first four bytes of `keccak256` over the error signature. `cast 4byte <selector>`
resolves known ones; for project errors, compute directly, for example
`cast sig "NotAllowed(bytes32,address)"`. `script/set-wrapper-base-uri.ts` hardcodes one such lookup
(`0xb87a12a9`) to explain a missing `OWNER` role.
