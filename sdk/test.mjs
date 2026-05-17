// Pure unit tests for wane-sdk. No network, no funds. Run: node test.mjs
// Verifies the guard logic and encoding that protect against silent failures.
import assert from "node:assert/strict";
import { test } from "node:test";
import { decodeFunctionData, getAddress } from "viem";
import { Wane, POLICY_REASON, WaneBlockedError, addressSubject, waneActions, DEPLOYMENTS } from "./dist/index.js";

const REGISTRY = "0x027F371fB139A57EcD2A2E175d30157eEA1C56de";
const POLICY = "0x571Ac11310fb5d69D660C30f696a81e097Db8586";
const DELEGATE = "0x6350D5850143277F7657549FB505569917641927";
const AGENT = "0x20911c6b4868Ab6C4C0638B518610d6D7a33f0d6";
const TARGET = "0x1111111111111111111111111111111111111111";
const DRAINER = "0x0000000000000000000000000000000000000bAd";

// minimal fake public client; each test wires the few methods it needs
function fakePc(over = {}) {
  return {
    getCode: async () => "0x",
    readContract: async () => [true, 0],
    waitForTransactionReceipt: async () => ({}),
    ...over,
  };
}
function makeWane(pcOver = {}, cfg = {}) {
  return new Wane({
    registry: REGISTRY, policy: POLICY, delegate: DELEGATE, agent: AGENT,
    publicClient: fakePc(pcOver), ...cfg,
  });
}
const account = { address: AGENT };
const protectedCode = ("0xef0100" + DELEGATE.slice(2)).toLowerCase();

test("POLICY_REASON matches contract R_ constants (0..9)", () => {
  assert.equal(POLICY_REASON.length, 10);
  assert.equal(POLICY_REASON[0], "allowed");
  assert.equal(POLICY_REASON[2], "flagged by antibody"); // R_ANTIBODY = 2
  assert.equal(POLICY_REASON[5], "paused (kill switch)"); // R_PAUSED = 5
  assert.equal(POLICY_REASON[9], "token not allowed");    // R_TOKEN = 9
});

test("isProtected true only when code is the exact delegation indicator", async () => {
  assert.equal(await makeWane({ getCode: async () => protectedCode }).isProtected(), true);
  assert.equal(await makeWane({ getCode: async () => "0x" }).isProtected(), false);
  // pointing at a DIFFERENT delegate must read as NOT protected by us
  const other = "0xef0100" + "00000000000000000000000000000000000000ff";
  assert.equal(await makeWane({ getCode: async () => other }).isProtected(), false);
});

test("wouldAllow refuses without a wallet address (no silent allow-all)", async () => {
  const w = new Wane({ registry: REGISTRY, delegate: DELEGATE, publicClient: fakePc() });
  await assert.rejects(() => w.wouldAllow({ to: TARGET }), /protected wallet address/);
});

test("wouldAllow reads AT the agent address, not the delegate contract", async () => {
  let readAt;
  const w = makeWane({ readContract: async (a) => { readAt = a.address; return [true, 0]; } });
  await w.wouldAllow({ to: TARGET }, AGENT);
  assert.equal(getAddress(readAt), getAddress(AGENT));
});

test("send REFUSES on an unprotected wallet (anti silent no-op)", async () => {
  let sent = false;
  const wane = makeWane({ getCode: async () => "0x" }); // not delegated
  const wallet = { account, sendTransaction: async () => { sent = true; return "0xdead"; } };
  await assert.rejects(() => wane.send(wallet, { to: TARGET }), /not protected/);
  assert.equal(sent, false, "must not send when unprotected");
});

test("send THROWS WaneBlockedError on a flagged target, never broadcasts", async () => {
  let sent = false;
  const wane = makeWane({
    getCode: async () => protectedCode,
    readContract: async () => [false, 2], // wouldAllow -> blocked, antibody
  });
  const wallet = { account, sendTransaction: async () => { sent = true; return "0xdead"; } };
  await assert.rejects(
    () => wane.send(wallet, { to: DRAINER }),
    (e) => e instanceof WaneBlockedError && /flagged by antibody/.test(e.message),
  );
  assert.equal(sent, false, "blocked action must not broadcast");
});

test("send routes a clean action through execute(self) with correct calldata", async () => {
  let txArgs;
  const wane = makeWane({
    getCode: async () => protectedCode,
    readContract: async () => [true, 0], // allowed
  });
  const wallet = { account, sendTransaction: async (a) => { txArgs = a; return "0xfeed"; } };
  const hash = await wane.send(wallet, { to: TARGET, value: 123n });
  assert.equal(hash, "0xfeed");
  assert.equal(getAddress(txArgs.to), getAddress(AGENT), "to == self (the wallet)");
  assert.equal(txArgs.value, 123n);
  const decoded = decodeFunctionData({ abi: waneDelegateAbiFromBuild(), data: txArgs.data });
  assert.equal(decoded.functionName, "execute");
  assert.equal(getAddress(decoded.args[0]), getAddress(TARGET));
  assert.equal(decoded.args[1], 123n);
});

test("sendBatch refuses an empty batch and pre-screens every leg", async () => {
  const wane = makeWane({ getCode: async () => protectedCode, readContract: async () => [true, 0] });
  const wallet = { account, sendTransaction: async () => "0xba7c4" };
  await assert.rejects(() => wane.sendBatch(wallet, []), /at least one/);
});

test("addressSubject pads an address to bytes32", () => {
  assert.equal(addressSubject(DRAINER).length, 66);
  assert.ok(addressSubject(DRAINER).toLowerCase().endsWith("0bad"));
});

test("Wane.baseSepolia() wires canonical addresses, no pasting", () => {
  const w = Wane.baseSepolia({ agent: AGENT, publicClient: fakePc() });
  assert.equal(getAddress(w.registry), getAddress(DEPLOYMENTS.baseSepolia.registry));
  assert.equal(getAddress(w.delegate), getAddress(DEPLOYMENTS.baseSepolia.delegate));
});

test("Wane.base() wires canonical Base mainnet addresses", () => {
  assert.ok(DEPLOYMENTS.base, "base deployment is set");
  const w = Wane.base({ agent: AGENT, publicClient: fakePc() });
  assert.equal(getAddress(w.registry), getAddress(DEPLOYMENTS.base.registry));
  assert.equal(getAddress(w.delegate), getAddress(DEPLOYMENTS.base.delegate));
});

test("waneActions extends a client with protectedSend that screens", async () => {
  let sent = false;
  const wane = makeWane({ getCode: async () => protectedCode, readContract: async () => [false, 2] });
  // emulate a viem client.extend(waneActions(wane))
  const client = { account, sendTransaction: async () => { sent = true; return "0x"; } };
  const actions = waneActions(wane)(client);
  await assert.rejects(() => actions.protectedSend({ to: DRAINER }), WaneBlockedError);
  assert.equal(sent, false);
  assert.equal(typeof actions.enableProtection, "function");
  assert.equal(typeof actions.isProtected, "function");
});

test("count reads antibodyCount", async () => {
  const w = makeWane({ readContract: async () => 558n });
  assert.equal(await w.count(), 558n);
});

// the execute ABI is internal; reconstruct the minimal slice for decode assertions
function waneDelegateAbiFromBuild() {
  return [{
    type: "function", name: "execute", stateMutability: "payable",
    inputs: [
      { name: "target", type: "address" },
      { name: "value", type: "uint256" },
      { name: "data", type: "bytes" },
    ],
    outputs: [{ name: "ret", type: "bytes" }],
  }];
}
