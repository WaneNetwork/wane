// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { WaneDelegate } from "../src/WaneDelegate.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WanePolicy } from "../src/WanePolicy.sol";
import { WaneToken } from "../src/WaneToken.sol";
import { WaneTypes } from "../src/WaneTypes.sol";

/// @notice Simulates a 7702-delegated wallet routing actions through execute().
///         Verifies: drainer target is blocked, clean target executes, and the
///         delegate has no path to divert the wallet's funds.
contract WaneDelegateTest is Test {
    WaneToken token;
    WaneRegistry reg;
    WanePolicy pol;
    WaneDelegate del;

    address treasury = makeAddr("treasury");
    address wallet; // the EOA that "becomes" the delegate under 7702
    address drainer = makeAddr("drainer");
    address friend = makeAddr("friend");

    function setUp() public {
        token = new WaneToken(treasury);
        reg = new WaneRegistry(address(token), treasury);
        pol = new WanePolicy(address(reg));
        del = new WaneDelegate(address(reg), address(pol));

        // seed drainer as genesis antibody (enforces immediately)
        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](1);
        bytes32[] memory s = new bytes32[](1);
        bytes32[] memory e = new bytes32[](1);
        k[0] = WaneTypes.ThreatKind.Address;
        s[0] = bytes32(uint256(uint160(drainer)));
        e[0] = keccak256("seed");
        reg.seedGenesis(k, s, e);

        // under 7702, the delegate code runs AT the wallet address. We emulate
        // that by having the wallet == the delegate's perspective: the policy is
        // keyed on address(this) inside the delegate. For the test we enroll the
        // delegate's address as the agent and call through it.
        wallet = address(del); // address(this) inside delegate == del's address

        // enroll the "wallet" (delegate address) with full protection
        vm.prank(address(del));
        pol.enroll(wallet, pol.K_ALL(), 0, 0, 0, 0);
    }

    /* ── drainer blocked through execute() ───────────────────────────── */

    function test_DrainerBlockedThroughExecute() public {
        vm.expectRevert(abi.encodeWithSelector(WaneDelegate.Blocked.selector, drainer, pol.R_ANTIBODY()));
        vm.prank(address(del));
        del.execute(drainer, 0, "");
    }

    /* ── only the wallet itself may call execute() ───────────────────── */

    function test_OutsiderCannotExecute() public {
        vm.deal(address(del), 1 ether);
        vm.expectRevert(WaneDelegate.NotSelf.selector);
        vm.prank(makeAddr("attacker"));
        del.execute(friend, 0.5 ether, "");
    }

    /* ── clean target executes ───────────────────────────────────────── */

    function test_CleanTargetExecutes() public {
        // friend is a plain EOA; a value-send with empty data should pass + run
        vm.deal(address(del), 1 ether);
        uint256 before = friend.balance;
        vm.prank(address(del));
        del.execute(friend, 0.5 ether, "");
        assertEq(friend.balance, before + 0.5 ether, "clean send went through");
    }

    /* ── dry-run matches ─────────────────────────────────────────────── */

    function test_WouldAllow() public view {
        (bool okDrain,) = del.wouldAllow(drainer, 0, "");
        assertFalse(okDrain, "drainer not allowed");
        (bool okClean,) = del.wouldAllow(friend, 0, "");
        assertTrue(okClean, "clean allowed");
    }

    /* ── batch: one drainer reverts whole batch ──────────────────────── */

    function test_BatchRevertsOnDrainer() public {
        vm.deal(address(del), 1 ether);
        address[] memory t = new address[](2);
        uint256[] memory v = new uint256[](2);
        bytes[] memory d = new bytes[](2);
        t[0] = friend; v[0] = 0.1 ether; d[0] = "";
        t[1] = drainer; v[1] = 0; d[1] = "";
        vm.expectRevert(abi.encodeWithSelector(WaneDelegate.Blocked.selector, drainer, pol.R_ANTIBODY()));
        vm.prank(address(del));
        del.executeBatch(t, v, d);
    }

    /* ── delegate cannot divert funds: inner call uses given target only ─ */

    function test_NoFundDiversion() public {
        // delegate executes exactly what it's told (friend), nowhere else.
        vm.deal(address(del), 1 ether);
        vm.prank(address(del));
        del.execute(friend, 0.3 ether, "");
        assertEq(friend.balance, 0.3 ether);
        assertEq(address(del).balance, 0.7 ether, "remainder stays with wallet");
    }
}
