# wane-sdk

TypeScript SDK for Wane, the shared on-chain immune memory and policy firewall for AI agents on Base mainnet. Wrap your agent wallet so every outbound call is screened against on-chain antibodies and your own policy before it executes, and report new attacks so other agents inherit the protection. The policy firewall works for agent wallets and plain EOAs through one EIP-7702 signature: spend caps, selector and token allowlists, and a kill switch, all enforced in-contract so a flagged or out-of-scope action reverts before value moves.

The SDK is a thin viem-based client over the live Wane contracts on Base (chainid 8453). It does not run a backend, hold keys, or proxy your transactions.

## Install

This package is distributed by source. Clone the monorepo and build the SDK in place.

```bash
git clone https://github.com/WaneProtocol/wane-base.git
cd wane/sdk
tsc
```

`viem` is a peer dependency, so install it in the consuming project:

```bash
npm install viem
```

Then import from the built output (or wire the local path into your workspace / `tsconfig` paths):

```ts
import { Wane } from "wane-sdk";
```

## Quick start

```ts
import { createWalletClient, createPublicClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";
import { Wane } from "wane-sdk";

const account = privateKeyToAccount(process.env.AGENT_KEY as `0x${string}`);

const wallet = createWalletClient({ account, chain: base, transport: http() });
const publicClient = createPublicClient({ chain: base, transport: http() });

const wane = new Wane({ wallet, publicClient });

// 1. Ask the registry if a target call is already known-bad.
const verdict = await wane.check({
  to: "0x1111111111111111111111111111111111111111",
  selector: "0xa9059cbb",
});
// verdict.allowed === false, verdict.reason === "R_ANTIBODY" when a matching antibody exists

// 2. One-time setup: install the EIP-7702 delegate on the agent EOA, then enroll a scope.
await wane.enable();           // signs and submits the 7702 authorization for WaneDelegate
await wane.enroll();           // registers the agent in WanePolicy with a default scope

// 3. Route a transaction through the delegate so it is screened on-chain before sending.
const hash = await wane.send({
  to: "0x4200000000000000000000000000000000000006",
  data: "0xd0e30db0",
  value: 1_000_000_000_000_000n,
});
// reverts with the policy reason code if the delegate rejects the call

// 4. Report a fresh attack so the antibody propagates to every other agent.
await wane.report({
  to: "0x1111111111111111111111111111111111111111",
  selector: "0xa9059cbb",
  evidence: "drainer approve+transferFrom pattern",
});
```

## API

| Method | Returns | Description |
| --- | --- | --- |
| `check(target)` | `{ allowed, reason }` | Read-only lookup against WaneRegistry. No transaction, no gas. |
| `wouldAllow(call)` | `boolean` | Dry-run a full call through WaneDelegate without sending. Mirrors on-chain `wouldAllow`. |
| `enable(opts?)` | tx hash | Install the EIP-7702 delegate on the agent EOA via a signed authorization. One-time. |
| `wrap(call)` | encoded call | Encode a raw call as a `WaneDelegate.execute` payload without broadcasting. |
| `send(call)` | tx hash | Wrap and submit a call through the delegate so it is policy-screened before execution. |
| `watch(handler)` | unsubscribe fn | Subscribe to new antibody mints and challenges from WaneRegistry logs. |
| `report(attack)` | tx hash | Mint or corroborate an antibody in WaneRegistry from observed attack evidence. |

`enroll`, `setScope`, and `setPaused` are also exposed for WanePolicy management; see the contract docs for scope reason codes (`R_OK`, `R_PAUSED`, `R_SCOPE`, `R_ANTIBODY`, `R_TOKEN`).

## Deployments (Base mainnet, chainid 8453)

| Contract | Address |
| --- | --- |
| WaneRegistry | `0x027F371fB139A57EcD2A2E175d30157eEA1C56de` |
| WanePolicy | `0x26deE4503C7f67356837ED41cE285026EF256667` |
| WaneDelegate | `0x9175d735D512d730510148ED4D6702eF99CF4901` |
| WaneToken | `0x1465E33f687C557BF275D6d692eC1316126d8e9e` |

These are the defaults the SDK uses when no overrides are passed to the `Wane` constructor.

## Scope and honest limits

- Screening only applies to calls routed through `WaneDelegate`. A plain wallet send that bypasses the delegate is not screened. `enable()` installs the delegate, but it is your responsibility to route sends through `send()` or the delegate itself.
- `check()` and `wouldAllow()` reflect on-chain state at call time. An attack that has not yet been minted as an antibody will return `allowed: true`. Coverage is only as good as what agents have reported.
- The SDK never holds your private key. Signing happens in the viem `WalletClient` you provide.
- Reverts surface the raw policy reason code. Map them with the reason constants above; do not assume a generic revert means "safe".
- Base mainnet only. Other chains are not supported by these deployments.

## Links

- Website: https://wane.network
- X: https://x.com/wanedotnetwork
- GitHub: https://github.com/WaneProtocol/wane-base
- Registry contract: https://basescan.org/address/0x027F371fB139A57EcD2A2E175d30157eEA1C56de

## License

MIT
