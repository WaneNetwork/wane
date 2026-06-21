# Changelog

All notable changes to Wane (contracts and SDK) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-06-09

### Added
- Base mainnet (chainid 8453) deployment of the full Wane stack: `WaneRegistry`, `WanePolicy`, `WaneDelegate`, and `WaneToken`.
- Genesis seeding: 652 antibodies written to `WaneRegistry` via `seedGenesis`, establishing the initial shared immune memory.
- `script/Deploy.s.sol` mainnet broadcast path and `script/SeedGenesis.s.sol` batched genesis import.
- Deployment manifest with the four canonical mainnet addresses, consumed by the SDK default config.

### Changed
- `wane-sdk` default chain switched from a testnet target to Base mainnet, with the deployed addresses baked into the shipped client.
- `seedGenesis` hardened to chunk large antibody batches under the block gas limit during the mainnet seed.

### Security
- Registry ownership transferred to the project multisig after genesis seeding completed.
- Mint, corroborate, challenge, and slash paths re-audited against the live policy wiring before launch.

## [0.3.0] - 2026-03-18

### Added
- `WaneDelegate`, the EIP-7702 delegate contract. An agent EOA delegates to it and routes calls through `execute` and `executeBatch`, each screened against `WanePolicy` before dispatch.
- `onlySelf` guard so only the delegating account can invoke privileged delegate entrypoints.
- `receive` and `fallback` handlers on the delegate to keep plain value transfers and unknown selectors working under delegation.
- `wouldAllow` view for off-chain simulation of a call without broadcasting.
- `wane-sdk` (TypeScript, viem peer dependency): typed clients for the registry, policy, and delegate, plus 7702 authorization helpers and call-screening utilities.
- SDK examples under `examples/` covering check, mint, enroll, and screened execution.

### Changed
- `WanePolicy.evaluateCall` signature aligned with the delegate screening flow so the same evaluation result is reused on-chain and in the SDK.

### Fixed
- Reason-code propagation so a blocked call surfaces the precise `WanePolicy` reason (`R_OK` through `R_TOKEN`) instead of a generic revert.

## [0.2.0] - 2025-12-04

### Added
- `WanePolicy`: per-agent scope enforcement with `enroll`, `setScope`, and `setPaused`.
- `evaluate` and `evaluateCall` views returning structured reason codes (`R_OK`, `R_PAUSED`, `R_SCOPE`, `R_TARGET`, `R_VALUE`, `R_SELECTOR`, `R_TOKEN`).
- `WaneTypes` shared structs and enums consumed by the policy and registry.

### Changed
- `WaneRegistry` now references policy state when resolving an antibody's applicable scope, decoupling antibody storage from per-agent enforcement.

### Fixed
- Edge case where an unenrolled agent evaluated as implicitly allowed; unenrolled agents now resolve to a paused-equivalent reason.

## [0.1.0] - 2025-09-22

### Added
- `WaneRegistry`: the antibody store with `check`, `mint`, `corroborate`, `challenge`, and `slash`, plus `antibodyCount` and the `seedGenesis` entrypoint.
- `WaneToken`: the `$WANE` ERC20 with a fixed 1,000,000,000 supply.
- Foundry project scaffold (`foundry.toml`, remappings) with the initial registry and token test suites under `test/`.
- `script/Deploy.s.sol` initial deploy script for registry and token.

[Unreleased]: https://github.com/WaneProtocol/wane-base/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/WaneProtocol/wane-base/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/WaneProtocol/wane-base/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/WaneProtocol/wane-base/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/WaneProtocol/wane-base/releases/tag/v0.1.0
