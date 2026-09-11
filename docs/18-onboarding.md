# 18 — Onboarding

A working checkout, a green test suite and one trivial change, in about an hour. Then a map of where to
start reading for the change types that come up most often.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## First hour

### 1. Install (10 min)

```bash
git clone git@github.com:CruTrade/Crutrade_Smart_Contracts.git
cd Crutrade_Smart_Contracts
forge soldeer install     # Solidity deps into dependencies/
bun install               # JS deps into node_modules/
```

Foundry and Bun must already be installed. Verify with `forge --version` and `bun --version`.

### 2. Build and test (10 min)

```bash
forge build --via-ir
forge test
```

Expect 115 passing tests. The first build is slow because `via_ir` is on; later builds use `cache/`.

`npx tsc --noEmit` currently reports four errors across three files, all pre-existing and unrelated to
the contracts. See
`docs/19-tech-debt.md`.

### 3. Read the shape (15 min)

In this order:

1. `src/abstracts/ModifiersBase.sol` — the modifiers and the signature scheme every contract shares.
2. `src/Roles.sol` — how contracts find each other.
3. `src/abstracts/SalesBase.sol`, `_processSingleListing` and `_processSinglePurchase` — the two flows
   that tie the system together.

Then `docs/04-core-flows.md` for the diagrams.

### 4. Make a trivial change (15 min)

Add a view function to a contract and a test for it. For example, in `src/Sales.sol`, expose the
current sale counter:

```solidity
function getNextSaleId() external view returns (uint256) {
    return _nextSaleId;
}
```

Then a test in `test/Crutrade.t.sol`:

```solidity
function test_GetNextSaleId() public view {
    assertEq(sales.getNextSaleId(), 1);
}
```

Run `forge test --match-test test_GetNextSaleId -vv`. Revert the change afterwards, or keep it and
follow the change protocol in `AGENTS.md`: a `CHANGELOG.md` entry under `[Unreleased]` and a
Conventional Commit.

### 5. Run a local chain (10 min)

```bash
npm run anvil          # terminal 1
npm run deploy:local   # terminal 2
```

The deploy prints every proxy address and writes `broadcast/deploy.s.sol/31337/run-latest.json`, which
is what the Bun tooling reads.

## Where to start, by change type

### Add a new external function to a contract

Logic goes in the matching `src/abstracts/<Name>Base.sol` as an `internal` function; the external
wrapper with its modifiers goes in `src/<Name>.sol`. If the function is called by another contract in
the system, add it to the interface in `src/interfaces/`. Add a test. If the ABI changes, note it in
`CHANGELOG.md`; the next `npm run build` propagates it to `index.ts` and `types/`.

Reference: `Sales.getListingDelay` wrapping `ScheduleBase._getListingDelay`.

### Add or change state (the equivalent of a migration)

Read `docs/03-data-model.md` first. Append the variable to the most-derived contract, never to a base.
Run `forge inspect <Contract> storage-layout` before and after and confirm only new slots appear. Add a
`reinitializer(n)` function if the new state needs a value; do not touch `initialize`. Plan the upgrade
with `script/safe-upgrade-v1.5.0-oz-foundry.s.sol` as the template.

### Add a new role or permission

Declare the `keccak256('NAME')` constant in `src/abstracts/ModifiersBase.sol` next to the existing
ones, gate the function with `onlyRole(NAME)`, and add the grant to `script/deploy.s.sol`
`_grantContractRoles` and to the fixture in `test/Crutrade.t.sol`. If the new holder must move other
users' assets, it needs `grantDelegateRole` instead of, or in addition to, a role.

Reference: `docs/05-roles-access-control.md`.

### Add a new test

Everything lives in `test/Crutrade.t.sol`. Extend `setUp()` only if the whole suite needs the new
state; otherwise set it up inside the test. Naming and signature-construction patterns are in
`.claude/rules/tests.md`.

### Add a deployment or configuration script

Copy the shape of `script/set-wrapper-base-uri.ts`: a `#!/usr/bin/env bun` header, argument parsing
from `process.argv.slice(2)` with a usage block, address resolution from the Foundry broadcast file,
ABI from `out/`, key from `process.env.PRIVATE_KEY`, and `main().catch()` with `process.exit(1)`.
Prefer importing `getNetworkConfig` from `script/network-config.ts` over a new inline chain map.

### Change a fee or a schedule on a live deployment

No code change. Call `Payments.setServiceFee` / `setMembershipFees` / `setFiatFeePercentage`, or
`Sales.setSchedules` / `setDurations`, from an `OWNER` key. `script/configure-schedules.ts` wraps the
schedule case with a read mode and an interactive delete mode.

## Things that will surprise you

- A listing does not go live when it is created. `start` is the next scheduled drop window.
- Users never send transactions. A relayer with `OPERATIONAL` submits their signed intents.
- `erc20 == address(0)` means "fiat", and the platform's `FIAT` wallet pays the on-chain leg.
- Exporting a wrapper does not burn it, and does not check ownership.
- `index.ts` and `types/` are generated. Editing them by hand is lost on the next build.
- The `Payments` fiat fee percentage is 0 after a fresh deployment regardless of configuration; the
  initializer's assignment is a no-op.
