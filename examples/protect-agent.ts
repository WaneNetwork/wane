/**
 * protect-agent.ts
 *
 * End-to-end EIP-7702 protection for an AI agent's own wallet on Base mainnet.
 *
 * The flow is three steps:
 *   1. enable()  one signature points the wallet's code at WaneDelegate and
 *                enrolls it in WanePolicy. The wallet keeps its address, funds,
 *                and keys. The delegate can only block, never move funds.
 *   2. wrap()    returns a thin client whose sendTransaction routes every call
 *                through the wallet's own execute(), which screens the target
 *                against the antibody registry + policy on-chain before any
 *                value moves.
 *   3. send      a clean target goes through untouched. A flagged target reverts
 *                with Blocked, surfaced here as a WaneBlockedError, before the
 *                wallet can be drained.
 *
 * Run:
 *   export WANE_PRIVATE_KEY=0x...        # the agent's key (Base mainnet, holds ETH)
 *   export BASE_RPC_URL=https://...      # an HTTPS Base RPC that supports type-0x04 txs
 *   npx tsx examples/protect-agent.ts
 *
 * EIP-7702 needs an RPC and account stack that accept set-code (type 0x04)
 * transactions. A plain local private-key account with a recent viem build does.
 */

import { createWalletClient, http, parseEther, getAddress, type Address, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { base } from "viem/chains";
import { Wane, WaneBlockedError } from "wane-sdk";

async function main() {
  const pk = process.env.WANE_PRIVATE_KEY as Hex | undefined;
  if (!pk) throw new Error("set WANE_PRIVATE_KEY (the agent's Base mainnet key)");
  const rpcUrl = process.env.BASE_RPC_URL; // optional; falls back to the chain default

  // The agent's own account. This is the wallet we are protecting.
  const account = privateKeyToAccount(pk);

  // A standard viem wallet client. signAuthorization + sendTransaction on this
  // client are what the 7702 path uses; nothing custom is required.
  const wallet = createWalletClient({
    account,
    chain: base,
    transport: http(rpcUrl),
  });

  // Wane wired to the live Base mainnet deployment (registry, policy, delegate,
  // token addresses are baked in, so nothing is hand-pasted). Passing `agent`
  // lets policy and 7702 views key on this wallet.
  const wane = Wane.base({ agent: account.address, rpcUrl });

  console.log("agent wallet:", account.address);
  console.log("known antibodies:", (await wane.count()).toString()); // e.g. 652n

  // ── step 1: turn protection on (one signature) ───────────────────────────
  // enable() is idempotent: if the wallet is already delegated to WaneDelegate
  // it skips the set-code tx. enroll defaults to true, registering the wallet in
  // WanePolicy. Optional caps below add a per-tx and a daily ceiling on top of
  // the global antibody registry.
  const already = await wane.isProtected(account.address); // boolean
  if (already) {
    console.log("already protected, skipping enable()");
  } else {
    const res = await wane.enable(wallet, {
      enroll: true,
      perTxCap: parseEther("0.5"), // reject any single screened send over 0.5 ETH
      dailyCap: parseEther("2"), // reject once the rolling daily total passes 2 ETH
    });
    console.log("set-code tx:", res.setCodeTx); // 0x... (type-0x04 7702 tx hash)
    console.log("enroll tx:", res.enrollTx ?? "(skipped)"); // 0x... or undefined
  }

  // Confirm the wallet now carries the 7702 delegation indicator for WaneDelegate.
  console.log("protected now:", await wane.isProtected(account.address)); // true

  // ── step 2: wrap the wallet so every send is screened ────────────────────
  // One-line swap: use `client` everywhere the agent used `wallet` before. Its
  // sendTransaction routes through the on-chain screen.
  const client = wane.wrap(wallet);

  // ── step 3a: a clean send goes through ───────────────────────────────────
  // Pick any non-flagged recipient the agent actually intends to pay. We
  // dry-run wouldAllow() first to show the verdict without spending a tx.
  const recipient: Address = getAddress("0x4200000000000000000000000000000000000006"); // example: WETH on Base
  const cleanCall = { to: recipient, value: parseEther("0.001") };

  const verdict = await wane.wouldAllow(cleanCall, account.address);
  console.log("wouldAllow clean target:", verdict.allowed, verdict.reasonText); // true "allowed"

  if (verdict.allowed) {
    const txHash = await client.sendTransaction(cleanCall);
    console.log("screened send tx:", txHash); // 0x... the tx that passed the screen
  }

  // ── step 3b: a flagged send is blocked before any value moves ────────────
  // Sending to a known-bad address throws WaneBlockedError (the on-chain screen
  // reverts with Blocked, and the SDK pre-screen catches it up front so no
  // failed tx is even broadcast). We probe a recent antibody to get a real
  // flagged subject; if none is found we fall back to a placeholder so the
  // example still demonstrates the catch path.
  const recent = await wane.recent(1); // newest antibodies, the swarm's live memory
  const knownBad: Address =
    recent.length > 0
      ? (getAddress(("0x" + recent[0].subject.slice(-40)) as Hex) as Address)
      : getAddress("0x000000000000000000000000000000000000dEaD");

  try {
    await client.sendTransaction({ to: knownBad, value: parseEther("0.001") });
    console.log("unexpected: send to", knownBad, "was not blocked");
  } catch (err) {
    if (err instanceof WaneBlockedError) {
      // The drain was stopped. The wallet still holds its funds.
      console.log("blocked as expected:", err.message);
    } else {
      throw err; // a different failure (RPC, gas, nonce); do not swallow it
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
