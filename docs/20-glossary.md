# 20 — Glossary

Terms used across this repository, with the code that defines them.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

| Term | Meaning |
| --- | --- |
| **Wrapper** | The ERC-721 token representing a physical item. Minted on import, flagged inactive on export. `src/Wrappers.sol` |
| **Collection** | A `bytes32` grouping wrappers, also called SKU in `ImportOutput.sku`. Indexed in `_wrappersByCollection` and used to index sales. |
| **Import** | Minting a wrapper for an item entering custody. `Wrappers.imports` |
| **Export** | Flagging a wrapper inactive and removing it from its collection index. Does not burn the token. `Wrappers.exports` |
| **Brand** | A soulbound ERC-721 identifying a marque. `src/Brands.sol` |
| **Sale / listing** | A `Sale` record with a start, end, price, seller and wrapper id. Keyed by `saleId`, starting at 1. `src/interfaces/ISales.sol` |
| **Schedule** | A weekly drop window (day, hour, minute, UTC) that determines when a new listing goes live. `src/abstracts/ScheduleBase.sol` |
| **Listing delay** | Fallback offset from now, used when no schedule is active. Default 7 days. |
| **Duration / expireType** | An id in `_durations` mapping to a sale length in seconds. Id 0 is seeded to 56 days. |
| **directSaleId** | An identifier included in every signed sale payload and every `Sales` entry point, never stored or validated on-chain. |
| **Membership** | A `uint256` tier per address that selects the fee pair used by `Payments`. Tier 0 is both "unset" and a valid tier. |
| **Service fee** | A flat token amount charged per operation (`LIST`, `BUY`, `WITHDRAW`, `RENEW`), sent to `_fees[0].wallet`. |
| **Transaction fee** | The percentage fees on a purchase, derived from the buyer's and seller's membership tiers. |
| **BPS** | Basis points. `BPS = 10000` equals 100 %. All percentages in `Payments` use this scale. |
| **Fiat path** | Settlement signalled by `erc20 == address(0)`. The token becomes the default fiat token and the payer becomes the `FIAT` role holder. |
| **Fiat surcharge** | `_fiatFeePercentage`, an extra bps charge applied only on the fiat path. |
| **Delegate / delegation** | A boolean flag in `Roles`, separate from any role, permitting a contract to move other users' assets. Checked by `onlyDelegatedRole`. |
| **Primary address** | The single canonical address per role, stored in `Roles._primaryAddresses` and returned by `getPrimaryAddress` and `getRoleAddress`. |
| **Relayer** | The backend account holding `OPERATIONAL` that submits users' signed intents and pays gas. |
| **Nonce** | A per-user, per-contract counter in `ModifiersBase._nonces` that must match the signed value exactly. Read with `getNonce`. |
| **Domain separator** | The EIP-712 domain hash computed once at initialization from the contract's name, version, chain id and address. Read with `getDomainSeparator`. |
| **Typehash** | The EIP-712 struct hash for one operation: `LIST_TYPEHASH`, `BUY_TYPEHASH`, `WITHDRAW_TYPEHASH`, `RENEW_TYPEHASH` in `ModifiersBase`. |
| **UUPS** | Universal Upgradeable Proxy Standard. The upgrade function lives in the implementation, gated here by `_authorizeUpgrade` and the `UPGRADER` role. |
| **ERC1967Proxy** | The proxy contract deployed in front of each implementation. Its address is the one users and the package refer to. |
| **Storage gap** | A reserved array in a base contract that lets it grow without shifting derived storage. None of this project's bases has one. |
| **Broadcast file** | `broadcast/deploy.s.sol/<chainId>/run-latest.json`, Foundry's record of a deployment. The Bun scripts read addresses from it. |
| **Soldeer** | Foundry's Solidity package manager. Dependencies land in `dependencies/` and are pinned in `soldeer.lock`. |
| **Fuji** | Avalanche's testnet, chain id 43113. Called `testnet` in most of the tooling and `staging` in the environment-based scripts. |
| **Anvil** | Foundry's local chain, chain id 31337. Called `local` throughout. |
