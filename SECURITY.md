# Security Policy

Wane is a smart contract protocol that holds and routes value on Base mainnet. We take security issues seriously and appreciate responsible disclosure from the community.

## Supported Versions

Security updates apply to the versions below. Older releases do not receive backports.

| Component  | Version | Supported          |
| ---------- | ------- | ------------------ |
| Contracts  | 1.x     | Yes                |
| Contracts  | < 1.0   | No                 |
| wane-sdk   | 1.x     | Yes                |
| wane-sdk   | < 1.0   | No                 |

The deployed Base mainnet contracts are the canonical, supported instances:

| Contract      | Address                                      |
| ------------- | -------------------------------------------- |
| WaneRegistry  | `0x027F371fB139A57EcD2A2E175d30157eEA1C56de` |
| WanePolicy    | `0x26deE4503C7f67356837ED41cE285026EF256667` |
| WaneDelegate  | `0x9175d735D512d730510148ED4D6702eF99CF4901` |
| WaneToken     | `0x1465E33f687C557BF275D6d692eC1316126d8e9e` |

If you find an issue in a fork or a redeployment that is not one of the addresses above, it is out of scope for this policy.

## Reporting a Vulnerability

Do not open a public GitHub issue for security vulnerabilities. Public disclosure before a fix is in place puts users and their funds at risk.

Use one of the following private channels:

1. GitHub private vulnerability reporting. Go to the Security tab of the repository at https://wane.network/ and click "Report a vulnerability". This opens a private advisory visible only to maintainers.
2. Email. Send details to security@wane.network. Use the PGP key published at https://wane.network/.well-known/security.txt if you need to encrypt the report.

Please include as much of the following as you can:

- A clear description of the issue and the impact you believe it has.
- The contract address or SDK version affected.
- Step-by-step reproduction, ideally a Foundry test or a minimal script that demonstrates the issue.
- Any relevant transaction hashes, addresses, or call data.
- Your assessment of severity and any suggested remediation.

### What to expect

- Acknowledgement of your report within 3 business days.
- An initial assessment and severity classification within 7 business days.
- Regular updates as we investigate and prepare a fix.
- Public credit in the advisory once the issue is resolved, unless you prefer to remain anonymous.

We ask that you give us a reasonable window to investigate and ship a fix before any public disclosure. We will coordinate a disclosure timeline with you and will not take legal action against researchers who follow this policy in good faith.

## Scope

In scope:

- The Solidity contracts in `src/` (WaneRegistry, WanePolicy, WaneDelegate, WaneToken, WaneHook, WaneTypes, and their interfaces).
- The deployed Base mainnet instances listed above.
- The `wane-sdk` TypeScript package and the example scripts in `examples/`.
- Logic flaws in policy evaluation, EIP-7702 delegate routing, antibody mint/corroborate/challenge/slash flows, and token accounting.

Out of scope:

- Vulnerabilities in third-party dependencies (OpenZeppelin, Uniswap v4-core, viem) that are already publicly known and tracked upstream. Report those to the respective projects.
- Issues that require a compromised private key, a malicious RPC provider, or physical access to a user's machine.
- General Base network, EVM client, or wallet software issues not specific to Wane.
- Gas optimization suggestions, style nits, and missing events that have no security impact. Open a normal issue or pull request for those.
- Denial of service caused solely by spending unbounded gas in calls the caller controls and pays for.
- Social engineering, phishing, and spam targeting maintainers or users.

## Unaudited Code

The Wane contracts have not undergone a third-party security audit. The code is provided as is, and interacting with the deployed contracts on Base mainnet carries real financial risk. Review the source yourself, start with small amounts, and do not commit funds you cannot afford to lose. If a formal audit is completed, the result will be linked from this file and from the repository README.

## Disclosure of Past Issues

Resolved security advisories are published under the Security tab of the repository. Each advisory includes the affected versions, the fix, and credit to the reporter where applicable.
