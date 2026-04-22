## Summary

<!-- Describe what this PR changes and why. Link any relevant issues with "Closes #123". -->



## Type of change

<!-- Mark all that apply with an "x". -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Smart contract change (modifies anything under `src/`)
- [ ] SDK change (modifies anything under `sdk/`)
- [ ] Documentation only (modifies `docs/`, `README.md`, or other markdown)
- [ ] Build, CI, or tooling change (`foundry.toml`, `.github/`, scripts)
- [ ] Refactor (no functional change)

## Testing

<!-- Describe how you verified the change. Paste relevant command output. -->

- [ ] `forge fmt --check` passes
- [ ] `forge build` passes
- [ ] `forge test` passes
- [ ] `cd sdk && npx tsc --noEmit` passes (if SDK changed)
- [ ] Added or updated tests covering the change

Commands run:

```
forge test

```

## Checklist

- [ ] My code follows the style of this project (`forge fmt`, existing SDK conventions)
- [ ] I have performed a self-review of my own changes
- [ ] I have commented my code where the intent is not obvious
- [ ] I have updated the documentation where needed
- [ ] My changes generate no new compiler warnings
- [ ] Contract changes preserve compatibility with the live Base mainnet deployments, or the PR explains the migration path
- [ ] I have not committed secrets, private keys, or `.env` files
- [ ] All commits are authored by a single account consistent with this repository's history
