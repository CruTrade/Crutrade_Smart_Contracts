# 15 — Security

The trust model is deliberately centralized: a backend relayer holding `OPERATIONAL` submits every user
action, a multisig holds `OWNER`, `PAUSER` and `UPGRADER`, and every participant must be whitelisted.
User intent is proven by an EIP-712 signature verified on-chain. This chapter states the model as
implemented and flags the places where the implementation is weaker than the design implies.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Authentication

Off-chain user signatures are verified by the modifiers in `src/abstracts/ModifiersBase.sol`:

- **Domain separation.** Each contract computes its own EIP-712 domain separator at initialization over
  `name`, `version` `"1"`, `block.chainid` and `address(this)`. A signature is bound to one contract on
  one chain. Domain names differ per contract (`Crutrade Sales`, `Crutrade Payments`, and so on).
- **Function binding.** Every typed struct hash includes the function selector, so a `list` signature
  cannot be replayed against `renew`.
- **Replay protection.** A monotonic per-user nonce is required to equal `_nonces[wallet]` exactly, and
  is incremented on success. Signatures cannot be reordered or reused.
- **Expiry.** `block.timestamp > expiry` reverts. Expiry is chosen by the signer.
- **Recovery.** `ECDSA.recover` from OpenZeppelin v5, which rejects malleable and zero-address
  recoveries.

## Authorization

Role checks route through the `Roles` contract (`docs/05-roles-access-control.md`). Three functions are
gated by the separate delegation flag rather than a role, because they act on assets the caller does not
own: `Wrappers.marketplaceTransfer`, `Payments.splitFees`, `Payments.splitServiceFee`.

Privilege concentration as configured in `script/roles-config.ts`:

| Environment | Addresses holding OWNER, PAUSER, UPGRADER, TREASURY |
| --- | --- |
| mainnet | one multisig, `0xE8c2…45E9` |
| testnet | one EOA, `0x45a0…8cfb` |
| local | one Anvil account |

`checkSecurityIssues` in `script/roles-config.ts` warns about this at deploy time but does not block.
`Roles.initialize` grants all six user roles to the single `defaultAdmin`.

## Input validation

- Zero-address checks on every constructor-equivalent argument and on upgrade targets.
- Percentage bounds: every fee setter rejects values above `BPS` and re-checks the total.
- Range checks on schedules (day 1-7, hour < 24, minute < 60) and durations (0 < d <= 365 days).
- Existence sentinels: `collection == bytes32(0)` for wrappers, `seller == address(0)` for sales,
  1-based indices in the `Payments` fee table.
- Array-length equality is enforced in the batch setters on `Sales`.

## Re-entrancy and ordering

`Sales` is the only contract with external value movement triggered by user input; all four entry
points are `nonReentrant` and follow checks-effects-interactions. `_processSinglePurchase` deactivates
the sale and removes both index entries before calling `Payments` or `Wrappers`.
`Payments` is not itself `nonReentrant`, but it is only reachable from `Sales` through the delegation
gate, which is already guarded.

## Pausing

`PAUSER` can halt every contract. `Wrappers` and `Brands` additionally block all ERC-721 movement while
paused, through the overridden `_update`.

## Secrets handling

- `.env` is gitignored (`.gitignore` lists `.env` and `.env.*` with an exception for `.env.example`)
  and `git ls-files` confirms only `.env.example` is tracked.
- Scripts read signing material exclusively from `process.env.PRIVATE_KEY` or `vm.envUint("PRIVATE_KEY")`.
- Hardcoded private keys exist only for local development: the three well-known public Anvil keys, in
  `script/deploy.ts`, `script/deploy.s.sol`, `script/network-config.ts` and
  `script/configure-schedules.ts`. They control no real funds but their presence means a misconfigured
  `NETWORK` could sign with a publicly known key.
- No contract logs a secret. Event payloads carry addresses, ids and amounts only.
- The Bun scripts print addresses and transaction hashes to stdout. `script/init.ts` logs truncated
  addresses; nothing logs a key.

## Flagged concerns

These are observations about the code as written, not exploit claims.

1. **`isFiat` is not bound to the settlement path.** The flag is inside the signed payload, but
   `Payments` decides the fiat path purely from `erc20 == address(0)`, which the relayer supplies
   outside the signature. A relayer can settle a signature marked `isFiat = true` against a real token,
   or the reverse, and nothing reverts. `src/Sales.sol`, all four entry points.
2. **`erc20` is not part of any signed payload.** The token address is a plain argument on `list`,
   `buy`, `withdraw` and `renew`. Its only constraint is `onlyValidPayment` inside `Payments`, so a
   relayer chooses which registered token the user pays in.
3. **`price` is not re-verified at purchase.** `buy` settles at the stored listing price; that is
   intended, but the buyer's signature covers only `saleId`, not the amount they will pay.
4. **`_fees[0]` is load-bearing.** `_processServiceFeeTransfers` sends service and fiat fees to
   `_fees[0].wallet`. `_removeFee` swaps the last element into the removed slot, so removing any fee can
   move an unrelated wallet into position 0.
5. **Unbounded loops in views.** `getSalesByCollection`, `getCollectionData` and `getActiveSchedules`
   materialize whole sets. `_getNextScheduleTime` scans `0.._scheduleCount`, and `_scheduleCount` only
   grows. A large schedule id set once makes every `list` and `renew` more expensive forever.
6. **`unchecked` fee arithmetic.** `_calculatePercentageFees` multiplies inside `unchecked`. Current
   callers pass a listing price, but the overflow guard is absent.
7. **No storage gaps.** Any variable added to an abstract base shifts the layout of live proxies.
8. **`Payments.send` is not pausable.** Every other user-facing operation is `whenNotPaused`.
9. **`Wrappers.exports` does not verify ownership.** It takes a `user` argument for the whitelist check
   and the event, but deactivates the given ids regardless of who owns them.
10. **Permit relays are permissionless by design.** `permitUSDC` and `permitForPayments` accept any
    caller; the ERC-2612 signature is the authorization. Worth noting because the contract name suggests
    otherwise.

## Not implemented

No rate limiting, no CORS or network-layer controls (there is no server in this repository), no circuit
breaker beyond `pause`, no timelock on upgrades, and no on-chain multisig contract; the multisig is an
external address.

## Open questions / unverified

- Whether a professional audit has been performed. No audit report, no `audits/` directory and no
  reference to one exists in this repository. The contracts carry
  `@custom:security-contact security@crutrade.io`.
- Whether the mainnet `OWNER` address is in fact a multisig. `script/roles-config.ts` labels it
  `MAINNET_MULTISIG`; that cannot be confirmed from this repository.
