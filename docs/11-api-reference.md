# 11 — API reference

Every externally callable function of the eight deployed contracts, with its access requirement and
the file that implements it. Signatures were read from the compiled ABIs in `out/`; access control was
read from the modifiers in `src/`. Inherited OpenZeppelin members (`proxiableUUID`,
`UPGRADE_INTERFACE_VERSION`, `supportsInterface`, `paused`, and the standard ERC-721 surface) are
listed only where they carry project-specific behaviour.

There are no HTTP endpoints, cron jobs, queues or webhooks in this repository. The equivalent surfaces
are these contract functions and the CLI scripts in `docs/12-scripts-reference.md`.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Common to every contract

| Function | Access | Notes |
| --- | --- | --- |
| `upgradeToAndCall(address,bytes)` | `UPGRADER` | UUPS; `_authorizeUpgrade` also rejects a zero implementation |
| `pause()` / `unpause()` | `PAUSER` | absent from `USDCApprovalProxy` |
| `getNonce(address)` | view | `ModifiersBase`; absent from `Roles` |
| `getDomainSeparator()` | view | `ModifiersBase`; absent from `Roles` |

## Roles — `src/Roles.sol`

| Function | Access | Reverts |
| --- | --- | --- |
| `initialize(address defaultAdmin, address usdc, address[] operational, address[] contracts, bytes32[] userRoles, bytes32[] contractRoles, uint256[] delegateIndices)` | initializer | `InvalidContract` on zero admin |
| `grantRole(bytes32,address)` / `revokeRole` / `renounceRole` | `DEFAULT_ADMIN_ROLE` | OZ `AccessControlUnauthorizedAccount` |
| `grantDelegateRole(address)` / `revokeDelegateRole(address)` | `DEFAULT_ADMIN_ROLE` | `InvalidContract` on zero |
| `setPayment(address token, uint8 decimals)` | `DEFAULT_ADMIN_ROLE` | `InvalidTokenAddress` |
| `setDefaultFiatToken(address)` | `DEFAULT_ADMIN_ROLE` | `PaymentNotConfigured` |
| `setPrimaryAddress(bytes32 role, address)` | `DEFAULT_ADMIN_ROLE` | `InvalidRole` if the account lacks the role |
| `hasRole`, `getRoleAdmin`, `hasDelegateRole`, `hasPaymentRole` | view | |
| `getPrimaryAddress(bytes32)`, `getRoleAddress(bytes32)` | view | identical; the second is deprecated |
| `getDefaultFiatPayment()` | view | |

## Sales — `src/Sales.sol`

All four operations are `whenNotPaused nonReentrant onlyRole(OPERATIONAL) onlyWhitelisted(wallet)` plus
their signature modifier.

| Function | Notes |
| --- | --- |
| `list(address seller, uint256 nonce, uint256 expiry, bytes signature, uint256 wrapperId, uint256 directSaleId, bool isFiat, uint256 price, uint256 expireType, address erc20)` | `InvalidSalePrice` on zero price, `InvalidDurationId` on unknown or unset duration, `NotOwner` if the seller does not own the wrapper |
| `buy(address buyer, uint256 nonce, uint256 expiry, bytes signature, uint256 directSaleId, uint256 saleId, bool isFiat, address erc20)` | `SaleNotFound`, `SaleNotActive`, `SaleNotStarted`, `SaleExpired`, `require("Seller not whitelisted")` |
| `withdraw(address seller, …, uint256 saleId, bool isFiat, address erc20)` | same state checks plus `NotOwner` when the caller is not the seller |
| `renew(address seller, …, uint256 saleId, bool isFiat, uint256 expireType, address erc20)` | `SaleNotExpired` while the sale is still live; `InvalidTimestamp` if the next schedule is not in the future |
| `setSchedules(uint256[],uint8[],uint8[],uint8[])` | `OWNER`; `InvalidSaleOperation` on empty input or length mismatch |
| `removeSchedules(uint256[])` | `OWNER` |
| `setDurations(uint256[],uint256[])` | `OWNER`; `require` duration in `(0, 365 days]` |
| `setListingDelay(uint256)` | `OWNER`; `InvalidListingDelay` above 365 days |
| `getSale(uint256)` | view; `SaleNotFound` |
| `getSalesByCollection(bytes32)` | view, unbounded |
| `getSalesByCollectionPaginated(bytes32,uint256,uint256)` | view; returns page and total |
| `getSalesBySellerPaginated(address,uint256,uint256)` | view; `require` non-zero seller |
| `getSchedule(uint256)` | view; `require("Invalid schedule ID")` at or above `_scheduleCount` |
| `getActiveSchedules()` | view, unbounded |
| `getDuration(uint256)` | view; `InvalidDurationId` |
| `getAllDurationsPaginated(uint256,uint256)` | view |
| `getNextScheduleTime()`, `getListingDelay()` | view |

## Payments — `src/Payments.sol`

| Function | Access | Notes |
| --- | --- | --- |
| `initialize(address roles, address treasury, uint256 fiatFeePercentage, MembershipFeeConfig[] fees)` | initializer | `ZeroAddress` on zero treasury, `InvalidPercentage` above 10000 |
| `splitServiceFee(bytes32 operation, address wallet, address erc20)` | `whenNotPaused onlyDelegatedRole onlyValidPayment` | returns `ServiceFee` |
| `splitFees(address erc20, uint256 transactionId, address from, address to, uint256 amount)` | `whenNotPaused onlyDelegatedRole onlyValidPayment` | returns `TransactionFees`, emits `FeesProcessed` |
| `send(uint256 nonce, uint256 expiry, bytes signature, address erc20, address from, address to, uint256 amount)` | `onlyRole(OPERATIONAL) onlyWhitelisted(from)` + `checkSignatureEIP712` | not `whenNotPaused`; `InvalidTokenAddress`, `ZeroAddress` |
| `addFee(bytes32,uint256,address)` | `OWNER` | `InvalidPercentage`, `DuplicateFee`, `ZeroAddress`, `TotalPercentageExceedsLimit` |
| `updateFee(bytes32,uint256,address)` | `OWNER` | `FeeNotFound`, plus the above |
| `removeFee(bytes32)` | `OWNER` | `FeeNotFound` |
| `updateTreasuryAddress(address)` | `OWNER` | `ZeroAddress`, `FeeNotFound` |
| `setFiatFeePercentage(uint256)` | `OWNER` | `InvalidPercentage` |
| `setServiceFee(bytes32 operation, uint256 fee)` | `OWNER` | no validation |
| `setMembershipFees(uint256,uint256,uint256)` | `OWNER` | `InvalidPercentage` |
| `getFees()`, `getFee(bytes32)`, `getMembershipFees(uint256)` | view | `getFee` reverts `FeeNotFound` |

## Wrappers — `src/Wrappers.sol`

| Function | Access | Notes |
| --- | --- | --- |
| `imports(address user, WrapperData[] wrappers)` | `whenNotPaused onlyRole(OPERATIONAL) onlyWhitelisted checkAddressZero` | `EmptyInput`, `InvalidToken` |
| `exports(address user, uint256[] wrapperIds)` | same | `EmptyInput`, `InvalidToken`, `WrapperNotFound` |
| `marketplaceTransfer(address,address,uint256)` | `whenNotPaused onlyDelegatedRole` | `WrapperNotFound` |
| `batchTransfer(address to, uint256[] wrapperIds)` | `whenNotPaused onlyRole(OWNER)` | moves from the `OWNER` primary address |
| `setHttpsBaseURI(string)` / `setBaseURI(string)` | `OWNER` | aliases writing the same variable |
| `setRoles(address)` | `OWNER` + `checkAddressZero` | emits `RolesSet` |
| `getWrapperData(uint256)` | view | `WrapperNotFound` |
| `getCollectionData(bytes32)` | view | `CollectionNotFound` |
| `checkCollection(bytes32,uint256)`, `isValidCollection(bytes32)` | view | |
| `tokenURI(uint256)`, `httpsTokenURI(uint256)` | view | `WrapperNotFound` |
| ERC-721 `transferFrom`, `safeTransferFrom`, `approve`, `setApprovalForAll`, `balanceOf`, `ownerOf` | standard | transfers blocked only while paused |

## Brands — `src/Brands.sol`

| Function | Access | Notes |
| --- | --- | --- |
| `initialize(address roles, address firstBrandOwner)` | initializer | registers brand 1 |
| `register(address owner)` | `OWNER` | `InvalidBrandOwner`; returns the new id |
| `burn(uint256 brandId)` | `OWNER` | `BrandNotFound` |
| `setBaseURI(string)` | `OPERATIONAL` | |
| `setRoles(address)` | `OPERATIONAL` | no zero check |
| `isValidBrand(uint256)`, `getBrandOwner(uint256)` | view | second reverts `BrandNotFound` |
| ERC-721 transfer surface | standard | always reverts `NotTransferable` |

## Whitelist — `src/Whitelist.sol`

| Function | Access |
| --- | --- |
| `addToWhitelist(address[])` | `whenNotPaused onlyRole(OPERATIONAL)` |
| `removeFromWhitelist(address[])` | `whenNotPaused onlyRole(OPERATIONAL)` |
| `isWhitelisted(address)` | view |
| `setRoles(address)` | `OWNER` |

## Memberships — `src/Memberships.sol`

| Function | Access | Notes |
| --- | --- | --- |
| `setMemberships(address[] members, uint256 id)` | `whenNotPaused onlyRole(OPERATIONAL)` | `InvalidMembershipOperation` on empty input |
| `revokeMembership(address)` | `whenNotPaused onlyRole(OPERATIONAL)` | `ZeroAddress`, `MembershipNotFound` |
| `getMembership(address)`, `getMemberships(address[])` | view | 0 when unset |
| `setRoles(address)` | `OWNER` | `ZeroAddress` |

## USDCApprovalProxy — `src/USDCApprovalProxy.sol`

| Function | Access | Notes |
| --- | --- | --- |
| `initialize(address roles, address usdcToken, address paymentsContract)` | initializer | `ZeroAddress` on either address |
| `permitUSDC(address,address,uint256,uint256,uint8,bytes32,bytes32)` | none | `USDCTokenNotSet`, `PermitExpired` |
| `permitForPayments(address,uint256,uint256,uint8,bytes32,bytes32)` | none | `PaymentsContractNotSet` |
| `setUSDCToken(address)` / `setPaymentsContract(address)` | `OWNER` | `ZeroAddress` |
| `allowance(address,address)`, `paymentsAllowance(address)` | view | `USDCTokenNotSet` / `PaymentsContractNotSet` |
| `usdcToken()`, `paymentsContract()` | view | public state variables |

## Events by contract

| Contract | Events |
| --- | --- |
| `Roles` | `PaymentSet`, `DefaultFiatTokenSet`, `DelegateRoleGranted`, `DelegateRoleRevoked`, `PrimaryAddressChanged`, plus OZ `RoleGranted`/`RoleRevoked` |
| `Sales` | `List`, `Buy`, `Withdraw`, `Renew`, `DurationSet`, `ScheduleSet`, `ScheduleRemoved`, `ListingDelayUpdated` |
| `Payments` | `FeeAdded`, `FeeRemoved`, `FeeUpdated`, `FeesProcessed`, `FiatFeePercentageUpdated`, `MembershipFeesUpdated`, `Send` |
| `Wrappers` | `Import`, `Export`, `MarketplaceTransfer`, `BatchTransfer`, ERC-721 standard |
| `Brands` | `BrandRegistered`, `BrandBurned`, ERC-721 standard |
| `Whitelist` | `Add`, `Remove` |
| `Memberships` | `Joined`, `MembershipUpdated`, `MembershipRevoked` |
| `USDCApprovalProxy` | `USDCPermitForwarded`, `USDCTokenUpdated`, `PaymentsContractUpdated` |
| all but `Roles` | `RolesSet`, `NonceUsed` |
