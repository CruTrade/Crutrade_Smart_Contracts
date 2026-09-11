# 09 — Supporting contracts

Four small contracts round out the system: `Brands` (soulbound brand tokens), `Whitelist` (the
allow-list every user action checks), `Memberships` (the fee tier per address) and `USDCApprovalProxy`
(an ERC-2612 permit relay). `MockUSDC` exists only for local deployment and tests.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Brands (`src/Brands.sol`)

A soulbound ERC-721. Name `Crutrade Brands`, symbol `CRUB`, base URI
`https://metadata.crutrade.io/brands/`. `initialize(roles, firstBrandOwner)` registers brand id 1 to
`firstBrandOwner`; ids start at 1.

| Function | Access | Notes |
| --- | --- | --- |
| `register(owner)` | `OWNER` | mints the next brand id; rejects a zero owner with `InvalidBrandOwner` |
| `burn(brandId)` | `OWNER` | reverts `BrandNotFound` if unowned |
| `isValidBrand(brandId)` | view | true when the token has an owner |
| `getBrandOwner(brandId)` | view | reverts `BrandNotFound` if unowned |
| `setBaseURI(string)` | `OPERATIONAL` | note: not `OWNER`, unlike the other contracts |
| `setRoles(address)` | `OPERATIONAL` | no zero-address check |
| `pause` / `unpause` | `PAUSER` | |

Soulbound enforcement is in `BrandsBase._update`: any update where both `from` and `to` are non-zero
reverts `NotTransferable`, permitting only mint and burn. The inherited `approve`,
`setApprovalForAll` and `transferFrom` remain in the ABI but a transfer always reverts.

## Whitelist (`src/Whitelist.sol`)

A `mapping(address => bool)`. `addToWhitelist(address[])` and `removeFromWhitelist(address[])` are
`whenNotPaused` and `onlyRole(OPERATIONAL)`; each emits one `Add` or `Remove` event carrying the whole
batch. `isWhitelisted(address)` is the read used by the `onlyWhitelisted` modifier everywhere else.

Neither writer validates its input: an empty array emits an event and changes nothing, and zero
addresses can be whitelisted. `setRoles(address)` is `OWNER`-gated with no zero-address check.

## Memberships (`src/Memberships.sol`)

A `mapping(address => uint256)` of tier ids, read in bulk by `Payments.splitFees`.

| Function | Access | Behaviour |
| --- | --- | --- |
| `setMemberships(address[], id)` | `OPERATIONAL`, `whenNotPaused` | rejects an empty array with `InvalidMembershipOperation` |
| `revokeMembership(address)` | `OPERATIONAL`, `whenNotPaused` | rejects a zero address; reverts `MembershipNotFound` when the stored id is 0 |
| `getMembership(address)` / `getMemberships(address[])` | view | returns 0 for unknown addresses |
| `setRoles(address)` | `OWNER` | rejects zero |

Event semantics in `_setMemberships`: an address whose previous id was 0 is collected into a `Joined`
event; an address whose previous id was non-zero and different emits `MembershipUpdated` individually.
Re-assigning the same non-zero id emits nothing, and re-assigning id 0 to an address that already had
0 puts it in `Joined`.

Tier 0 is both "unset" and a valid fee tier, since `Payments` reads `_membershipFees[0]` for anyone
without an assignment.

## USDCApprovalProxy (`src/USDCApprovalProxy.sol`)

Forwards ERC-2612 permits so a user can approve `Payments` without holding gas. It stores two public
addresses, `usdcToken` and `paymentsContract`, both set at `initialize` and updatable by `OWNER`
through `setUSDCToken` and `setPaymentsContract` (each rejecting zero and emitting an event).

| Function | Access | Behaviour |
| --- | --- | --- |
| `permitUSDC(owner, spender, value, deadline, v, r, s)` | none | reverts `USDCTokenNotSet` or `PermitExpired`, then calls `IERC20Permit(usdcToken).permit(...)` and emits `USDCPermitForwarded` |
| `permitForPayments(owner, value, deadline, v, r, s)` | none | reverts `PaymentsContractNotSet`, then re-enters via `this.permitUSDC(...)` with `spender = paymentsContract` |
| `allowance(owner, spender)` | view | reverts `USDCTokenNotSet` if unset |
| `paymentsAllowance(owner)` | view | reverts `PaymentsContractNotSet` if unset |

The permit functions are intentionally permissionless: the user's signature is the authorization.
`permitForPayments` and `paymentsAllowance` call themselves through `this.`, which costs an extra
external call but keeps the revert semantics of the inner function.

`USDCPermitForwarded` always reports `success = true`, because a failing `permit` reverts the whole
transaction before the event is emitted. The declared error `InvalidPermitSignature` is never thrown;
the underlying token's own revert surfaces instead.

`USDCApprovalProxy` inherits `ModifiersBase`, so it carries the shared nonce map and domain separator
(domain name `USDCApprovalProxy`) even though it verifies no signatures of its own.

## MockUSDC (`src/mock/MockUSDC.sol`)

An `ERC20Permit` named "Mock USDC", symbol `USDC`, 18 decimals (it does not override `decimals()`,
despite minting `1_000_000 * 1e6` to the deployer). `mint(to, amount)` is unrestricted. It is deployed
only by `script/deploy.s.sol` in `runLocal()`.

## Open questions / unverified

- `Brands.setBaseURI` and `Brands.setRoles` are gated by `OPERATIONAL` while the equivalents on
  `Wrappers`, `Whitelist` and `Memberships` are gated by `OWNER`. Nothing records whether this is
  deliberate.
- `MockUSDC` mints with 6-decimal scaling but inherits 18 decimals. Since it is test-only this does not
  affect production, but local fee arithmetic will not match mainnet.
