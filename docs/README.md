# CruTrade Smart Contracts — documentation

Chapter index for the contracts in `src/`, the deployment and operations scripts in `script/`, and the
published `@crutrade/contracts` npm package. Every chapter is grounded in code at the commit named in
its header; anything that could not be verified is listed under "Open questions / unverified" in the
chapter where it belongs.

Last verified against commit: 136615be21009eb2ea72a249527f07e2c1c61ab3

| Chapter | Summary |
| --- | --- |
| [01-overview.md](01-overview.md) | What the system does, the domain model and a high-level diagram. |
| [02-architecture.md](02-architecture.md) | Contracts, their boundaries, the proxy topology and how they find each other. |
| [03-data-model.md](03-data-model.md) | On-chain storage of every contract: slots, structs, relations, upgrade constraints. |
| [04-core-flows.md](04-core-flows.md) | Sequence diagrams for import, list, buy, withdraw, renew and permit. |
| [05-roles-access-control.md](05-roles-access-control.md) | The `Roles` hub, role hashes, delegation and the shared modifiers. |
| [06-sales-scheduling.md](06-sales-scheduling.md) | Listing lifecycle, weekly schedules, durations and pagination. |
| [07-payments-fees.md](07-payments-fees.md) | Fee model, membership tiers, fiat handling and transfer order. |
| [08-wrappers.md](08-wrappers.md) | The wrapper ERC-721, collections, import/export and metadata URIs. |
| [09-supporting-contracts.md](09-supporting-contracts.md) | Brands, Whitelist, Memberships, USDCApprovalProxy and MockUSDC. |
| [10-typescript-package.md](10-typescript-package.md) | What `@crutrade/contracts` exports and how the build generates it. |
| [11-api-reference.md](11-api-reference.md) | Every external function per contract: access, arguments, reverts. |
| [12-scripts-reference.md](12-scripts-reference.md) | Every deployment, configuration and utility script with its arguments. |
| [13-configuration.md](13-configuration.md) | Every environment variable and config constant, with the file that reads it. |
| [14-errors.md](14-errors.md) | Custom errors, where they originate and what triggers them. |
| [15-security.md](15-security.md) | Signature scheme, authorization model, secrets handling, and flagged concerns. |
| [16-testing.md](16-testing.md) | Test layout, fixtures, how to run, coverage gaps. |
| [17-operations.md](17-operations.md) | Deployment, upgrade, configuration runbooks and what is not implemented. |
| [18-onboarding.md](18-onboarding.md) | First hour: clone, build, test, make a change; where to start per change type. |
| [19-tech-debt.md](19-tech-debt.md) | Concrete defects, dead code, broken references and missing tests. |
| [20-glossary.md](20-glossary.md) | Domain and project-specific terms. |

Agent-facing instructions live in [`../AGENTS.md`](../AGENTS.md); the release log is
[`../CHANGELOG.md`](../CHANGELOG.md).
