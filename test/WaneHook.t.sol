// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { WaneHook } from "../src/WaneHook.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WaneToken } from "../src/WaneToken.sol";
import { WaneTypes } from "../src/WaneTypes.sol";
import { PoolKey } from "v4-core/src/types/PoolKey.sol";
import { SwapParams } from "v4-core/src/types/PoolOperation.sol";
import { Currency } from "v4-core/src/types/Currency.sol";
import { IHooks } from "v4-core/src/interfaces/IHooks.sol";

/// @notice Proves the hook makes immunity automatic: a flagged drainer cannot
///         swap on a Wane-protected pool, while a clean agent passes.
contract WaneHookTest is Test {
    WaneToken token;
    WaneRegistry reg;
    WaneHook hook;

    address treasury = makeAddr("treasury");
    address poolManager = makeAddr("poolManager");
    address alice = makeAddr("alice"); // clean agent
    address drainer = makeAddr("drainer"); // flagged

    PoolKey key;
    SwapParams params;

    function setUp() public {
        token = new WaneToken(treasury);
        reg = new WaneRegistry(address(token), treasury);
        hook = new WaneHook(address(reg), poolManager, address(this));

        // governor seeds the drainer as a known threat (genesis)
        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](1);
        bytes32[] memory s = new bytes32[](1);
        bytes32[] memory e = new bytes32[](1);
        k[0] = WaneTypes.ThreatKind.Address;
        s[0] = bytes32(uint256(uint160(drainer)));
        e[0] = keccak256("scamsniffer");
        reg.seedGenesis(k, s, e);

        params = SwapParams({ zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 0 });
    }

    function test_DrainerCannotSwap() public {
        // pool manager forwards the swap; drainer is the sender
        vm.prank(poolManager);
        vm.expectRevert(abi.encodeWithSelector(WaneHook.Blocked.selector, drainer, uint64(1)));
        hook.beforeSwap(drainer, key, params, "");
    }

    function test_CleanAgentSwapsFine() public {
        vm.prank(poolManager);
        (bytes4 sel,,) = hook.beforeSwap(alice, key, params, "");
        assertEq(sel, IHooks.beforeSwap.selector, "clean agent passes the hook");
    }

    function test_OnlyPoolManagerCanCallHook() public {
        vm.prank(alice);
        vm.expectRevert(WaneHook.NotPoolManager.selector);
        hook.beforeSwap(alice, key, params, "");
    }
}
