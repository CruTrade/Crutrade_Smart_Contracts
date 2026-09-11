# 04 — Core flows

Every user-facing operation follows the same shape: the user signs an EIP-712 payload off-chain, a
backend account holding the `OPERATIONAL` role submits it, the contract verifies the signature against
the user's current nonce, then executes. The user never sends a transaction and never pays gas. This
chapter traces the five flows that move value or custody.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Common preconditions

For `list`, `buy`, `withdraw` and `renew` in `src/Sales.sol`, all of these must hold:

| Check | Modifier / code | Failure |
| --- | --- | --- |
| Contract not paused | `whenNotPaused` | `EnforcedPause` |
| No re-entry | `nonReentrant` | `ReentrancyGuardReentrantCall` |
| Caller is the relayer | `onlyRole(OPERATIONAL)` | `NotAllowed(role, account)` |
| User is whitelisted | `onlyWhitelisted(wallet)` | `NotWhitelisted(wallet)` |
| Signature not expired | `block.timestamp > expiry` | `SignatureExpired(expiry, current)` |
| Nonce matches | `nonce != _nonces[wallet]` | `InvalidNonce(expected, provided)` |
| Signature recovers to the user | `ECDSA.recover` | `InvalidSignature(expected, actual)` |

On success the modifier increments `_nonces[wallet]` and emits `NonceUsed`.

## Import: minting a wrapper

```mermaid
sequenceDiagram
    participant Op as Relayer (OPERATIONAL)
    participant W as Wrappers
    Op->>W: imports(user, WrapperData[])
    W->>W: onlyWhitelisted(user), checkAddressZero(user)
    loop per wrapper
        W->>W: require !wrapper.active else InvalidToken
        W->>W: wrapperId = _nextWrapperId++
        W->>W: store WrapperData, add to _wrappersByCollection
        W->>W: _safeMint(user, wrapperId)
    end
    W-->>Op: emit Import(user, ImportOutput[])
```

`exports` is the inverse: it flips `active` to false and removes the id from the collection index, but
it does **not** burn the token. The holder keeps the ERC-721 after export.

## List: putting a wrapper on sale

```mermaid
sequenceDiagram
    participant Seller
    participant Op as Relayer
    participant S as Sales
    participant W as Wrappers
    participant P as Payments

    Seller->>Seller: sign CrutradeListMessage (EIP-712)
    Op->>S: list(seller, nonce, expiry, sig, wrapperId, directSaleId, isFiat, price, expireType, erc20)
    S->>S: verify signature + nonce
    S->>S: getNextScheduleTime()
    S->>S: validate price != 0 and durationId
    S->>W: getWrapperData(wrapperId) -> collection
    S->>W: ownerOf(wrapperId) must equal seller
    S->>S: write Sale{start, end, active:true}, index by collection and seller
    S->>P: splitServiceFee(LIST, seller, erc20)
    P->>P: transfer LIST service fee to treasury
    S->>W: marketplaceTransfer(seller, Sales, wrapperId)
    S-->>Op: emit List(seller, saleId, date, fee, output)
```

`start` is the next scheduled drop time, not `block.timestamp`, so a listing is dormant until the
window opens. `end` is `start + _durations[expireType]`.

## Buy: settling a sale

```mermaid
sequenceDiagram
    participant Buyer
    participant Op as Relayer
    participant S as Sales
    participant P as Payments
    participant M as Memberships
    participant W as Wrappers
    participant T as ERC-20

    Buyer->>Buyer: sign CrutradeBuyMessage
    Op->>S: buy(buyer, nonce, expiry, sig, directSaleId, saleId, isFiat, erc20)
    S->>S: sale exists, active, started, not expired
    S->>S: seller still whitelisted
    S->>S: active = false, drop from both indexes
    S->>P: splitServiceFee(BUY, buyer, erc20)
    S->>P: splitFees(erc20, saleId, buyer, seller, price)
    P->>M: getMemberships([buyer, seller])
    P->>P: fromFee = price * sellerFee(buyer tier) / 10000
    P->>P: toFee = price * buyerFee(seller tier) / 10000
    P->>T: safeTransferFrom(payer, seller, price - toFee)
    loop each configured Fee
        P->>T: safeTransferFrom(payer, fee.wallet, (fromFee+toFee) * fee.percentage / 10000)
    end
    P->>T: service and fiat fees to _fees[0].wallet
    S->>W: marketplaceTransfer(Sales, buyer, wrapperId)
    S-->>Op: emit Buy(buyer, saleId, fees)
```

Note the argument order in `Payments.splitFees`: `from` is the buyer and `to` is the seller, so
`fromMembershipFees.sellerFee` is looked up from the **buyer's** tier and `toMembershipFees.buyerFee`
from the **seller's** tier (`src/Payments.sol`, `splitFees`). The buyer must have approved `Payments`
for `price - toFee` plus all fee transfers before the call.

## Withdraw and renew

`withdraw` cancels an active, started, unexpired sale for its own seller: it flips `active` to false,
removes both index entries, deletes the sale record, charges the `WITHDRAW` service fee and returns the
wrapper from `Sales` to the seller.

`renew` moves an **expired** sale to the next drop window. It requires `block.timestamp >= sale.end`
(`SaleNotExpired` otherwise), charges the `RENEW` service fee, and rewrites `start` to the next
schedule time and `end` to `start + (old end - old start)`, preserving the original duration. The
wrapper stays in `Sales` custody and the indexes are untouched.

## Fiat path

Passing `erc20 == address(0)` marks a fiat-settled operation:

1. `Payments` substitutes `roles.getDefaultFiatPayment()` as the token to move.
2. The payer becomes `roles.getRoleAddress(FIAT)` instead of the user, so the platform's fiat account
   funds the on-chain leg.
3. `splitServiceFee` adds `serviceFees * _fiatFeePercentage / 10000` as `fiatFees`, and `splitFees`
   adds `amount * _fiatFeePercentage / 10000`, both transferred to `_fees[0].wallet`.

The `onlyValidPayment` modifier explicitly allows `address(0)` through; any other token must be
registered with `Roles.setPayment`.

## Permit forwarding

```mermaid
sequenceDiagram
    participant User
    participant Caller as Anyone
    participant Proxy as USDCApprovalProxy
    participant USDC

    User->>User: sign ERC-2612 permit for spender = Payments
    Caller->>Proxy: permitForPayments(owner, value, deadline, v, r, s)
    Proxy->>Proxy: paymentsContract != 0, block.timestamp <= deadline
    Proxy->>Proxy: this.permitUSDC(owner, paymentsContract, ...)
    Proxy->>USDC: permit(owner, spender, value, deadline, v, r, s)
    Proxy-->>Caller: emit USDCPermitForwarded(owner, spender, value, true)
```

`permitUSDC` and `permitForPayments` carry no access-control modifier: anyone may submit a permit, which
is standard for ERC-2612 relays since the signature itself is the authorization.

## Open questions / unverified

- `directSaleId` is part of every signed payload and every function signature in `Sales`, but is never
  stored, validated or emitted. Its purpose is presumably off-chain correlation; nothing in this
  repository confirms that.
- `isFiat` is part of the signed payload but the contract derives the fiat path solely from
  `erc20 == address(0)`. A signature could therefore claim `isFiat = true` while the relayer passes a
  real token address, and nothing rejects the mismatch.
