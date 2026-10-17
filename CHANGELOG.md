# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


### Added

- Makefile: shortcuts for Docker startup, logs, proxy addresses, tests, typechecking and explicit local-state reset.
- Docker local environment: pinned toolchain image, automatic Anvil deployment, persistent local
  state, proxy address manifest and an offline test service.
- Repository documentation set under `docs/`: architecture, data model, core flows, per-module
  chapters, API and script references, configuration, errors, security, testing, operations,
  onboarding, tech debt and glossary.
- `AGENTS.md` with the dev environment, testing commands, conventions, boundaries and the change
  protocol that applies to every change in this repository.
- `CLAUDE.md` and scoped rule files in `.claude/rules/` for contracts, scripts, tests and the
  published npm package.
- This changelog.

### Changed

- Docker local environment: explicitly build and run all development and offline test services as native `linux/arm64` on Apple Silicon.

- Docker local toolchain: pin Foundry/Anvil 1.8.5 and Bun 1.4.3 by immutable image digests while retaining Solidity 0.8.30 and native ARM64 development services.
- Docker: use Bun and TypeScript for startup and lifecycle tests, removing the Node.js runtime.
- `README.md`: add Docker and native onboarding, marketplace prerequisites, package generation,
  remote deployment constraints and contributor/agent workflow.
- `README.md`: corrected the install command to the published package name `@crutrade/contracts`,
  added `USDCApprovalProxy` to the contract table, documented the local development commands and
  linked the new documentation.

### Fixed

- Local Docker toolchain: force recompilation of deployment scripts after Solidity edits so cached scripts cannot install an older implementation.

- Payments: apply the buyer's buying rate and seller's selling rate when settling purchases, preserving the public ABI and existing fiat payer/surcharge behavior.

- Wrappers validates the current owner when an export executes, preventing a stale request from deactivating another user's wrapper and preserving atomic batch rollback.

- Deployment script: omit empty optional arguments so local deployment works with current Foundry releases.

## [1.5.0]

Released as npm package version `1.5.0` (`package.json`). No changelog was kept before this entry;
see the git history for changes up to and including that release.
