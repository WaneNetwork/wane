/**
 * examples/check-address.ts
 *
 * Reading is immunity. Before an agent signs anything that touches a counterparty,
 * it asks the Wane registry on Base mainnet whether that address is covered by an
 * active antibody. The check is a free view call, so it costs no gas and adds no
 * latency beyond one RPC round trip.
 *
 * Run it:
 *   cd sdk && npm run build
 *   npx tsx ../examples/check-address.ts 0x... [rpcUrl]
 *
 * If no address is passed, it falls back to a known clean address (the WaneToken
 * contract) so the script always produces output.
 */

import { Wane } from "wane-sdk";
import { getAddress, type Address } from "viem";

async function main() {
  // Address to screen: first CLI arg, or a default clean one (the $WANE token).
  const arg = process.argv[2];
  const target: Address = getAddress(
    arg ?? "0x1465E33f687C557BF275D6d692eC1316126d8e9e",
  );

  // Optional custom RPC as the second arg; otherwise viem's default Base RPC.
  const rpcUrl = process.argv[3];

  // Wire the SDK to the live Base mainnet deployment. No address pasting:
  // the factory carries the registry/policy/delegate/token addresses for chain 8453.
  const wane = Wane.base(rpcUrl ? { rpcUrl } : {});

  // How big is the shared immune memory right now? Free view call.
  const total = await wane.count();
  console.log(`Wane registry on Base holds ${total} antibodies.`);

  // The actual screen. Returns a Verdict: { flagged, antibodyId, kind, subject }.
  const verdict = await wane.checkAddress(target);

  if (verdict.flagged) {
    console.log(
      `BLOCKED ${target} is flagged by antibody #${verdict.antibodyId}. Do not sign.`,
    );
    // An agent would abort the action here. assertSafe() throws WaneBlockedError
    // for callers who prefer exceptions over inspecting the verdict:
    //   await wane.assertSafe(target)
    process.exitCode = 1;
  } else {
    console.log(`CLEAN ${target} is not covered by any active antibody. Safe to proceed.`);
  }
}

main().catch((err) => {
  console.error("check-address failed:", err);
  process.exit(1);
});

/*
 * Example output (values depend on live chain state):
 *
 *   Wane registry on Base holds 652 antibodies.
 *   CLEAN 0x1465E33f687C557BF275D6d692eC1316126d8e9e is not covered by any active antibody. Safe to proceed.
 *
 * For a flagged address:
 *
 *   Wane registry on Base holds 652 antibodies.
 *   BLOCKED 0xBadDrainer... is flagged by antibody #41. Do not sign.
 */
