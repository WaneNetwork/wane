# Contributing to Wane

Thanks for your interest in Wane. This repository holds the smart contracts (Solidity, Foundry) and the TypeScript SDK (`wane-sdk`). There is no frontend here.

This guide covers how to set up the repository locally, build and test the contracts, build the SDK, and the conventions we follow for commits and pull requests.

## Prerequisites

Install the following before you start:

- Foundry (`forge`, `cast`, `anvil`). Install via `foundryup`. See https://book.getfoundry.sh for setup.
- Node.js 20 or newer, and a package manager (`npm`, `pnpm`, or `yarn`). The SDK targets viem as a peer dependency.
- Git.

Verify your toolchain:

```bash
forge --version
node --version
```

## Clone the repository

```bash
git clone https://github.com/WaneNetwork/wane.git
cd wane
```

Install Foundry library dependencies (OpenZeppelin, Uniswap v4-core, forge-std) declared in the repo:

```bash
forge install
```

## Build the contracts

```bash
forge build
```

The build must complete with no errors before you open a pull request. Formatting is enforced in CI, so run the formatter and check it locally:

```bash
forge fmt
forge fmt --check
```

## Run the tests

```bash
forge test
```

Useful variants while developing:

```bash
forge test -vvv                 # verbose traces for failing tests
forge test --match-test testMint   # run a single test by name
forge test --match-contract WaneRegistryTest   # run one test contract
forge snapshot                  # record gas snapshots
```

Any contract change must keep the existing tests green and add coverage for new behavior. Tests live under `test/` and follow Foundry conventions (`*.t.sol`, functions prefixed with `test`).

## Build the SDK

The SDK is a separate TypeScript package under `sdk/`.

```bash
cd sdk
npm install
npm run build
```

Type-check without emitting (this is what CI runs):

```bash
npx tsc --noEmit
```

If you change the public surface of the SDK, update the examples under `examples/` so they still compile and reflect the current API.

## Branching

Create a topic branch off `main` for your work:

```bash
git checkout -b fix/registry-challenge-window
```

Keep one logical change per branch. Rebase on the latest `main` before opening or updating a pull request rather than merging `main` into your branch.

## Commit conventions

We use Conventional Commits. Each commit message starts with a type, an optional scope, and a short imperative summary:

```
type(scope): summary
```

Allowed types:

- `feat` a new feature or capability
- `fix` a bug fix
- `docs` documentation only
- `test` adding or correcting tests
- `refactor` a code change that neither fixes a bug nor adds a feature
- `perf` a change that improves gas or runtime performance
- `chore` build, tooling, or housekeeping
- `ci` changes to CI configuration

Common scopes in this repository: `registry`, `policy`, `delegate`, `token`, `hook`, `sdk`, `script`, `docs`, `ci`.

Examples:

```
feat(policy): add per-selector scope evaluation in evaluateCall
fix(registry): correct slash accounting on a failed challenge
docs(sdk): document corroborate return shape
test(delegate): cover executeBatch revert on paused agent
```

Guidelines:

- Use the imperative mood ("add", not "added" or "adds").
- Keep the summary under about 72 characters.
- Put the why in the commit body when the change is not obvious.
- Reference issues in the body or footer, for example `Closes #123`.
- A breaking change is marked with `!` after the type or scope, for example `feat(sdk)!: rename wrap to attach`, and explained in the body.

## Pull requests

Before you open a pull request, confirm all of the following pass locally:

```bash
forge fmt --check
forge build
forge test
cd sdk && npx tsc --noEmit
```

When you open the pull request:

- Fill in the pull request template.
- Give it a clear title in the same Conventional Commits style as your commits.
- Describe what changed and why, and call out any change to deployed-contract behavior or to the SDK public API.
- Link the issue it addresses.
- Keep the diff focused. Unrelated cleanups belong in their own pull request.

A maintainer will review your change. CI runs `forge fmt --check`, `forge build`, and `tsc --noEmit` as required checks; some heavier checks run non-blocking. Address review feedback by pushing additional commits to the same branch. We squash on merge, so intermediate commits do not need to be perfect, but the final squashed title must follow the commit convention.

## Code style

### Solidity

- Target Solidity 0.8.27.
- Formatting is whatever `forge fmt` produces. Do not hand-format against it.
- Prefer custom errors over `require` strings.
- Use NatSpec (`/// @notice`, `/// @param`, `/// @return`) on external and public functions.
- Order within a contract: type declarations, state variables, events, errors, constructor, external, public, internal, private.
- Emit an event for every state change that off-chain consumers need to follow.
- Keep storage layout stable. Do not reorder or remove existing storage slots in deployed contracts; append new ones.
- Mark functions `external` over `public` when they are not called internally.

### TypeScript (SDK)

- Strict mode is on. Code must pass `tsc --noEmit` with no errors and no `any` escapes added to skirt the type checker.
- Use viem types for addresses, hashes, and ABI-derived values rather than bare strings where a typed value exists.
- Export public API from the package entry point only. Keep internal helpers unexported.
- Document exported functions and their return shapes with TSDoc comments.
- Match the existing formatting in the package; do not introduce a different style.

## Reporting bugs and requesting features

Use the issue templates under `.github/ISSUE_TEMPLATE`. For anything security-sensitive, do not open a public issue. Follow the disclosure process in `SECURITY.md` instead.

## License

By contributing, you agree that your contributions are licensed under the MIT License, the same license that covers this repository. See `LICENSE`.

## Links

- Website: https://wane.network
- X: https://x.com/wanedotnetwork
- GitHub: https://wane.network/
- npm: https://www.npmjs.com/package/wane-sdk
