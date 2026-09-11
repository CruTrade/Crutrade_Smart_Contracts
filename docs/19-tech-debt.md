# 19 — Technical debt

A factual inventory of defects, dead code, broken references and gaps found while reading the
repository. Nothing here was fixed. Each item names the file and, where useful, the line.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Defects

### Fiat fee percentage is never stored at deployment

`src/Payments.sol:55` inside `initialize`:

```solidity
_fiatFeePercentage = _fiatFeePercentage;
```

The parameter shadows the storage variable declared at `src/abstracts/PaymentsBase.sol:35`, so the
assignment is a no-op. Every deployment starts with a fiat surcharge of 0 regardless of
`FIAT_FEE_PERCENTAGE`. `setFiatFeePercentage` works correctly and must be called afterwards.

### Membership fees from configuration never reach the chain

`script/deploy.s.sol:_parseMembershipFees` takes the `MEMBERSHIP_FEES` JSON string, ignores it, and
returns a hardcoded pair (tier 0 at 600/400 bps, tier 1 at 100/100 bps). The comment acknowledges this.
The values in `script/payments-config.ts` for testnet and mainnet (0/0 and 150/500) are printed,
validated, exported as an env var, and discarded.

### `npm run deploy:testnet` cannot work as written

`package.json` maps it to `bun script/deploy.ts fuji`, but the `chainConfigs` map in
`script/deploy.ts:27` has only `local`, `testnet` and `mainnet`. The script exits 1 with
`Unknown network: fuji`. `script/deploy.s.sol:81` does understand `fuji`.

### Build order bundles a stale `index.ts`

`package.json` `build` runs `tsup` (step 2) before `update-package` (step 5), so `dist/` is built from
the previous `index.ts`. A single clean build publishes stale artifacts.

### Schedule seed off-by-one

`src/abstracts/ScheduleBase.sol:__ScheduleBase_init` writes the seed schedule to `_schedules[1]` but
sets `_scheduleCount = 2`, leaving an all-zero inactive `Schedule` at index 0. The scan skips it, so
behaviour is correct, but the comment says "One initial schedule" while the count says two.

### `_scheduleCount` only grows

`_deactivateSchedule` does not decrement it, and `_setSchedule` raises it to `max(id) + 1`. Setting a
schedule with a large id permanently increases the loop bound in `_getNextScheduleTime`, which runs on
every `list` and `renew`. The mainnet configuration in `script/configure-schedules.ts` uses id 16.

### `_fees[0]` is an implicit contract

`PaymentsBase._processServiceFeeTransfers` reads `_fees[0].wallet` as the treasury, while `_removeFee`
swaps the last element into a removed slot. Removing any fee can therefore move an unrelated wallet
into position 0 and silently redirect service fees.

### `Payments.send` is not pausable

Every other user-facing operation carries `whenNotPaused`; `src/Payments.sol:send` does not.

### `Wrappers.exports` does not verify ownership

`src/Wrappers.sol:exports` takes a `user` for the whitelist check and the event, then deactivates the
given ids in `WrapperBase._processSingleExport` without checking that `user` owns them.

### `unchecked` fee arithmetic

`PaymentsBase._calculatePercentageFees` performs `amount * percentage` inside `unchecked`. Callers pass
a listing price today, so no overflow is reachable, but the guard is gone.

### No storage gaps in any base contract

Confirmed with `forge inspect <Contract> storage-layout` for all eight contracts. Adding a variable to
`ModifiersBase`, `ScheduleBase` or any `*Base` shifts every slot below it in every deployed proxy.

## Broken references

| File | Missing target |
| --- | --- |
| `config.ts:4` | `./logging/logger` does not exist |
| `config.ts:12-19` | resolves artifacts under `../contracts/out`, outside this repository |
| `script/config.ts` | imports the above; also references `CruToken`, `CruClub`, `Vesting`, `Presale`, `Drops`, `Referrals`, none of which exist in `src/` |
| `script/run-fuji-upgrade.sh` | `script/fuji-storage-fix.s.sol`, `script/verify-fuji-fix.ts` |
| `script/run-custom-upgrade.sh` | `script/verify-v1.5.0-upgrade.ts` (named only in a closing echo, so the wrapper still succeeds) |
| `script/run-fuji-upgrade.sh` | documentation file `UPGRADE_MANAGEMENT_GUIDE.md` |
| `script/run-custom-upgrade.sh` | documentation file `SAFE_UPGRADE_V1.5.0_GUIDE.md` |
| `src/Wrappers.sol:13` | `@custom:oz-upgrades-from src/old/Wrappers.sol:Wrappers`; `src/old/` does not exist |

`npx tsc --noEmit` fails with four errors across three files: the missing logger above at `config.ts:4`
(TS2307), two `TS18046: 'error' is of type 'unknown'` at `script/init.ts:129`, and one `TS2322` type
mismatch at `script/fetch-wrapper-events.ts:637`. Treat this as the baseline; any additional error is new.

## Dead code

| Symbol | File | Note |
| --- | --- | --- |
| `checkFrontendSignature` modifier | `src/abstracts/ModifiersBase.sol` | never applied; the only user of `_usedHashes` |
| `_usedHashes` mapping | `src/abstracts/ModifiersBase.sol` | occupies slot 1 in seven contracts |
| `onlyAllowedBrand`, `onlyTokenOwner` | `src/abstracts/ModifiersBase.sol` | never applied |
| `LISTER`, `BUYER`, `RENEWER`, `WITHDRAWER` | `src/Sales.sol` | role constants nothing reads |
| `ListingCancelled`, `RenewCancelled` | `src/abstracts/SalesBase.sol` | events never emitted |
| `InvalidSaleDuration` | `src/abstracts/SalesBase.sol` | error never thrown |
| `PaymentProcessed` | `src/abstracts/PaymentsBase.sol` | event never emitted |
| `TransferFailed`, `InsufficientPayment`, `InvalidPaymentToken`, `PaymentFailed` | `src/abstracts/PaymentsBase.sol` | errors never thrown |
| `UnauthorizedTransfer`, `InvalidCollection` | `src/abstracts/WrapperBase.sol` | errors never thrown |
| `InvalidMembership` | `src/abstracts/MembershipsBase.sol` | error never thrown |
| `InvalidPermitSignature` | `src/USDCApprovalProxy.sol` | error never thrown |
| `HashAlreadyUsed`, `InvalidBrand` | `src/abstracts/ModifiersBase.sol` | errors never thrown |
| `_toString` | `src/abstracts/WrapperBase.sol` | hand-rolled uint-to-string, never called |
| `_setMembership` (singular) | `src/abstracts/MembershipsBase.sol` | never called; only the plural form is used |
| `_getRoleAddress`, `_getDefaultFiatPayment`, `_hasPaymentRole`, `_hasDelegateRole`, `_getTokenDecimals` | `src/abstracts/RolesBase.sol` | internal helpers the concrete contract bypasses |
| `_saveDeployment` | `script/deploy.s.sol` | commented out in full |
| `SALES` role | granted in `script/deploy.s.sol`, read by nothing |
| `USDCPROXY` role | granted in `test/Crutrade.t.sol`, exists in no contract |
| `WrapperData.uri`, `WrapperData.amount` | `src/interfaces/IWrappers.sol` | stored, never read |
| `Payment.decimals` | `src/interfaces/IRoles.sol` | stored by `setPayment`, never read |

## Duplicated logic

- Four near-identical signature modifiers in `src/abstracts/ModifiersBase.sol` (`checkListSignature`,
  `checkBuySignature`, `checkWithdrawSignature`, `checkRenewSignature`) repeat the same expiry, nonce,
  hash, recover, increment, emit sequence with a different struct hash.
- Three network/chain maps exist in parallel: `script/network-config.ts`, `script/deploy.ts:27` and
  `script/configure-schedules.ts:47`. Only the first is the designated shared module.
- Three upgrade scripts (`safe-upgrade-v1.5.0.s.sol`, `-custom`, `-oz-foundry`) target the same proxy
  with the same base URI and differ only in upgrade mechanism.
- Address resolution from the Foundry broadcast file is reimplemented in
  `script/create-deployments.ts`, `script/configure-usdc-proxy.ts` and `script/set-wrapper-base-uri.ts`,
  with different strategies: the first matches implementations to proxies by constructor argument, the
  second maps by deployment order against a hardcoded contract list.
- `Wrappers.setBaseURI` and `setHttpsBaseURI` are exact duplicates.

## Explicit TODOs

| Location | Text |
| --- | --- |
| `script/fetch-wrapper-events.ts:81` | `TODO: Replace with actual address` on the mainnet `Wrappers` address |
| `test/Crutrade.t.sol:3847` | `TODO: Fix the USDCApprovalProxy to handle failures gracefully` |

## Hardcoded values

- Anvil private keys in `script/deploy.ts:22-27`, `script/deploy.s.sol:40-45`,
  `script/network-config.ts:17` and `script/configure-schedules.ts:52`. These are the public Foundry
  test keys, but a misconfigured `NETWORK` would sign with a publicly known key.
- Every role address in `script/roles-config.ts` and every treasury in `script/payments-config.ts` is a
  literal, despite doc comments claiming environment-variable sourcing.
- Deployed proxy addresses hardcoded in `script/fuji-upgrade.s.sol`, the three `safe-upgrade-*` scripts,
  `script/set-wrapper-base-uri.ts`, `script/init.ts` and `script/fetch-wrapper-events.ts`.
- Base URIs hardcoded in `src/Wrappers.sol` (`https://cdn.crutrade.io/`) and `src/Brands.sol`
  (`https://metadata.crutrade.io/brands/`).
- `.env.example` ships a `PAYMENTS_CONTRACT` address that matches nothing in `index.ts` and is read by
  no code.
- `script/config.ts` gives the `roles` entry a `hex` value that is an ASCII string padded to 32 bytes,
  not a `keccak256` hash. The decoded text is crude Italian and should not remain in a published
  repository.

## Missing tests

Listed in `docs/16-testing.md`. The largest gaps: no upgrade test of any kind, no test for
`Payments.send`, none for `Wrappers.batchTransfer`, none for any `setRoles`, and no invariant tests.

## Tooling and process gaps

- No CI: no `.github/` directory and no pipeline configuration anywhere.
- No linter or formatter gate. `forge fmt --check` exits 1 on 30 of the 31 Solidity files (only
  `src/interfaces/IRoles.sol` is clean), so the repository
  has never been formatted with it; running `forge fmt` now would produce a whole-repo diff.
- No coverage reporting.
- `script/generate-artifacts.sh` appends bytecode after the ABI in the same file, producing invalid
  JSON. Its comments are in Italian while the rest of the codebase is in English. Nothing calls it.
- `deployments/` and `broadcast/` are gitignored, so deployment history exists only on the machine that
  ran the deploy, and `npm run clean` deletes `broadcast/`.

## Dependencies

Solidity dependencies are pinned exactly through soldeer: `forge-std` 1.9.7, `@openzeppelin-contracts`
5.0.1, `@openzeppelin-contracts-upgradeable` 5.0.1, all with checksums in `soldeer.lock`.
OpenZeppelin 5.0.1 was released in January 2024; later 5.x patch releases exist.

JavaScript dependencies use caret ranges (`^0.4.0`, `^1.44.1`, `^17.2.1`, `^6.15.0`, `^2.28.0` and the
dev set), so `bun install` without the lockfile can resolve differently. `bun.lock` is committed, which
mitigates this for developers but not for a fresh `npm install`, since `package-lock.json` is
gitignored.
