---
name: Feature request
about: Suggest a new capability or improvement for Wane contracts or the SDK
title: "[Feature] "
labels: enhancement
assignees: ""
---

## Summary

One or two sentences describing the feature you want.

## Component

Which part of Wane does this affect? Check all that apply.

- [ ] WaneRegistry (antibody store: check/mint/corroborate/challenge/slash)
- [ ] WanePolicy (per-agent scope and call evaluation)
- [ ] WaneDelegate (EIP-7702 delegate execution screening)
- [ ] WaneToken ($WANE ERC20)
- [ ] WaneHook (Uniswap v4 hook)
- [ ] wane-sdk (TypeScript)
- [ ] Docs
- [ ] Other

## Problem

What problem does this solve? Describe the current limitation or the use case that is not covered today. Link to a specific agent flow or contract interaction if relevant.

## Proposed solution

Describe how you would like it to work. For contract changes, include the function signature, the storage you expect to read or write, and the reason codes or events involved. For SDK changes, include the proposed method name and its return shape.

```solidity
// Optional: sketch the interface or function signature you have in mind.
```

```typescript
// Optional: sketch the SDK call and the value it should return.
```

## Alternatives considered

Other approaches you looked at and why you discarded them. Note if an existing primitive (corroborate, challenge, setScope, evaluateCall) already gets you most of the way there.

## Onchain impact

- Storage layout change: yes / no
- New external function: yes / no
- Breaking ABI change: yes / no
- Affects deployed Base mainnet contracts: yes / no

If this touches a contract already live on Base mainnet (chainid 8453), explain the migration or upgrade path you expect.

## Additional context

Anything else: links, references to similar mechanisms in other protocols, gas considerations, or screenshots of the current behavior.

## Checklist

- [ ] I have searched existing issues and this is not a duplicate.
- [ ] This is a single, focused request, not a list of unrelated ideas.
- [ ] I have described the problem, not only the solution.
