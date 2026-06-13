# Wane Roadmap

This roadmap reflects what is built, deployed, and verifiable on Base mainnet (chain id 8453). It lists shipped milestones only. There are no open items in this document; planning happens in GitHub issues.

## Status legend

All entries below are complete and live.

## Milestones

### Core registry
- [x] Antibody data model and storage layout (`WaneTypes`, `WaneRegistry`)
- [x] Mint flow: `check`, `mint` with stake escrow
- [x] Social verification: `corroborate` to strengthen an antibody
- [x] Dispute path: `challenge` and `slash` with stake redistribution
- [x] Read paths: `antibodyCount`, per-antibody lookups, status queries
- [x] Genesis bootstrap entrypoint: `seedGenesis`

### Staking and challenge economics
- [x] Stake escrow accounting tied to mint and challenge
- [x] Slash settlement that pays the prevailing party
- [x] Corroboration weighting that raises the cost to overturn an antibody
- [x] Token wiring against `WaneToken` for stake denomination

### Policy layer
- [x] Per-agent enrollment: `enroll`
- [x] Scope configuration: `setScope`, `setPaused`
- [x] Evaluation surface: `evaluate`, `evaluateCall`
- [x] Deterministic reason codes: `R_OK` through `R_TOKEN`

### EIP-7702 delegate
- [x] Self-authorized execution: `execute`, `executeBatch` with `onlySelf` guard
- [x] Policy screening on every routed call
- [x] Plain value transfers via `receive` and `fallback`
- [x] Dry-run check without state change: `wouldAllow`

### Token
- [x] `WaneToken` ERC20 with a fixed 1,000,000,000 supply
- [x] Deployed and verified on Base mainnet

### SDK
- [x] `wane-sdk` TypeScript package published on npm
- [x] viem-based clients for registry, policy, delegate, and token
- [x] Typed reads and writes against the live Base addresses
- [x] Runnable examples under `examples/`

### Base mainnet launch
- [x] `WaneRegistry` deployed at `0x027F371fB139A57EcD2A2E175d30157eEA1C56de`
- [x] `WanePolicy` deployed at `0x26deE4503C7f67356837ED41cE285026EF256667`
- [x] `WaneDelegate` deployed at `0x9175d735D512d730510148ED4D6702eF99CF4901`
- [x] `WaneToken` deployed at `0x1465E33f687C557BF275D6d692eC1316126d8e9e`
- [x] Source verification on BaseScan for all four contracts

### Genesis seeding
- [x] 652 genesis antibodies seeded into `WaneRegistry`
- [x] Seed script under `script/` for reproducible bootstrap
- [x] Post-seed read checks confirming `antibodyCount`

## Verification

Every address above is live on Base mainnet and can be inspected on BaseScan. The SDK reads and writes against these exact addresses with no test shims.

## Links

- Website: https://wane.network
- X: https://x.com/wanedotnetwork
- GitHub: https://wane.network/
- npm: https://www.npmjs.com/package/wane-sdk
