---
name: Bug report
about: Report a defect in the Wane contracts or SDK
title: "[bug] "
labels: bug
assignees: ''
---

## Summary

A clear, concise description of the bug.

## Component

Which part of Wane is affected. Check all that apply.

- [ ] WaneRegistry (antibody store)
- [ ] WanePolicy (per-agent scope)
- [ ] WaneDelegate (EIP-7702 delegate)
- [ ] WaneToken ($WANE ERC20)
- [ ] WaneHook (Uniswap v4 hook)
- [ ] wane-sdk (TypeScript)
- [ ] Docs / examples
- [ ] Other

## Environment

- Network: <!-- Base mainnet (8453), local fork, or other -->
- Contract address(es) involved: <!-- e.g. WaneRegistry 0x027F371fB139A57EcD2A2E175d30157eEA1C56de -->
- wane-sdk version: <!-- output of `npm ls wane-sdk`, or commit hash if built from source -->
- viem version: <!-- peer dependency version in use -->
- Foundry version: <!-- output of `forge --version`, if reproducing against contracts -->
- Solidity version: <!-- if relevant, e.g. 0.8.27 -->
- Node version: <!-- output of `node --version`, if SDK related -->
- OS: <!-- e.g. macOS 14.5, Ubuntu 22.04, Windows 11 -->

## Steps to reproduce

1.
2.
3.

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened. Include the full error message and revert reason if there is one.

## Transaction or call data

If the bug involves an on-chain transaction or call, paste the relevant details.

- Transaction hash: <!-- e.g. https://basescan.org/tx/0x... -->
- Block number:
- Calldata or function called:
- Revert reason / policy reason code: <!-- e.g. R_TOKEN, R_OK -->

## Minimal reproduction

A minimal Foundry test, SDK snippet, or cast command that reproduces the issue. Keep it as small as possible.

```
// paste code or commands here
```

## Logs and stack trace

```
paste relevant logs, forge trace, or stack trace here
```

## Additional context

Anything else that helps, such as related issues, recent changes, or partial diagnosis.

## Checklist

- [ ] I searched existing issues and this is not a duplicate.
- [ ] I am using the deployed Base mainnet addresses listed in the README, or I have stated which fork or local deployment I used.
- [ ] I included steps to reproduce and the full error output.
