# 06 — Sales and scheduling

`src/Sales.sol` is the marketplace entry point and the only contract that holds user assets in
custody. Its distinguishing feature is that listings do not go live immediately: a listing's `start`
is the next occurrence of a configured weekly drop window, computed at listing time by
`src/abstracts/ScheduleBase.sol`. Sale lengths come from a separate table of named durations.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Sale lifecycle

| State | `active` | Timing | Reachable operations |
| --- | --- | --- | --- |
| Upcoming | `true` | `block.timestamp < start` | `withdraw` reverts `SaleNotStarted`; `buy` reverts `SaleNotStarted` |
| Live | `true` | `start <= now <= end` | `buy`, `withdraw` |
| Expired | `true` | `now > end` | `renew` |
| Sold | `false` | — | none; record retained |
| Withdrawn | record deleted | — | none |

`_processSingleRenewal` requires `block.timestamp >= sale.end`, so a live sale cannot be renewed
(`SaleNotExpired`). `withdraw` requires the sale to be live, so an expired listing cannot be withdrawn
directly; it must be renewed first. The only exit from an expired listing is renewal.

## Scheduling

A `Schedule` is `{ dayOfWeek (1-7, Monday-Sunday), hour (0-23), minute (0-59), isActive }`, stored by id.

`_getNextScheduleTime` scans ids `0 .. _scheduleCount - 1`, computes the next occurrence of each active
schedule with `_getNextOccurrence`, and returns the earliest. If no schedule is active it returns
`block.timestamp + _listingDelay`. All arithmetic is UTC: `_getNextOccurrence` derives the weekday with
`((timestamp / 86400 + 3) % 7) + 1` and rounds down to midnight UTC before adding the target
hour and minute. If today is the target day and the time has already passed, it rolls forward a week.

Configuration is `OWNER`-gated:

| Function | Effect |
| --- | --- |
| `setSchedules(ids[], days[], hours[], minutes[])` | upsert; reverts `InvalidSaleOperation` on empty input or length mismatch, and `require`s valid ranges |
| `removeSchedules(ids[])` | sets `isActive = false`; `require`s the id to be below `_scheduleCount` |
| `setListingDelay(seconds)` | fallback delay; rejects more than 365 days with `InvalidListingDelay` |

`setSchedules` grows `_scheduleCount` to `max(id) + 1`, so using a large id makes the scan in
`_getNextScheduleTime` iterate over that whole range on every `list` and `renew` call. Gaps are cheap
per iteration but not free.

`_deactivateSchedule` never decrements `_scheduleCount`, so removing schedules does not shrink the scan.

### Initialization quirk

`__ScheduleBase_init` writes the seed schedule to `_schedules[1]` (Saturday 15:30 UTC) but sets
`_scheduleCount = 2`. Slot 0 is left as an all-zero, inactive `Schedule`, which the scan skips. The
comment says "One initial schedule" while the count implies two. The behaviour is correct but the
off-by-one is real; see `docs/19-tech-debt.md`.

## Durations

`_durations[id]` maps a duration id to seconds. `__SalesBase_init` seeds `_durations[0] = 56 days`.
`setDurations(ids[], values[])` is `OWNER`-gated and enforces `0 < duration <= 365 days` with `require`
strings. `_maxDurationId` tracks the highest id ever set and bounds both `getDuration` and the
`expireType` validation in `_processSingleListing`, which rejects an unset id with
`InvalidDurationId`.

## Views and pagination

| Function | Returns |
| --- | --- |
| `getSale(saleId)` | the `Sale`; reverts `SaleNotFound` if the seller is zero |
| `getSalesByCollection(collection)` | all sales for a collection, unbounded |
| `getSalesByCollectionPaginated(collection, offset, limit)` | page plus total |
| `getSalesBySellerPaginated(seller, offset, limit)` | sale ids plus total |
| `getAllDurationsPaginated(offset, limit)` | ids, values, total (`_maxDurationId + 1`) |
| `getActiveSchedules()` | parallel arrays of ids, days, hours, minutes, unbounded |
| `getNextScheduleTime()`, `getListingDelay()`, `getSchedule(id)`, `getDuration(id)` | scalars |

`getSalesByCollection` and `getActiveSchedules` have no upper bound and materialize the whole set; both
call `EnumerableSet.values()` or scan `_scheduleCount`. Prefer the paginated variants from off-chain
code on large collections.

## Custody and re-entrancy

Between `list` and `buy`/`withdraw`, the wrapper is owned by the `Sales` proxy itself. Transfers use
`WrapperBase._marketplaceTransfer`, which calls `_update` directly rather than `_safeTransfer`, so no
`onERC721Received` callback is made and `Sales` does not need to implement `IERC721Receiver`.

All four entry points are `nonReentrant` and write their state before calling `Payments` or `Wrappers`.

## Events

| Event | Emitted by |
| --- | --- |
| `List(wallet, salesId, date, fee, output)` | `list` |
| `Buy(wallet, salesId, fees)` | `buy` |
| `Withdraw(wallet, salesId, fee)` | `withdraw` |
| `Renew(wallet, salesId, date, fee)` | `renew` |
| `DurationSet(durationId, duration)` | `_setDuration` |
| `ScheduleSet`, `ScheduleRemoved`, `ListingDelayUpdated` | `ScheduleBase` |

`ListingCancelled` and `RenewCancelled` are declared in `src/abstracts/SalesBase.sol` and never emitted.

## Open questions / unverified

- Nothing enforces that a listed wrapper is `active` in the `Wrappers` contract. A wrapper that was
  exported (`active == false`) can still be listed, since `_processSingleListing` only reads its
  `collection` and checks ERC-721 ownership.
- `renew` preserves the original `end - start` duration and ignores the `expireType` in the signed
  payload, so the argument has no effect on the resulting sale length.
