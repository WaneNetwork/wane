// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { WanePolicy } from "../src/WanePolicy.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WaneToken } from "../src/WaneToken.sol";
import { WaneTypes } from "../src/WaneTypes.sol";

contract WanePolicyTest is Test {
    WaneToken token;
    WaneRegistry reg;
    WanePolicy pol;

    address treasury = makeAddr("treasury");
    address owner = makeAddr("owner");
    address guardian; // = deployer (this)
    address bot = makeAddr("bot");
    address drainer = makeAddr("drainer");
    address friend = makeAddr("friend");

    uint8 ALL;
    uint8 BYTECODE;

    function setUp() public {
        token = new WaneToken(treasury);
        reg = new WaneRegistry(address(token), treasury);
        pol = new WanePolicy(address(reg)); // deployer = guardian
        guardian = address(this);
        ALL = pol.K_ALL();
        BYTECODE = pol.K_BYTECODE();

        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](1);
        bytes32[] memory s = new bytes32[](1);
        bytes32[] memory e = new bytes32[](1);
        k[0] = WaneTypes.ThreatKind.Address;
        s[0] = bytes32(uint256(uint160(drainer)));
        e[0] = keccak256("seed");
        reg.seedGenesis(k, s, e);
    }

    function _enroll() internal {
        vm.prank(owner);
        pol.enroll(bot, ALL, 0, 0, 0, 0); // all kinds, no sensitivity/caps/ttl
    }

    /* ── existing core (regression) ──────────────────────────────────── */

    function test_EnrollClaimsOwnership() public {
        _enroll();
        (address o, bool enabled,,,,,,,,,,) = pol.policies(bot);
        assertEq(o, owner);
        assertTrue(enabled);
    }

    function test_EnrolledAgentBlocksDrainer() public {
        _enroll();
        (bool ok, uint8 reason) = pol.evaluate(bot, drainer, 0);
        assertFalse(ok);
        assertEq(reason, pol.R_ANTIBODY());
    }

    function test_UnenrolledPasses() public view {
        (bool ok,) = pol.evaluate(bot, drainer, 0);
        assertTrue(ok);
    }

    function test_PerTxCap() public {
        vm.prank(owner);
        pol.enroll(bot, ALL, 0, 1 ether, 0, 0);
        (bool ok, uint8 reason) = pol.evaluate(bot, friend, 2 ether);
        assertFalse(ok);
        assertEq(reason, pol.R_PERTX());
    }

    /* ── NEW: kill switch + global pause ─────────────────────────────── */

    function test_OwnerKillSwitch() public {
        _enroll();
        vm.prank(owner);
        pol.setPaused(bot, true);
        (bool ok, uint8 reason) = pol.evaluate(bot, friend, 0);
        assertFalse(ok);
        assertEq(reason, pol.R_PAUSED());
    }

    function test_GuardianCanKillAgent() public {
        _enroll();
        // guardian (this contract) can pause someone else's agent
        pol.setPaused(bot, true);
        (bool ok, uint8 reason) = pol.evaluate(bot, friend, 0);
        assertFalse(ok);
        assertEq(reason, pol.R_PAUSED());
    }

    function test_StrangerCannotKill() public {
        _enroll();
        vm.prank(drainer);
        vm.expectRevert(WanePolicy.NotGuardianOrOwner.selector);
        pol.setPaused(bot, true);
    }

    function test_GlobalPauseHaltsAll() public {
        _enroll();
        pol.setGlobalPaused(true); // guardian
        (bool ok, uint8 reason) = pol.evaluate(bot, friend, 0);
        assertFalse(ok);
        assertEq(reason, pol.R_PAUSED());
    }

    function test_OnlyGuardianGlobalPause() public {
        vm.prank(owner);
        vm.expectRevert(WanePolicy.NotGuardian.selector);
        pol.setGlobalPaused(true);
    }

    /* ── NEW: global recipient denylist ──────────────────────────────── */

    function test_GlobalDenylist() public {
        _enroll();
        pol.setGlobalDenied(friend, true); // guardian curates
        (bool ok, uint8 reason) = pol.evaluate(bot, friend, 0);
        assertFalse(ok);
        assertEq(reason, pol.R_GLOBAL_DENY());
    }

    /* ── NEW: policy expiry (TTL) ────────────────────────────────────── */

    function test_PolicyExpiry() public {
        uint40 exp = uint40(block.timestamp + 1 days);
        vm.prank(owner);
        pol.enroll(bot, ALL, 0, 0, 0, exp);
        // before expiry: drainer still blocked (policy active)
        (bool ok1,) = pol.evaluate(bot, drainer, 0);
        assertFalse(ok1);
        // after expiry: everything denied with R_EXPIRED
        vm.warp(block.timestamp + 2 days);
        (bool ok2, uint8 reason) = pol.evaluate(bot, friend, 0);
        assertFalse(ok2);
        assertEq(reason, pol.R_EXPIRED());
    }

    /* ── NEW: function-selector allowlist + K_CALL ───────────────────── */

    function test_SelectorAllowlist() public {
        _enroll();
        bytes4 swapSel = bytes4(keccak256("swap(uint256)"));
        bytes4 approveSel = bytes4(keccak256("approve(address,uint256)"));
        vm.startPrank(owner);
        pol.setSelectorScoped(bot, true);
        pol.setSelector(bot, swapSel, true); // only swap allowed
        vm.stopPrank();

        // swap on a clean target passes
        (bool okSwap,) = pol.evaluateCall(bot, friend, swapSel, 0);
        assertTrue(okSwap, "allowed selector passes");
        // approve is blocked (infinite-approve drain vector)
        (bool okApprove, uint8 reason) = pol.evaluateCall(bot, friend, approveSel, 0);
        assertFalse(okApprove);
        assertEq(reason, pol.R_SELECTOR());
    }

    function test_SelectorIgnoredWhenNotScoped() public {
        _enroll(); // selectorScoped = false
        bytes4 approveSel = bytes4(keccak256("approve(address,uint256)"));
        (bool ok,) = pol.evaluateCall(bot, friend, approveSel, 0);
        assertTrue(ok, "no selector scope => any selector passes");
    }

    /* ── NEW: token allowlist ────────────────────────────────────────── */

    function test_TokenAllowlist() public {
        _enroll();
        address goodToken = makeAddr("goodToken");
        address scamToken = makeAddr("scamToken");
        vm.startPrank(owner);
        pol.setTokenScoped(bot, true);
        pol.setToken(bot, goodToken, true);
        vm.stopPrank();

        assertTrue(pol.isTokenAllowed(bot, goodToken), "allowed token ok");
        assertFalse(pol.isTokenAllowed(bot, scamToken), "scam token blocked");
    }

    function test_TokenAllAllowedWhenNotScoped() public {
        _enroll();
        assertTrue(pol.isTokenAllowed(bot, makeAddr("anything")), "no token scope => all allowed");
    }

    /* ── allow/block still work ──────────────────────────────────────── */

    function test_AllowlistOverridesAntibody() public {
        _enroll();
        vm.prank(owner);
        pol.setAllow(bot, drainer, true);
        (bool ok,) = pol.evaluate(bot, drainer, 0);
        assertTrue(ok);
    }
}

