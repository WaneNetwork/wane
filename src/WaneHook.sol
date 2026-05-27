// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IHooks } from "v4-core/src/interfaces/IHooks.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { SwapParams, ModifyLiquidityParams } from "v4-core/src/types/PoolOperation.sol";
import { BalanceDelta } from "v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, BeforeSwapDeltaLibrary } from "v4-core/src/types/BeforeSwapDelta.sol";
import { WaneTypes } from "./WaneTypes.sol";

interface IWaneCheck {
    function check(WaneTypes.ThreatKind kind, bytes32 subject)
        external
        view
        returns (bool active, uint64 id);
    function checkAddress(address target) external view returns (bool active, uint64 id);
}

/// @title WaneHook
/// @notice Uniswap v4 hook that makes immunity automatic. Attach it to a pool
///         and every swap is screened against the Wane antibody registry. A
///         flagged swapper (by address OR by contract codehash) is rejected.
///
/// @dev Hardened build:
///   - No tx.origin (AA/4337-unsafe, linter-flagged). We screen `sender` and,
///     when a contract, its runtime codehash (catches re-deployed drainers).
///   - registry call wrapped in try/catch with an explicit fail policy so a
///     registry bug can't brick the pool. Default = fail-OPEN (don't block
///     swaps if the registry reverts); governor can flip to fail-closed.
///   - The address must be CREATE2-mined so its low bits set BEFORE_SWAP_FLAG
///     per v4 hook-address rules (handled in the deploy script).
contract WaneHook is IHooks {
    IWaneCheck public immutable registry;
    address public immutable poolManager;
    address public guardian; // can flip failClosed / detach behavior
    bool public failClosed; // if registry reverts: true = block, false = allow

    error Blocked(address who, uint64 antibodyId);
    error BlockedCode(bytes32 codehash, uint64 antibodyId);
    error NotPoolManager();
    error NotGuardian();
    error RegistryDown();

    event FailModeSet(bool failClosed);

    constructor(address registry_, address poolManager_, address guardian_) {
        registry = IWaneCheck(registry_);
        poolManager = poolManager_;
        guardian = guardian_;
    }

    modifier onlyPoolManager() {
        if (msg.sender != poolManager) revert NotPoolManager();
        _;
    }

    function setFailClosed(bool v) external {
        if (msg.sender != guardian) revert NotGuardian();
        failClosed = v;
        emit FailModeSet(v);
    }

    /// @notice Screened before every swap. Reverts if the swapper is flagged.
    function beforeSwap(address sender, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // 1) address screen
        try registry.checkAddress(sender) returns (bool flagged, uint64 id) {
            if (flagged) revert Blocked(sender, id);
        } catch {
            if (failClosed) revert RegistryDown();
        }

        // 2) bytecode screen (only if sender is a contract), catches re-deploys
        uint256 size;
        assembly {
            size := extcodesize(sender)
        }
        if (size > 0) {
            bytes32 codehash;
            assembly {
                codehash := extcodehash(sender)
            }
            try registry.check(WaneTypes.ThreatKind.Bytecode, codehash) returns (bool f2, uint64 id2) {
                if (f2) revert BlockedCode(codehash, id2);
            } catch {
                if (failClosed) revert RegistryDown();
            }
        }

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /* ── unused hook points: return their selectors, do nothing ──────── */

    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }
}

