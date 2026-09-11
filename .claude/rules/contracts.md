---
paths:
  - "src/**/*.sol"
---

# Rules for `src/**/*.sol`

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

## Upgrade safety

The eight concrete contracts in `src/` (everything except `src/abstracts/`, `src/interfaces/` and
`src/mock/MockUSDC.sol`) sit behind ERC1967 UUPS proxies. Seven are live on both Avalanche mainnet and
Fuji; `USDCApprovalProxy` is live on Fuji only, and its mainnet entry in `index.ts` is the zero
address. Treat all of them as deployed.

- Never reorder, retype, rename or remove an existing state variable.
- Never add a state variable to an abstract base (`src/abstracts/*.sol`). No base declares a `__gap`,
  so an insertion shifts every slot below it. Append to the most-derived contract instead.
- Confirm the layout after any storage change: `forge inspect <Contract> storage-layout`.
- Keep `constructor() { _disableInitializers(); }` and the `initializer` modifier on `initialize`.
  New init logic belongs in a `reinitializer(n)` function, never in the existing `initialize`.
- `_authorizeUpgrade` must stay gated by `onlyRole(UPGRADER)` and must keep rejecting a zero
  implementation. Seven contracts express that as `onlyRole(UPGRADER) checkAddressZero(newImplementation)`.
  `src/Roles.sol:189` deliberately differs: it is `internal view override onlyRole(UPGRADER)` with an
  explicit `if (newImplementation == address(0)) revert InvalidContract(newImplementation);`, because
  `Roles` does not inherit `ModifiersBase`. Do not "harmonize" it; that would change the upgrade gate
  and the revert type of the live hub contract.

## Structure

- Logic in `src/abstracts/<Name>Base.sol` as `internal` functions, external surface in `src/<Name>.sol`.
- Shared structs live in `src/interfaces/I<Name>.sol`. Import them; do not redeclare.
- Cross-contract references resolve at call time via `roles.getRoleAddress(<ROLE_CONSTANT>)`, never via
  a stored peer address (except `USDCApprovalProxy`, which deliberately stores `usdcToken` and
  `paymentsContract`).

## Access control and safety

- Gate every state-changing external function with a modifier from `src/abstracts/ModifiersBase.sol`.
- Apply `whenNotPaused` to user-facing operations, and `nonReentrant` where value or NFTs move
  (see `src/Sales.sol`).
- Follow checks-effects-interactions: write storage before any external call, as in
  `SalesBase._processSinglePurchase`.
- Declare a custom error rather than a revert string. Errors belong next to the contract that reverts.
- Use `SafeERC20` for all ERC-20 movement.

## Do not

- Do not run `forge fmt`; it currently rewrites every file in the repo.
- Do not widen the `pragma solidity 0.8.30;` pin.
- Do not add `payable` entry points. The system is ERC-20-only; there is no native-token path.
