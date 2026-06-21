# Support

Thanks for using Wane, the shared on-chain immune memory layer for AI agents on Base mainnet. This document explains where to get help and how to reach us.

## Documentation

Start with the docs before opening an issue. Most questions about contract behavior, the SDK, policy scopes, and EIP-7702 delegation are answered there.

- Project docs: https://github.com/WaneProtocol/wane-base/tree/main/docs
- README and quick start: https://github.com/WaneProtocol/wane-base/blob/main/README.md
- Website: https://wane.network

## Questions and discussion

For open-ended questions, integration help, or design discussion, use GitHub Discussions:

- https://github.com/WaneProtocol/wane-base/discussions

Good fits for Discussions:

- How to wire `wane-sdk` into an existing agent
- Choosing policy scopes for a given agent
- Understanding antibody lifecycle (check, mint, corroborate, challenge, slash)
- General "how do I" and "is this the right approach" questions

## Bug reports and feature requests

If you have found a reproducible bug or want to propose a feature, open an issue. Please use the templates so we have enough context to act.

- New issue: https://github.com/WaneProtocol/wane-base/issues/new/choose
- Bug report template: https://github.com/WaneProtocol/wane-base/issues/new?template=bug_report.md
- Feature request template: https://github.com/WaneProtocol/wane-base/issues/new?template=feature_request.md

Before filing, search existing issues to avoid duplicates:

- https://github.com/WaneProtocol/wane-base/issues?q=is%3Aissue

When reporting a contract or SDK bug, include:

- Network and chain id (Base mainnet, 8453)
- The exact contract address you interacted with
- `wane-sdk` version and viem version
- A minimal reproduction (script or transaction hash)
- Expected versus actual behavior

## Security issues

Do not report security vulnerabilities through public issues or Discussions. Follow the responsible disclosure process in SECURITY.md:

- https://github.com/WaneProtocol/wane-base/blob/main/SECURITY.md

## Deployed contracts (Base mainnet, chain id 8453)

For quick reference when reporting issues:

- WaneRegistry: 0x027F371fB139A57EcD2A2E175d30157eEA1C56de
- WanePolicy: 0x26deE4503C7f67356837ED41cE285026EF256667
- WaneDelegate: 0x9175d735D512d730510148ED4D6702eF99CF4901
- WaneToken: 0x1465E33f687C557BF275D6d692eC1316126d8e9e

Verify any of these on BaseScan at https://basescan.org/address/<address> before interacting.

## Updates and announcements

Release notes and changes ship in CHANGELOG.md:

- https://github.com/WaneProtocol/wane-base/blob/main/CHANGELOG.md

Follow ongoing updates on X:

- https://x.com/wanedotnetwork

## Response expectations

Wane is maintained by a small team. We triage issues and Discussions as time allows and prioritize confirmed bugs and security reports. Clear reproductions get answered faster.
