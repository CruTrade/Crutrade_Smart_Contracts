# 07 — Payments and fees

`src/Payments.sol` is the only contract that moves ERC-20 value. It exposes two settlement entry
points to delegated callers, `splitServiceFee` for flat per-operation fees and `splitFees` for the
percentage fees on a sale, plus a relayed `send` for direct transfers. All percentages are basis
points against `BPS = 10000` declared in `src/abstracts/PaymentsBase.sol`.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Fee kinds

| Kind | Storage | Unit | Set by |
| --- | --- | --- | --- |
| Service fee | `_serviceFees[operation]` | absolute token amount | `setServiceFee(bytes32, uint256)` |
| Membership fee | `_membershipFees[id]` | basis points, seller and buyer | `setMembershipFees(id, sellerFee, buyerFee)` |
| Distribution fee | `_fees[]` | basis points of the total collected fee | `addFee` / `updateFee` / `removeFee` |
| Fiat surcharge | `_fiatFeePercentage` | basis points | `setFiatFeePercentage(uint256)` |

All four setters are `onlyRole(OWNER)`. `addFee` and `updateFee` reject a percentage above `BPS` and a
zero wallet, and re-check that the sum of `_fees[].percentage` stays at or below `BPS`, reverting with
`TotalPercentageExceedsLimit`.

## splitServiceFee

Called by `Sales` for each of `LIST`, `BUY`, `WITHDRAW` and `RENEW`.

1. `isFiat = (erc20 == address(0))`.
2. Token = the default fiat token if fiat, else `erc20`. Payer = the `FIAT` role holder if fiat, else
   the user.
3. `serviceFees = _serviceFees[operation]`; if fiat and non-zero,
   `fiatFees = serviceFees * _fiatFeePercentage / BPS`.
4. Both amounts are pulled with `safeTransferFrom(payer, _fees[0].wallet, amount)`.

If both amounts are zero the function returns without any transfer.

## splitFees

Called by `Sales.buy` with `from = buyer`, `to = seller`, `amount = price`.

```
memberships   = Memberships.getMemberships([from, to])
fromFee       = amount * _membershipFees[memberships[0]].sellerFee / BPS
toFee         = amount * _membershipFees[memberships[1]].buyerFee  / BPS
fees.fees     = copy of _fees[]
if isFiat: fees.serviceFee.fiatFees = amount * _fiatFeePercentage / BPS
```

Then `_processTransfers` executes, in order:

1. `safeTransferFrom(payer, to, amount - toFee)` — the seller receives the price minus the buyer-tier
   fee.
2. For each entry in `_fees`: `safeTransferFrom(payer, fee.wallet, (fromFee + toFee) * fee.percentage / BPS)`,
   skipping zero amounts.
3. `_processServiceFeeTransfers(token, payer, fees.serviceFee)` — the fiat surcharge, to `_fees[0].wallet`.

Every leg is pulled from the single payer. On a crypto sale that payer is the buyer, so the buyer must
have approved `Payments` for `amount - toFee + fromFee + toFee` (plus the separate `BUY` service fee
charged by the preceding `splitServiceFee` call). On a fiat sale the payer is the `FIAT` role holder
and the buyer contributes nothing on-chain.

### Naming caveat

The tier lookup is positional, not semantic. `fromFee` uses `sellerFee` from the **buyer's** tier and
`toFee` uses `buyerFee` from the **seller's** tier, because `splitFees` is invoked with the buyer as
`from`. Read `src/Payments.sol` before changing the tier tables.

## Fee distribution table

`_fees` is an array with a 1-based index map `_feeIndices` (0 means absent). `_fees[0]` is the treasury
entry pushed by `initialize` at 100 % (`10000` bps), and `_processServiceFeeTransfers` hardcodes
`_fees[0].wallet` as the destination of service and fiat fees. Consequences:

- Removing or reordering the treasury entry breaks service-fee routing.
- `_removeFee` swaps the last element into the removed slot, so removing any fee can move a different
  fee into position 0.
- `updateTreasuryAddress(address)` rewrites `_fees[_feeIndices[TREASURY] - 1].wallet` and emits
  `FeeUpdated`; use it rather than `removeFee` plus `addFee`.

## send

`Payments.send(nonce, expiry, signature, erc20, from, to, amount)` is an `OPERATIONAL`-relayed,
whitelist-gated, EIP-712-verified `safeTransferFrom`. The signed `dataHash` is
`keccak256(abi.encode(erc20, to, amount))`, which binds the token, recipient and amount but not the
sender. It rejects a zero token (`InvalidTokenAddress`) and zero endpoints (`ZeroAddress`), and emits
`Send(from, to, amount)`.

Unlike the split functions, `send` is not marked `whenNotPaused`.

## Configured values

Deployment defaults come from `script/payments-config.ts`. `script/deploy.ts` overrides
`treasuryAddress` with the treasury from `script/roles-config.ts` before passing it on.

| Environment | Fiat surcharge | Tier 0 seller/buyer | Tier 1 seller/buyer |
| --- | --- | --- | --- |
| local / dev | 300 bps | 600 / 400 | 100 / 100 |
| testnet / fuji | 300 bps | 0 / 0 | 150 / 500 |
| mainnet | 250 bps | 0 / 0 | 150 / 500 |

Service fees are not set at deployment. Nothing in `script/` calls `setServiceFee`, so `_serviceFees`
is zero for every operation until an owner sets it manually. `test/Crutrade.t.sol` sets them in its
fixture.

## Known defect

`Payments.initialize` contains `_fiatFeePercentage = _fiatFeePercentage;`. The parameter shadows the
storage variable, so the assignment is a no-op and the stored fiat surcharge is 0 after deployment
regardless of the configured value. It must be set afterwards with `setFiatFeePercentage`. See
`docs/19-tech-debt.md`.

## Events and errors

Events: `FeeAdded`, `FeeRemoved`, `FeeUpdated`, `FeesProcessed(transactionId, fees)`,
`FiatFeePercentageUpdated`, `MembershipFeesUpdated`, `Send`. `PaymentProcessed` is declared and never
emitted.

Errors: `FeeNotFound`, `DuplicateFee`, `TotalPercentageExceedsLimit`, `InvalidPercentage`,
`InvalidTokenAddress`. `TransferFailed`, `InsufficientPayment`, `InvalidPaymentToken` and
`PaymentFailed` are declared and never thrown.

## Open questions / unverified

- `_calculatePercentageFees` is wrapped in `unchecked`. With `amount` near `type(uint256).max` the
  multiplication would wrap silently. No caller passes an unbounded amount today, since `price` comes
  from a listing, but the guard is absent.
- There is no on-chain check that `fromFee + toFee` is fully distributed. If `_fees` percentages sum to
  less than `BPS`, the remainder is simply never pulled from the payer.
