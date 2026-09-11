# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

- `README.md`: add Docker and native onboarding, marketplace prerequisites, package generation,
  remote deployment constraints and contributor/agent workflow.
- `README.md`: corrected the install command to the published package name `@crutrade/contracts`,
  added `USDCApprovalProxy` to the contract table, documented the local development commands and
  linked the new documentation.

## [1.5.0]

Released as npm package version `1.5.0` (`package.json`). No changelog was kept before this entry;
see the git history for changes up to and including that release.
