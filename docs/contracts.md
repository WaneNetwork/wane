# Contracts

Wane is four contracts on Base mainnet (chainid 8453). One stores the shared
immune memory, one holds each agent's protection scope, one is the EIP-7702
delegate that screens actions before they run, and one is the staking and reward
token. They are independent: the registry has no idea the delegate exists, and
an integrator can read the registry directly without touching policy or delegate
at all.

```
WaneToken  ──stake/reward──▶  WaneRegistry  ◀──reads check()──  WanePolicy  ◀──evaluate()──  WaneDelegate
 (ERC20)                      (antibody store)                  (per-agent scope)            (7702 screen)
```

| Contract | Base mainnet address |
| --- | --- |
| WaneRegistry | [`0x027F371fB139A57EcD2A2E175d30157eEA1C56de`](https://basescan.org/address/0x027F371fB139A57EcD2A2E175d30157eEA1C56de) |
| WanePolicy | [`0x26deE4503C7f67356837ED41cE285026EF256667`](https://basescan.org/address/0x26deE4503C7f67356837ED41cE285026EF256667) |
| WaneDelegate | [`0x9175d735D512d730510148ED4D6702eF99CF4901`](https://basescan.org/address/0x9175d735D512d730510148ED4D6702eF99CF4901) |
| WaneToken | [`0x1465E33f687C557BF275D6d692eC1316126d8e9e`](https://basescan.org/address/0x1465E33f687C557BF275D6d692eC1316126d8e9e) |

652 genesis antibodies are seeded on the live registry. Solidity 0.8.27, built
with Foundry, OpenZeppelin for ERC20 / SafeERC20 / ReentrancyGuard.

## Shared types

`WaneTypes` defines the enums every contract references.

`ThreatKind` is the category of threat an antibody recognizes:

| Value | Name | Subject encoding |
| --- | --- | --- |
| 0 | `Address` | `bytes32(uint256(uint160(target)))`, a specific wallet or contract |
| 1 | `CallPattern` | `bytes32(selector)`, a 4-byte calldata selector used to drain |
| 2 | `Bytecode` | a contract runtime codehash (catches re-deployed drainers) |
| 3 | `Semantic` | a prompt-injection / tool-poisoning marker hash |

`Status` is the lifecycle of one antibody:

| Value | Name | Meaning |
| --- | --- | --- |
| 0 | `None` | never minted |
| 1 | `Active` | live, enforced once it clears the dispute window |
| 2 | `Challenged` | someone staked against it; under dispute, still fail-closed |
| 3 | `Revoked` | proven false; minter slashed, no longer enforces |

An antibody's storage key is `keccak256(abi.encodePacked(kind, subject))`, so the
same address flagged as both `Address` and `Bytecode` lives in two separate
entries.

---

## WaneRegistry

`0x027F371fB139A57EcD2A2E175d30157eEA1C56de`

The blood. Antibodies (threat memories) live here. Any agent reads `check()` for
free before it signs. One agent is attacked once; every agent after is immune.

### Read path

These are `view`, free, and the only functions an integrator strictly needs.

| Function | Returns | Notes |
| --- | --- | --- |
| `check(ThreatKind kind, bytes32 subject)` | `(bool active, uint64 id)` | `active` is true only when the antibody is enforceable. Returns `(false, 0)` while paused or unknown. |
| `checkAddress(address target)` | `(bool active, uint64 id)` | Convenience wrapper over `check(Address, ...)`, the most common case. |
| `checkBytecode(bytes32 codehash)` | `(bool active, uint64 id)` | Wrapper over `check(Bytecode, ...)`; catches a drainer redeployed to a new address. |
| `antibodies(uint64 id)` | full `Antibody` tuple | Public mapping getter: id, kind, status, publisher, stake, mintedBlock, corroborations, subject, evidence. |
| `antibodyCount()` | `uint64` | Total antibodies ever minted (including genesis). |
| `surplus()` | `uint256` | WANE held by the registry not backing any stake, bond, or earned balance. |

#### Enforceability

`check()` returns `active = true` only when the antibody is past dispute risk.
The internal `_enforceable` rule:

- `Revoked` never enforces.
- `Challenged` still enforces (fail-closed, so a drainer cannot self-challenge
  to un-block itself).
- `Active` enforces when any of: stake is 0 (genesis / protocol-owned), OR
  corroborations `>= enforceCorrobs` (default 2), OR `block.number >=
  mintedBlock + enforceWindow` (default 1800 blocks, about an hour at 2s blocks).
- A young, un-corroborated `Active` antibody does NOT enforce yet. This is the
  anti false-flag guard: a fresh entry cannot be weaponized to censor a target
  before it has survived the window or gathered corroborations.

### Write path

| Function | Access | Effect |
| --- | --- | --- |
| `mintAntibody(ThreatKind kind, bytes32 subject, bytes32 evidence)` | anyone | Locks `mintStake` (default 100 WANE), creates an `Active` antibody, returns its id. Reverts `Exists` on a live duplicate; a `Revoked` key may be overwritten to re-flag a re-offender. `nonReentrant`, blocked while paused. |
| `corroborate(uint64 id)` | anyone except publisher | Adds one independent confirmation, raising trust and enforceability. Reverts `SelfCorroborate`, `AlreadyCorroborated`, or `NotActive`. |

### Dispute path

| Function | Access | Effect |
| --- | --- | --- |
| `challenge(uint64 id)` | anyone | Locks `challengeStake` (default 200 WANE), moves the antibody to `Challenged` (still fail-closed). Reverts `AlreadyChallenged` if a challenge is open. |
| `resolve(uint64 id, bool falsePositive)` | governor | Arbitrates. `falsePositive = true`: antibody `Revoked`, key freed, challenger paid bond + slashed stake. `false`: antibody back to `Active`, challenger bond credited to publisher's `earned`. CEI: state cleared before any transfer. |

### Economics

| Function | Access | Effect |
| --- | --- | --- |
| `reclaimStake(uint64 id)` | publisher | After `maturity` (default 21600 blocks, about 72h) an unchallenged `Active` antibody's stake is reclaimable. Reverts `TooEarly` or `NotActive`. |
| `claimRewards()` | anyone | Withdraws the caller's accrued `earned` balance. |
| `payCheck(uint64 id)` | anyone | Optional metered check fee (0 by default, so plain `check()` is free). Splits `checkFee` 80/20 publisher/treasury via `publisherBps`. |

### Genesis and admin

| Function | Access | Effect |
| --- | --- | --- |
| `seedGenesis(ThreatKind[] kinds, bytes32[] subjects, bytes32[] evidence)` | governor | Cold-start seed of protocol-owned antibodies (stake 0, publisher = registry, enforce immediately). Only while `genesisOpen`. Skips keys that already exist. |
| `closeGenesis()` | governor | Permanently closes the genesis window. |
| `setPaused(bool p)` | governor | Emergency: `check()` returns clear and all writes revert. |
| `transferGovernor(address next)` / `acceptGovernor()` | governor / pending | Two-step governor handoff (no fat-finger to zero). |
| `setTreasury(address t)` | governor | Updates the fee-share treasury. |
| `setParams(uint96 mintStake, uint96 challengeStake, uint64 maturity, uint16 publisherBps, uint96 checkFee)` | governor | Tunes stakes, maturity, fee split (`publisherBps <= 10000`), and check fee. |
| `setEnforcement(uint64 window, uint32 corrobs)` | governor | Tunes the enforce window and corroboration threshold. |

### Key public state

`wane`, `governor`, `pendingGovernor`, `treasury`, `genesisOpen`, `paused`,
`mintStake`, `challengeStake`, `maturity`, `enforceWindow`, `enforceCorrobs`,
`publisherBps`, `checkFee`, `antibodyCount`, `reserved`, `antibodies(id)`,
`idByKey(key)`, `hasCorroborated(id, addr)`, `challenger(id)`,
`challengeBond(id)`, `earned(addr)`.

### Token accounting invariant

Every locked stake, bond, and earned balance is summed in `reserved`. Payouts
decrement `reserved` and can never dip into another user's locked principal.
`surplus()` exposes any excess balance not backing a liability.

---

## WanePolicy

`0x26deE4503C7f67356837ED41cE285026EF256667`

Per-agent protection scope. A bot owner enrolls an agent once, picks what to
block, and from then on the SDK, the delegate, or the v4 hook evaluates every
action against this policy plus the shared registry.

### Threat-kind bitmask

`blockKinds` is a bitmask of `ThreatKind` flags. The owner picks which kinds the
policy enforces.

| Constant | Value | Threat kind |
| --- | --- | --- |
| `K_ADDRESS` | `1 << 0` | Address |
| `K_CALL` | `1 << 1` | CallPattern |
| `K_BYTECODE` | `1 << 2` | Bytecode |
| `K_SEMANTIC` | `1 << 3` | Semantic |
| `K_ALL` | `0x0F` | all of the above |

Passing `blockKinds = 0` to `enroll` defaults the policy to `K_ALL`.

### Enroll and configure

| Function | Access | Effect |
| --- | --- | --- |
| `enroll(address agent, uint8 blockKinds, uint32 minCorrobs, uint128 perTxCap, uint128 dailyCap, uint40 expiresAt)` | first caller becomes owner | Registers an agent and sets its initial scope. Subsequent calls require the same owner. `enabled = true`, `paused = false`. |
| `setEnabled(address agent, bool on)` | owner | Owner intent on/off. |
| `setScope(address agent, uint8 blockKinds, uint32 minCorrobs, uint128 perTxCap, uint128 dailyCap, uint40 expiresAt)` | owner | Re-configures threat kinds, sensitivity, spend caps, and TTL. |

### Kill switch and global controls

| Function | Access | Effect |
| --- | --- | --- |
| `setPaused(address agent, bool p)` | owner OR guardian | Fast per-agent kill switch. Either the owner or the guardian can trip it. |
| `setGlobalPaused(bool p)` | guardian | Stops every enrolled agent at once. |
| `setGlobalDenied(address target, bool value)` | guardian | Curated recipient denylist applied to all agents. |
| `setGuardian(address g)` | guardian | Hands off the guardian role. |

### Per-agent lists and scoping

| Function | Access | Effect |
| --- | --- | --- |
| `setAllow(address agent, address target, bool value)` | owner | Allowlist: target always passes (checked before everything). |
| `setBlock(address agent, address target, bool value)` | owner | Blocklist: target always stops. |
| `setSelectorScoped(address agent, bool scoped)` | owner | When true, only allowlisted 4-byte selectors pass. |
| `setSelector(address agent, bytes4 selector, bool value)` | owner | Adds / removes a selector from the agent's selector allowlist. |
| `setTokenScoped(address agent, bool scoped)` | owner | When true, only allowlisted tokens pass `isTokenAllowed`. |
| `setToken(address agent, address token, bool value)` | owner | Adds / removes a token from the agent's token allowlist. |
| `recordSpend(address agent, uint128 amount)` | owner | Records a spend against the rolling daily counter (resets each UTC day). |

### Evaluate

The read functions the protection layer calls before an agent acts. Both are
`view` and free.

| Function | Returns | Notes |
| --- | --- | --- |
| `evaluate(address agent, address target, uint128 amount)` | `(bool allowed, uint8 reason)` | Value-only check (native send or generic target), no selector. |
| `evaluateCall(address agent, address target, bytes4 selector, uint128 amount)` | `(bool allowed, uint8 reason)` | Full check including the called selector; enforces the selector allowlist and `K_CALL` antibody lookup. |
| `isTokenAllowed(address agent, address token)` | `bool` | Token-allowlist check at the swap boundary. Returns true when the agent is not enrolled, disabled, or not token-scoped. |
| `usedToday(address agent)` | `uint128` | Amount spent today against the daily cap. |

#### Evaluation order

`_evaluate` short-circuits in this order. If the agent is unenrolled or
`!enabled`, it returns `(true, R_OK)` (Wane only screens enrolled agents).
Otherwise:

1. `globalPaused` or per-agent `paused` -> `R_PAUSED`
2. policy `expiresAt` elapsed -> `R_EXPIRED`
3. agent allowlist hit -> `R_OK` (pass immediately)
4. agent blocklist hit -> `R_BLOCKLIST`
5. global denylist hit -> `R_GLOBAL_DENY`
6. selector allowlist miss (when `selectorScoped`) -> `R_SELECTOR`
7. `K_CALL` antibody on the selector -> `R_ANTIBODY`
8. `K_ADDRESS` antibody on the target -> `R_ANTIBODY`
9. `K_BYTECODE` antibody on the target's codehash -> `R_ANTIBODY`
10. per-tx cap exceeded -> `R_PERTX`
11. daily cap exceeded -> `R_DAILY`
12. otherwise -> `R_OK`

#### Sensitivity

Antibody hits only count when they meet the agent's `minCorrobs` threshold.
`_meetsSensitivity`: `minCorrobs == 0` always passes; genesis / protocol-owned
antibodies (stake 0) are always trusted; otherwise the antibody's
`corroborations` must be `>= minCorrobs`.

### Reason codes

Returned as `uint8 reason` by `evaluate` / `evaluateCall`, and re-emitted by the
delegate in `Blocked` and `Screened`.

| Code | Constant | Meaning |
| --- | --- | --- |
| 0 | `R_OK` | allowed |
| 1 | `R_BLOCKLIST` | target on the agent's blocklist |
| 2 | `R_ANTIBODY` | a registry antibody (address, call pattern, or bytecode) flagged it |
| 3 | `R_PERTX` | amount over the per-transaction cap |
| 4 | `R_DAILY` | amount would exceed the rolling daily cap |
| 5 | `R_PAUSED` | agent kill switch or global pause is on |
| 6 | `R_GLOBAL_DENY` | target on the curated global recipient denylist |
| 7 | `R_EXPIRED` | policy TTL elapsed |
| 8 | `R_SELECTOR` | function selector not on the allowlist (selector-scoped) |
| 9 | `R_TOKEN` | token not on the allowlist (token-scoped) |

### Key public state

`registry`, `guardian`, `globalPaused`, `policies(agent)`, `allowlist(agent,
target)`, `blocklist(agent, target)`, `allowedSelector(agent, selector)`,
`allowedToken(agent, token)`, `globalDenied(target)`, plus the `K_*` and `R_*`
constants above.

---

## WaneDelegate

`0x9175d735D512d730510148ED4D6702eF99CF4901`

The EIP-7702 delegate. A wallet signs one 7702 Account Update pointing its code
here. From then on, when the wallet routes an action through `execute()`, Wane
screens it against the registry and the wallet's policy before it runs. A flagged
target reverts; a clean one executes with the wallet's own authority.

### Trust model

This contract can only block. It never holds funds and has no path to move the
wallet's assets anywhere the wallet did not ask for. Under 7702 the inner call's
`msg.sender` is the wallet itself (`address(this)`), so Wane cannot redirect
value. The honest limit: a delegate cannot intercept a raw transaction the key
signs directly. Protection holds for actions sent through `execute()`, which is
what the Wane SDK and agent runtime call. Direct key spends bypass it, the same
as every 7702 guard.

### Functions

| Function | Access | Effect |
| --- | --- | --- |
| `execute(address target, uint256 value, bytes data)` | `onlySelf` | Screens, then performs `target.call{value}(data)` with the wallet's authority. Reverts `Blocked(target, reason)` if screening fails, or `"Wane: inner call failed"` if the inner call reverts. Returns the call's return data. |
| `executeBatch(address[] targets, uint256[] values, bytes[] datas)` | `onlySelf` | Screens and runs each action in order. Any flagged target reverts the whole batch. Reverts `BatchLengthMismatch` on uneven arrays. |
| `wouldAllow(address target, uint256 value, bytes data)` | view | Dry-run the screen without executing. Returns `(bool allowed, uint8 reason)`. |
| `receive()` | payable | Accepts inbound ETH. Inbound is never the wallet's own action, so it is not screened. |
| `fallback()` | payable | Accepts inbound calls with data, including the 7702 set-code self-call. |

### onlySelf

`execute` and `executeBatch` require `msg.sender == address(this)`. Under 7702 a
legitimate action is the wallet calling its own code, so `msg.sender` is the
wallet. Any other caller is an outsider trying to move the wallet's funds and is
rejected with `NotSelf`. Without this guard, anyone could call `execute()` on a
delegated wallet and drain it by sending to a clean (unflagged) address.

### Screening

`_evaluate` derives `amount` from `value` (clamped to `uint128`) and `selector`
from the first 4 bytes of `data`. If a selector is present it calls
`policy.evaluateCall(address(this), target, selector, amount)`, otherwise
`policy.evaluate(address(this), target, amount)`. The policy is keyed on
`address(this)` because the wallet is its own agent under 7702. Reasons mirror
`WanePolicy`'s `R_*` codes (see the table above). Every screen emits
`Screened(agent, target, value, allowed, reason)`.

### Key public state

`registry`, `policy` (both immutable, set at deploy).

---

## WaneToken

`0x1465E33f687C557BF275D6d692eC1316126d8e9e`

`$WANE`, the currency of the bloodstream. Staked to mint antibodies, slashed for
false ones, paid out as rewards.

- Standard OpenZeppelin `ERC20`. Name `Wane`, symbol `WANE`, 18 decimals.
- Fixed supply: `MAX_SUPPLY = 1_000_000_000e18` (1B WANE), minted in full to the
  treasury at deploy.
- No mint function after deploy; supply can only ever decrease (via burns from
  ERC20). Distribution (LP, airdrop, treasury) is handled externally.

| Member | Notes |
| --- | --- |
| `MAX_SUPPLY` | constant, `1_000_000_000e18` |
| `name()` / `symbol()` / `decimals()` | `Wane` / `WANE` / `18` |
| standard ERC20 | `transfer`, `transferFrom`, `approve`, `allowance`, `balanceOf`, `totalSupply` |

The registry references this token via its immutable `wane` address and moves it
with `SafeERC20` under `nonReentrant`, CEI-ordered functions.

---

## Putting it together

A minimal integration never deploys anything. It reads the live registry:

```solidity
(bool flagged, uint64 id) = registry.checkAddress(suspectRecipient);
if (flagged) revert("Wane: recipient has an active antibody");
```

A full agent integration enrolls in `WanePolicy`, optionally delegates its
wallet to `WaneDelegate` via EIP-7702, and routes outbound actions through
`execute()` so every action is screened against both the per-agent scope and the
shared antibody memory before it runs.
