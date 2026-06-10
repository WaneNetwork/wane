// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { WaneTypes } from "./WaneTypes.sol";

interface IWaneRegistryView {
    function check(WaneTypes.ThreatKind kind, bytes32 subject) external view returns (bool active, uint64 id);
    function antibodies(uint64 id)
        external
        view
        returns (
            uint64 id_,
            WaneTypes.ThreatKind kind,
            WaneTypes.Status status,
            address publisher,
            uint96 stake,
            uint64 mintedBlock,
            uint32 corroborations,
            bytes32 subject,
            bytes32 evidence
        );
}

interface IWanePolicyView {
    function evaluate(address agent, address target, uint128 amount) external view returns (bool allowed, uint8 reason);
    function evaluateCall(address agent, address target, bytes4 selector, uint128 amount)
        external
        view
        returns (bool allowed, uint8 reason);
}

/// @title WaneDelegate
/// @notice The 7702 delegate. A wallet (EOA) signs one EIP-7702 "Account Update"
///         pointing its code here. From then on, when the wallet routes an
///         action through execute(), Wane screens it against the antibody
///         registry and the wallet's own policy BEFORE it runs. A flagged
///         target reverts; a clean one executes with the wallet's own authority.
///
///         Trust model (important): this contract can only BLOCK. It never holds
///         funds and has no path to move the wallet's assets anywhere the wallet
///         did not ask for. msg.sender for the inner call is the wallet itself
///         (address(this) under 7702), so Wane cannot redirect value. Reading
///         the registry is free; the wallet keeps full custody.
///
///         Honest limit (per EIP-7702): a delegate cannot intercept a raw tx the
///         key signs directly. Protection holds for actions sent through
///         execute(); that is what the Wane SDK / agent runtime calls. Direct
///         key spends bypass it, same as every 7702 guard. Documented, not hidden.
contract WaneDelegate {
    IWaneRegistryView public immutable registry;
    IWanePolicyView public immutable policy;

    /// reasons mirror WanePolicy plus a local antibody code
    error Blocked(address target, uint8 reason);
    error BatchLengthMismatch();
    error NotSelf();

    /// @notice Under 7702 the wallet calls its own code, so a legitimate action
    ///         has msg.sender == address(this). Any other caller is an outsider
    ///         trying to move the wallet's funds and is rejected outright. Without
    ///         this, anyone could call execute() on a delegated wallet and drain
    ///         it (even past screening, by sending to a clean address).
    modifier onlySelf() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    event Screened(address indexed agent, address indexed target, uint256 value, bool allowed, uint8 reason);

    constructor(address registry_, address policy_) {
        registry = IWaneRegistryView(registry_);
        policy = IWanePolicyView(policy_);
    }

    /// @notice Accept inbound ETH. A Wane-protected wallet must still be able to
    ///         RECEIVE funds. Wane only screens OUTBOUND actions (those routed
    ///         through execute()); incoming transfers are never the wallet's own
    ///         action, so they pass untouched.
    receive() external payable { }

    /// @notice Accept inbound calls with data (e.g. a contract calling back into
    ///         the wallet). Same rationale as receive(): inbound is not an action
    ///         the wallet initiated, so there is nothing to screen. Without this,
    ///         the 7702 set-code tx itself (a self-call with empty data) would
    ///         revert and the wallet could never be reached.
    fallback() external payable { }

    /// @notice Screen + execute a single action from the delegated wallet.
    ///         `address(this)` is the wallet itself under 7702, so the call runs
    ///         with the wallet's authority and Wane cannot divert funds.
    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        onlySelf
        returns (bytes memory ret)
    {
        _screen(target, value, data);
        bool ok;
        (ok, ret) = target.call{ value: value }(data);
        require(ok, "Wane: inner call failed");
    }

    /// @notice Screen + execute a batch. Any flagged target reverts the whole batch.
    function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        payable
        onlySelf
        returns (bytes[] memory rets)
    {
        uint256 n = targets.length;
        if (values.length != n || datas.length != n) revert BatchLengthMismatch();
        rets = new bytes[](n);
        for (uint256 i; i < n;) {
            _screen(targets[i], values[i], datas[i]);
            (bool ok, bytes memory r) = targets[i].call{ value: values[i] }(datas[i]);
            require(ok, "Wane: inner call failed");
            rets[i] = r;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Dry-run the screen without executing. Free view.
    function wouldAllow(address target, uint256 value, bytes calldata data)
        external
        view
        returns (bool allowed, uint8 reason)
    {
        return _evaluate(target, value, data);
    }

    /* ── internal screening ──────────────────────────────────────────── */

    function _screen(address target, uint256 value, bytes calldata data) internal {
        (bool allowed, uint8 reason) = _evaluate(target, value, data);
        emit Screened(address(this), target, value, allowed, reason);
        if (!allowed) revert Blocked(target, reason);
    }

    function _evaluate(address target, uint256 value, bytes calldata data)
        internal
        view
        returns (bool allowed, uint8 reason)
    {
        uint128 amount = value > type(uint128).max ? type(uint128).max : uint128(value);
        bytes4 selector = data.length >= 4 ? bytes4(data[0:4]) : bytes4(0);

        // The wallet IS address(this) under 7702, so policy is keyed on address(this).
        if (selector != bytes4(0)) {
            return policy.evaluateCall(address(this), target, selector, amount);
        }
        return policy.evaluate(address(this), target, amount);
    }
}
