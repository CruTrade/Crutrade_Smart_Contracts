---
paths:
  - "test/**/*.sol"
---

# Rules for `test/**/*.sol`

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

All tests live in one suite: `test/Crutrade.t.sol`, contract `CrutradeEcosystemTest`.

## Fixture

`setUp()` deploys the whole ecosystem in-process: two `MockERC20` tokens, every implementation, then
an `ERC1967Proxy` per contract, then role grants, service fees and three sale durations. Actors are
derived with `vm.addr(k)` from fixed keys so the same key can sign EIP-712 payloads:

| Actor | Key |
| --- | --- |
| `admin` | `0x1` |
| `operational` | `0x2` |
| `seller` | `0x3` |
| `buyer` | `0x4` |
| `treasury` | `0x5` |
| `feeReceiver` | `0x6` |

Extend `setUp()` rather than re-deploying the stack inside a test, unless the test specifically needs a
different initialization (see the `test_ConfigurablePayments*` tests, which deploy their own `Payments`).

## Naming

- `test_<Behaviour>` for happy paths and state assertions.
- `test_RevertOn<Condition>` for negative paths, paired with `vm.expectRevert`.
- `testFuzz_<Subject>` for fuzzed inputs, with `vm.assume` to discard invalid ranges.

## Writing a test

- Use `vm.prank(operational)` for the relayed entry points; `list`, `buy`, `withdraw` and `renew` all
  require the `OPERATIONAL` role plus a valid user signature.
- Build signatures with the EIP-712 typehashes from `src/abstracts/ModifiersBase.sol` and the domain
  separator of the target contract (`getDomainSeparator()`); the domain name differs per contract.
- Read the current nonce with `getNonce(user)` before signing. Each verified signature increments it.
- Advance time with `vm.warp` when exercising schedules, sale start, expiry or renewal.
- Assert on emitted events with `vm.expectEmit` where the event is the contract's observable output,
  as the membership and primary-address tests do.

Run a single test while iterating: `forge test --match-test <name> -vv`.
