# 16 — Testing

One Foundry suite covers the whole system: `test/Crutrade.t.sol`, 4319 lines, 115 tests, all passing at
the verified commit in roughly 240 ms. There are no TypeScript unit tests; `script/test-package.ts` is
a packaging smoke test, not a test suite. The Docker startup integration test described below is
separate from the Solidity suite.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Running

### Container validation

After `docker compose build`, run `docker compose run --rm test`. This disposable container has
`network_mode: none` and runs both `forge test --offline` and
`bun test docker/local-stack.test.ts`. The startup test creates its own local Anvil, verifies
all eight deployed proxies, restarts and checks unchanged addresses and deployer nonce, then
checks that an invalid persisted manifest exits non-zero and never reports ready. It owns `/data`
inside its disposable container; do not run it against a developer's persisted state volume.

The Docker image contains freshly installed dependencies and compiled contracts, never host caches
or secrets. Validation uses the host's native architecture; ARM64 results are not independent AMD64
release evidence. See `README.md` for the Docker setup.

Bun/TypeScript validation on 2026-09-11: the staged-only snapshot built with `oven/bun:latest`
(Bun 1.4.2, Debian 13, Linux ARM64), image
`sha256:8f0566cc046223b14aa8a6ea80ede70bd6b055e3a6482f3d4a46b9dbd0789b92`.
`forge test --offline -q` and `bun test docker/local-stack.test.ts` passed in a disposable
`--network none` container. `bunx --bun --no-install tsc --noEmit` returned only the three existing
diagnostics below, including the new Docker TypeScript files in its scope. The image's `node`
compatibility command is a symlink to Bun, not a separate Node.js runtime.

Historical Node-based image validation on 2026-09-11 (before the Bun-only runtime change):
a sanitized archive of the Git index (excluding the user's
unstaged `bun.lock` and `remappings.txt` changes) built successfully on Linux ARM64, Debian 12,
Foundry 1.2.1, Bun 1.4.2 and Node 26.8.2. The image ID was
`sha256:55cbef3099232f0769f99c9e3ce3b7d4d35cf2aeccce082fb16f1165bdfccc20`.
`forge test --offline` passed all 115 tests; `node --test docker/local-stack.test.mjs` passed its
deployment/restart/failure regression. Both ran under `docker run --rm --network none`.
`npx --no-install tsc --noEmit` exited 2 with the three existing diagnostics in `config.ts:4` and
`script/init.ts:129` (twice). Compose startup reached healthy and recreation retained all proxy
addresses with deployer nonce unchanged at 26. These are functional checks, not benchmarks.

### Native commands

```bash
forge test                                    # full suite
forge test --match-test test_ListingFlow -vv  # one test, preferred while iterating
forge test --match-test 'test_USDCApprovalProxy.*'
forge test --match-contract CrutradeEcosystemTest
forge test -vvvv                              # full traces
forge test --gas-report
```

`forge test` compiles with the default profile, which has `via_ir = true`, so the first run after a
clean is slow. Subsequent runs reuse `cache/`.

## Layout

| Contract in the file | Purpose |
| --- | --- |
| `MockERC20` | plain 18-decimal token used as both the crypto and the fiat token |
| `MockERC20Permit` | ERC-20 with a hand-rolled `permit`, used for the `USDCApprovalProxy` tests |
| `TestModifierContract` | bare `ModifiersBase` consumer, isolates the `onlyDelegatedRole` check |
| `CrutradeEcosystemTest` | the suite |

## Fixture

`setUp()` deploys the full stack in-process: two mock tokens, eight implementations, eight
`ERC1967Proxy` instances, then role grants, delegate flags, service fees and durations. Actors come
from fixed private keys so the same key can produce EIP-712 signatures:

| Actor | Key | Roles |
| --- | --- | --- |
| `admin` | `0x1` | `DEFAULT_ADMIN`, `OWNER`, `OPERATIONAL`, `TREASURY`, `FIAT`, `PAUSER` |
| `operational` | `0x2` | `OPERATIONAL` |
| `seller` | `0x3` | none |
| `buyer` | `0x4` | none |
| `treasury` | `0x5` | `TREASURY` |
| `feeReceiver` | `0x6` | none |

Fixture values that differ from production: mock tokens are registered with 18 decimals, service fees
are 10/5/2/8 tokens for `LIST`/`BUY`/`WITHDRAW`/`RENEW`, and durations 0/1/2 are 7/1/30 days.

## Coverage by area

| Area | Representative tests |
| --- | --- |
| Roles and primary addresses | `test_RolesSetup`, `test_SetPrimaryAddress*`, `test_GrantRole*`, `test_RevokeRole*` (16 tests) |
| Whitelist and memberships | `test_WhitelistManagement`, `test_MembershipManagement`, `test_SetMembershipsEventEmissions*` |
| Brands | `test_BrandManagement`, `test_SoulboundBrandTransfer` |
| Wrappers | `test_WrapperImportExport`, `test_WrapperExport*`, `test_SetBaseURI*`, `test_TokenURI_*` |
| Sales lifecycle | `test_ListingFlow`, `test_PurchaseFlow`, `test_WithdrawFlow`, `test_RenewFlow`, `test_CompleteEcosystemFlow` |
| Scheduling and durations | `test_ScheduleManagement`, `test_DurationManagement`, `test_ScheduleBasedListing`, `test_GetActiveSchedules`, `test_SetAndGetListingDelay` |
| Payments | `test_PaymentFeeCalculation`, `test_ComplexFeeScenarios`, `test_ConfigurablePayments*`, `test_UpdateTreasuryAddress*` |
| Signatures | `test_RevertOnInvalidSignature`, `test_RevertOnExpiredSignature`, `test_RevertOnWrongNonce`, `test_NonceIncrement`, `test_GetDomainSeparator` |
| Delegation | `test_OnlyDelegatedRole*` (3 tests, using `TestModifierContract`) |
| USDCApprovalProxy | `test_USDCApprovalProxy*`, `test_PermitUSDC*`, `test_PermitForPayments*` (18 tests) |
| Pausing | `test_PauseUnpause`, `test_UnauthorizedPause` |
| Fuzz | `testFuzz_MembershipAssignment`, `testFuzz_FeePercentages`, `testFuzz_SalePrice`, `testFuzz_BatchOperations`, `testFuzz_ScheduleTiming`, `testFuzz_DurationValues`, `test_SetMembershipsEventEmissionsFuzz` |

## Patterns in use

- `vm.prank` / `vm.startPrank` for role-gated calls; `vm.expectRevert` with the custom error selector
  for negative paths.
- `vm.warp` to cross schedule boundaries and sale expiry.
- `vm.expectEmit` where the event is the observable output, notably the membership and
  primary-address tests.
- `vm.assume` to bound fuzz inputs.
- Signatures built inline from the typehashes in `src/abstracts/ModifiersBase.sol` and the target's
  `getDomainSeparator()`.

## Coverage gaps

Verified by searching the suite for the relevant symbols:

- **`Payments.send`** has no test. The only use of `checkSignatureEIP712` is untested.
- **`Wrappers.batchTransfer`** has no test, including the `OWNER`-primary-address sourcing.
- **`Wrappers.setRoles`, `Whitelist.setRoles`, `Memberships.setRoles`, `Brands.setRoles`** are untested.
- **`Roles.setPayment` / `setDefaultFiatToken` failure paths** are exercised only indirectly.
- **Upgrades are not tested.** No test calls `upgradeToAndCall` or checks `_authorizeUpgrade`, and no
  test validates a storage layout across versions. This is the highest-risk gap given the UUPS design.
- **`Payments.removeFee` reindexing** is not asserted. The function is called once, in
  `test_DuplicateFeeAddition` at `test/Crutrade.t.sol:1305`, purely to free up percentage headroom;
  no test checks the swap-and-pop or what ends up in `_fees[0]`.
- **Fiat settlement** is covered by `test_FiatPaymentFlow` only; the interaction between the fiat
  surcharge and service fees on a real purchase is not asserted.
- **No invariant or differential tests.** `StdInvariant` is compiled into `out/` through forge-std but
  no test contract extends it.
- **No coverage report is produced.** `forge coverage` is not wired into any script or CI.

`test/Crutrade.t.sol:3847` carries a `TODO: Fix the USDCApprovalProxy to handle failures gracefully`,
marking a behaviour the suite documents rather than asserts.

## Continuous integration

There is no CI. No `.github/`, no workflow file, no pipeline configuration of any kind exists in the
repository. Tests run only when a developer runs them.
