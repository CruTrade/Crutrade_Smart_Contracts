# 08 — Wrappers

`src/Wrappers.sol` is the ERC-721 that represents physical items. It is minted by the backend when an
item enters custody ("import") and flagged inactive when the item leaves ("export"). Beyond the
standard token behaviour it maintains a collection index, serves metadata from a configurable HTTPS
base URI, and exposes a privileged transfer used by `Sales` to take and return custody.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

Token name `Crutrade Wrappers`, symbol `CRUW`, initial base URI `https://cdn.crutrade.io/`
(`src/Wrappers.sol`, `initialize`).

## Wrapper data

`IWrappers.WrapperData`:

| Field | Set at import | Read by |
| --- | --- | --- |
| `uri` | from input | nothing in `src/` |
| `metaKey` | from input | `tokenURI`, `httpsTokenURI`, `ImportOutput` |
| `amount` | forced to `0` | nothing |
| `tokenId` | from input (the original item id) | `ImportOutput` |
| `brandId` | from input, unvalidated | nothing |
| `collection` | from input | `Sales` indexing, existence checks |
| `active` | forced to `true` | `exports` |

`collection == bytes32(0)` is the existence sentinel. Any wrapper id whose stored collection is zero is
treated as non-existent by `getWrapperData`, `tokenURI`, `httpsTokenURI`, `marketplaceTransfer` and
`batchTransfer`.

## Import and export

`imports(user, WrapperData[])` is `whenNotPaused`, `onlyRole(OPERATIONAL)`, `onlyWhitelisted(user)` and
`checkAddressZero(user)`. It rejects an empty array with `EmptyInput`, and rejects any input element
whose `active` flag is already `true` with `InvalidToken`. For each element it assigns
`wrapperId = _nextWrapperId++`, stores the record, adds the id to `_wrappersByCollection[collection]`
and `_safeMint`s to `user`. One `Import` event carries the whole batch.

`exports(user, wrapperIds[])` has the same guards. Per id it requires `active == true` (`InvalidToken`)
and a non-zero collection (`WrapperNotFound`), then sets `active = false` and removes the id from the
collection index. **It does not burn the token and does not check that `user` owns it.** The holder
keeps the NFT; only the flag and the index change.

Because export removes the id from `_wrappersByCollection`, a collection whose every wrapper has been
exported reports `isValidCollection == false` and `getCollectionData` reverts `CollectionNotFound`.

## Transfers

| Function | Guard | Used by |
| --- | --- | --- |
| `marketplaceTransfer(from, to, wrapperId)` | `whenNotPaused`, `onlyDelegatedRole`, both endpoints non-zero | `Sales` custody moves |
| `batchTransfer(to, wrapperIds[])` | `whenNotPaused`, `onlyRole(OWNER)`, `to` non-zero | admin recovery; moves tokens from the `OWNER` primary address |
| `transferFrom` / `safeTransferFrom` / `approve` | standard ERC-721, plus `whenNotPaused` via `_update` | holders |

`marketplaceTransfer` and `batchTransfer` both call `_update` directly, bypassing approval checks.
`batchTransfer` sources tokens from `roles.getRoleAddress(OWNER)`, not from `msg.sender`, so the caller
must hold `OWNER` and the tokens must sit at the primary `OWNER` address.

Standard ERC-721 transfers are **not** restricted: a holder can move a wrapper to anyone, whitelisted
or not, as long as the contract is unpaused. Only listed wrappers are protected, because `Sales` holds
them during a listing.

## Metadata

Two URI getters share one base string:

- `tokenURI(tokenId)` returns `_baseURI() + metaKey + ".json"`, where `_baseURI()` returns
  `_httpsBaseURI`.
- `httpsTokenURI(tokenId)` returns the same value through a separate code path.

Both revert `WrapperNotFound` for an unknown id. The base URI is writable by `OWNER` through either
`setHttpsBaseURI(string)` or its alias `setBaseURI(string)`; both assign `_httpsBaseURI`. The alias
exists for ABI compatibility, and `script/set-wrapper-base-uri.ts` calls `setHttpsBaseURI`.

A source comment records that a second `_baseURIString` variable was removed to avoid corrupting the
deployed storage layout, which is why one variable now backs both accessors.

## Admin surface

`setRoles(address)` (`OWNER`, non-zero) repoints the `Roles` reference and emits `RolesSet`.
`pause()` / `unpause()` are `PAUSER`-gated and, through `ERC721PausableUpgradeable`, block every
transfer, mint and burn.

## Events

`Import(user, ImportOutput[])`, `Export(user, wrapperIds[])`,
`MarketplaceTransfer(from, to, wrapperId)`, `BatchTransfer(from, to, tokenIds[])`, plus the standard
ERC-721 events. `script/fetch-wrapper-events.ts` reads exactly these five plus `Transfer`.

## Open questions / unverified

- `brandId` is stored but never checked against the `Brands` contract, and never read afterwards.
- `WrapperData.uri` is stored from input but no function returns it; `metaKey` is what drives both URI
  getters.
- `_toString` in `src/abstracts/WrapperBase.sol` is a hand-written uint-to-string helper that nothing
  calls.
