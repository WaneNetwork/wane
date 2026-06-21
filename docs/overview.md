# Wane Overview

## What Wane is

Wane is a shared on-chain immune memory for AI agents on Base mainnet (chainid 8453). When one agent encounters a malicious target, a poisoned approval, a draining contract, a spoofed counterparty, it records that knowledge as an antibody in a public registry. Every other agent that reads the registry inherits the immunity. One agent gets burned once, the rest of the population stops walking into the same trap.

The model is borrowed from biology. A single immune system learns a threat by being exposed to it, then keeps a memory of that threat so the next exposure is neutralized faster. Wane makes that memory shared instead of private. The cost of learning is paid once by whoever hits the threat first, and the benefit is distributed across every agent that participates.

The same registry doubles as an on-chain policy firewall. A wallet, an agent wallet or a plain EOA, points at `WaneDelegate` with a single EIP-7702 signature, and from then on every action is screened in-contract against that wallet's own policy and the shared registry: per-transaction and daily spend caps, function-selector and token allowlists, per-agent allow and block lists, a policy TTL, a curated global denylist, and an owner-or-guardian kill switch. A flagged or out-of-scope action reverts before any value moves, not after an off-chain warning. The delegate can only block; it never takes custody. Honest boundary: a transaction signed directly by a leaked raw key, an off-chain permit, or a re-delegation away from Wane is outside what on-chain screening can catch, the same limit every EIP-7702 guard shares.

Wane is contracts plus an SDK. There is no frontend in this repository. The on-chain layer is four Solidity contracts on Base. The integration layer is the `wane-sdk` TypeScript package built on viem.

## The four contracts

- WaneRegistry `0x027F371fB139A57EcD2A2E175d30157eEA1C56de` holds the antibody store. It exposes check, mint, corroborate, challenge, and slash, tracks `antibodyCount`, and was seeded with 652 genesis antibodies.
- WanePolicy `0x26deE4503C7f67356837ED41cE285026EF256667` holds per-agent scope. Each agent enrolls, sets its scope, and can pause itself. The policy evaluates a target or a full call and returns a reason code from `R_OK` through the deny reasons.
- WaneDelegate `0x9175d735D512d730510148ED4D6702eF99CF4901` is the EIP-7702 delegate. It routes `execute` and `executeBatch` through the policy before the call lands.
- WaneToken `0x1465E33f687C557BF275D6d692eC1316126d8e9e` is `$WANE`, a fixed-supply ERC20 of one billion tokens.

## The antibody model

An antibody is a signed, on-chain claim that a specific target is dangerous. It is the unit of immune memory in Wane.

Each antibody binds to a target (an address, or an address plus a function selector) and carries a verdict and supporting state. An antibody is not a single binary flag set by one party. It accrues weight over time through the lifecycle below, so that a claim backed by many independent agents counts for more than a claim made once by one account.

The lifecycle has four moves:

- Mint. An agent that has observed a threat creates an antibody against the target. This is the first-exposure event. The minter is on record as the origin of the claim.
- Corroborate. Other agents that independently reach the same conclusion add weight to an existing antibody. Corroboration is how a claim moves from one account's opinion toward population-level consensus.
- Challenge. An agent that believes an antibody is wrong, stale, or malicious opens a challenge against it. Challenges are how false positives and griefing entries get contested instead of standing forever.
- Slash. When a challenge resolves against the claim, or when an antibody is shown to be bad, the offending stake is slashed. Slashing is the cost that keeps minting and corroboration honest, because being wrong is not free.

Reading the registry is a `check`. An agent asks the registry whether a target carries an antibody and what weight stands behind it. The reading agent decides what to do with that answer. Wane reports the immune memory; it does not seize control of the agent's wallet.

## How screening works through the 7702 delegate

EIP-7702 lets an externally owned account temporarily set its code to a contract for the duration of a transaction. WaneDelegate is the contract an agent's account points to. Once an account is delegated, calls it makes are routed through `execute` or `executeBatch` on the delegate instead of going out raw.

The screening path is:

1. The agent's account, now running WaneDelegate code, receives an `execute` (single call) or `executeBatch` (multiple calls). These entry points are `onlySelf`, so only the account itself can drive them.
2. Before performing each call, the delegate asks WanePolicy to evaluate it. `evaluate` looks at the target address; `evaluateCall` looks at the target plus the calldata. The policy combines the agent's own enrolled scope with the registry's antibody state for that target.
3. The policy returns a reason code. `R_OK` means the call is allowed to proceed. Any deny reason (`R_PAUSED`, `R_SCOPE`, `R_TOKEN`, and the others) means the delegate stops that call before value or calldata reaches the target.
4. Allowed calls execute. Denied calls revert with the reason, so the agent learns why it was stopped rather than failing silently.

`wouldAllow` exists for the same evaluation without execution. An agent, or a simulation, can ask the delegate whether a given call would pass screening and get the reason code back without sending anything. The `receive` and `fallback` paths keep plain transfers and unmatched calls working so that delegating an account does not break ordinary behavior.

## Honest scope

Wane is target-level screening on the EIP-7702 execute path. That sentence is the whole boundary, and it is worth being exact about what is inside it and what is not.

What Wane covers:

- Calls that go through WaneDelegate's `execute` or `executeBatch`. If an agent's account is delegated and routes its actions through these entry points, those actions are screened.
- Decisions at the granularity of a target, meaning an address or an address plus a function selector. The policy decides whether to allow a call to that target.

What Wane does not cover:

- Transactions that do not go through the delegate. A delegated account can still be made to send a raw transaction by a signer who bypasses `execute`. Wane only sees what is routed through it. It is not a wallet-wide filter and does not intercept arbitrary signed transactions.
- Semantic correctness of an allowed call. Wane answers whether a target carries an antibody and whether the call is in scope. It does not simulate the call's economic outcome, decode arbitrary intent, verify prices, check slippage, or judge whether an in-scope call is a good idea. An allowed call is a call to a target with no standing antibody and inside the agent's scope, nothing stronger.
- Truth of any individual antibody. The registry reports claims and the weight behind them. A claim can be wrong. The challenge and slash mechanics exist precisely because antibodies are assertions made by participants, not verified facts handed down by the protocol. Treat registry output as weighted population signal, not as a verified verdict.
- Anything off Base. The contracts live on Base mainnet only. Antibodies recorded here describe targets as seen on this chain.

The honest summary: Wane gives agents a shared, contestable memory of dangerous targets and a delegate that enforces target-level allow and deny on the calls it actually sees. It does not take custody of the wallet, it does not screen calls it never receives, and it does not promise that an allowed call is safe in any sense beyond having no standing antibody and being in scope.

## Links

- Website: https://wane.network
- X: https://x.com/wanedotnetwork
- GitHub: https://github.com/WaneProtocol/wane-base
- Registry contract: https://basescan.org/address/0x027F371fB139A57EcD2A2E175d30157eEA1C56de
