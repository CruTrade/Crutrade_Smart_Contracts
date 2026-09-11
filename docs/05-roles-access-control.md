# 05 — Roles and access control

`src/Roles.sol` is the single authority for the ecosystem. It extends OpenZeppelin's
`AccessControlUpgradeable` with three additions: a "primary address" index so a role can be resolved to
one canonical address, a delegation flag that lets specific contracts act on users' assets, and a
registry of accepted payment tokens. Every other contract stores only the `Roles` address and asks it
for everything else.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Role identifiers

Roles are `keccak256('NAME')`. Constants are declared in `src/abstracts/ModifiersBase.sol` and
`src/abstracts/RolesBase.sol`.

| Role | Hash | Held by | Grants |
| --- | --- | --- | --- |
| `DEFAULT_ADMIN_ROLE` | `0x00…00` | deployment admin / multisig | grant and revoke any role, `setPayment`, `setDefaultFiatToken`, `grantDelegateRole`, `setPrimaryAddress` |
| `OWNER` | `0x6270edb7…feb91b` | admin | fee and schedule configuration, base URIs, `setRoles` |
| `OPERATIONAL` | `0xb0564e6f…f79b57b` | backend hot wallets | relay `list`/`buy`/`withdraw`/`renew`, `imports`/`exports`, whitelist and membership writes |
| `PAUSER` | `0x53944082…515c14c` | admin | `pause` / `unpause` on every contract |
| `UPGRADER` | `0xa615a8af…168cff4c` | admin | authorize UUPS upgrades |
| `TREASURY` | `0x06aa0396…3e83edb7` | treasury wallet | identity only; the fee wallet is `_fees[0].wallet` in `Payments` |
| `FIAT` | `0xd6d95ec8…870846c6` | platform fiat wallet | source of funds for fiat-settled operations |
| `BRANDS` | `0x0b176afd…d5fc5faf` | `Brands` proxy | resolved by `onlyAllowedBrand` |
| `WRAPPERS` | `0xd980240a…f835a23b` | `Wrappers` proxy | resolved by `Sales` and `onlyTokenOwner` |
| `WHITELIST` | `0x0af0c3eb…ce9f2500` | `Whitelist` proxy | resolved by `onlyWhitelisted` |
| `MEMBERSHIPS` | `0xabf1e1b8…d9373026` | `Memberships` proxy | resolved by `Payments.splitFees` |
| `PAYMENTS` | `0x9b545ae4…41a1c4b3` | `Payments` proxy | resolved by `Sales` |
| `SALES` | `0xd0145825…46a90ff1` | `Sales` proxy | granted at deploy; not read by any contract |

Operation identifiers used as service-fee keys are hashes of the same shape but are not roles:
`LIST`, `BUY`, `RENEW`, `WITHDRAW` (declared in `src/abstracts/SalesBase.sol`).

## Primary addresses

`AccessControl` allows many holders per role, but the contracts need one address per role to call.
`Roles` overrides `_grantRole` to also write `_primaryAddresses[role] = account`, so the most recent
grant wins. `_revokeRole` clears the entry only if the revoked account was the primary one and no
longer holds the role. `setPrimaryAddress(role, account)` lets an admin pick explicitly, and reverts
with `InvalidRole(role)` if the account does not already hold the role.

`getRoleAddress` and `getPrimaryAddress` return the same value; `getRoleAddress` is marked deprecated
in the source and kept for ABI compatibility.

Consequence: granting `OPERATIONAL` to a second hot wallet silently repoints
`getPrimaryAddress(OPERATIONAL)`. That does not affect `onlyRole`, which uses `hasRole`, but it does
affect anything reading the primary address.

## Delegation

`_delegated[address]` is a flag independent of `AccessControl`. `Roles.grantDelegateRole` sets it,
`revokeDelegateRole` clears it, and `hasDelegateRole` reads it. The `onlyDelegatedRole` modifier in
`ModifiersBase` gates the three functions that act on assets the caller does not own:

| Function | Contract |
| --- | --- |
| `marketplaceTransfer` | `src/Wrappers.sol` |
| `splitFees` | `src/Payments.sol` |
| `splitServiceFee` | `src/Payments.sol` |

`script/deploy.s.sol` grants the flag to `Wrappers`, `Payments` and `Sales`. In practice only `Sales`
needs it, since it is the only caller of those three functions.

## Payment token registry

`setPayment(token, decimals)` records `{decimals, isConfigured}` and emits `PaymentSet`.
`setDefaultFiatToken(token)` requires the token to be configured first and reverts with
`PaymentNotConfigured(token)` otherwise. `hasPaymentRole(token)` is what `onlyValidPayment` checks.
`Roles.initialize` configures the USDC address it is passed with 6 decimals and makes it the default
fiat token.

The stored `decimals` value is written but never read by any contract in `src/`.

## The shared modifiers

All in `src/abstracts/ModifiersBase.sol`:

| Modifier | Check | Reverts with |
| --- | --- | --- |
| `onlyRole(role)` | `roles.hasRole(role, msg.sender)` | `NotAllowed(role, account)` |
| `onlyDelegatedRole()` | `roles.hasDelegateRole(msg.sender)` | `NotAllowedDelegate(account)` |
| `onlyWhitelisted(wallet)` | `IWhitelist(...).isWhitelisted(wallet)` | `NotWhitelisted(wallet)` |
| `onlyValidPayment(payment)` | `payment == 0` or `roles.hasPaymentRole(payment)` | `PaymentNotAllowed(payment)` |
| `checkAddressZero(user)` | `user != address(0)` | `ZeroAddress()` |
| `onlyAllowedBrand(brandId)` | `IBrands(...).isValidBrand(brandId)` | `InvalidBrand(brandId)` — **not used anywhere** |
| `onlyTokenOwner(wallet, tokenId)` | `IERC721(...).ownerOf == wallet` | `NotOwner(...)` — **not used anywhere** |

Note that `onlyRole` here shadows OpenZeppelin's modifier of the same name and checks against the
remote `Roles` contract, not local storage. `Roles` itself uses the OpenZeppelin version.

## Signature modifiers

Five signature-verifying modifiers exist. Four are typed per operation and used by `Sales`; one is
generic and used by `Payments.send`.

| Modifier | Typehash | Used by |
| --- | --- | --- |
| `checkListSignature` | `LIST_TYPEHASH` | `Sales.list` |
| `checkBuySignature` | `BUY_TYPEHASH` | `Sales.buy` |
| `checkWithdrawSignature` | `WITHDRAW_TYPEHASH` | `Sales.withdraw` |
| `checkRenewSignature` | `RENEW_TYPEHASH` | `Sales.renew` |
| `checkSignatureEIP712` | `CrutradeMessage(...)` with an opaque `dataHash` | `Payments.send` |
| `checkFrontendSignature` | `abi.encodePacked` string format, 30-minute window | nothing |

Each typed hash includes the function selector, so a signature for `list` cannot be replayed against
`renew`. Each contract has its own EIP-712 domain name (`Crutrade Sales`, `Crutrade Payments`,
`Crutrade Wrappers`, `Crutrade Brands`, `Crutrade Whitelist`, `Crutrade Memberships`,
`USDCApprovalProxy`), so a signature is bound to one contract on one chain.

## Pausing

Every contract exposes `pause()` and `unpause()` behind `onlyRole(PAUSER)`. `Wrappers` and `Brands`
inherit `ERC721PausableUpgradeable`, so pausing also blocks plain ERC-721 transfers, minting and
burning through the overridden `_update`.

## Open questions / unverified

- `Roles.pause()` and `unpause()` exist but no function in `Roles` is marked `whenNotPaused`, so
  pausing the `Roles` contract has no observable effect from this codebase.
- `src/Sales.sol` declares `LISTER`, `BUYER`, `RENEWER` and `WITHDRAWER` role constants that no code
  reads; whether they are reserved for a future per-operation authorization split is not recorded.
