// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WaneToken } from "../src/WaneToken.sol";
import { WaneTypes } from "../src/WaneTypes.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WaneRegistryTest is Test {
    WaneToken token;
    WaneRegistry reg;

    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice"); // attacked agent / publisher
    address bob = makeAddr("bob");
    address carol = makeAddr("carol"); // challenger
    address eve = makeAddr("eve"); // griefer
    address victim = makeAddr("victim"); // innocent address eve tries to censor
    address drainer = makeAddr("drainer");

    uint96 constant MINT = 100e18;
    uint96 constant CHAL = 200e18;

    function setUp() public {
        token = new WaneToken(treasury);
        reg = new WaneRegistry(address(token), treasury);

        vm.startPrank(treasury);
        token.transfer(alice, 10_000e18);
        token.transfer(bob, 10_000e18);
        token.transfer(carol, 10_000e18);
        token.transfer(eve, 10_000e18);
        vm.stopPrank();

        for (uint256 i; i < 4; ++i) {
            address u = [alice, bob, carol, eve][i];
            vm.prank(u);
            token.approve(address(reg), type(uint256).max);
        }
    }

    function _subj(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _mintDrainer(address by) internal returns (uint64 id) {
        vm.prank(by);
        id = reg.mintAntibody(WaneTypes.ThreatKind.Address, _subj(drainer), keccak256("evidence"));
    }

    /* ── enforcement gating (C-1 fix: young antibody is NOT weaponizable) ─ */

    function test_FreshAntibodyDoesNotEnforceImmediately() public {
        _mintDrainer(alice);
        // not enforceable yet: no corroborations, window not elapsed
        (bool active,) = reg.checkAddress(drainer);
        assertFalse(active, "fresh antibody must not block until window/corrobs");
    }

    function test_EnforcesAfterWindow() public {
        _mintDrainer(alice);
        vm.roll(block.number + reg.enforceWindow());
        (bool active,) = reg.checkAddress(drainer);
        assertTrue(active, "enforces after window elapses");
    }

    function test_EnforcesAfterCorroborations() public {
        uint64 id = _mintDrainer(alice);
        vm.prank(bob);
        reg.corroborate(id);
        vm.prank(carol);
        reg.corroborate(id); // reaches enforceCorrobs (2)
        (bool active,) = reg.checkAddress(drainer);
        assertTrue(active, "enforces once corroboration threshold met");
    }

    /* ── C-1b fix: a Challenged antibody stays fail-closed ───────────── */

    function test_DrainerCannotUnblockBySelfChallenging() public {
        uint64 id = _mintDrainer(alice);
        vm.roll(block.number + reg.enforceWindow()); // now enforcing
        assertTrue(_active(drainer), "blocking before challenge");

        // drainer (via eve) challenges to try to un-block itself
        vm.prank(eve);
        reg.challenge(id);

        // still blocked during dispute (fail-closed)
        assertTrue(_active(drainer), "must stay blocked while challenged");
    }

    /* ── C-1: false flag censorship is mitigated by gating + slashing ── */

    function test_FalseFlagDoesNotInstantlyCensor() public {
        // eve flags an innocent victim
        vm.prank(eve);
        reg.mintAntibody(WaneTypes.ThreatKind.Address, _subj(victim), keccak256("lie"));
        // victim is NOT blocked immediately (gating gives time to challenge)
        assertFalse(_active(victim), "innocent victim not instantly censored");
    }

    function test_FalseFlagSlashedOnResolve() public {
        vm.prank(eve);
        uint64 id =
            reg.mintAntibody(WaneTypes.ThreatKind.Address, _subj(victim), keccak256("lie"));

        uint256 carolBefore = token.balanceOf(carol);
        vm.prank(carol);
        reg.challenge(id);
        reg.resolve(id, true); // governor: false positive => eve slashed

        // victim free, carol recovered bond + took eve's stake
        assertFalse(_active(victim));
        assertEq(token.balanceOf(carol), carolBefore + MINT, "challenger nets slashed stake");
    }

    /* ── M-2 fix: revoked key can be re-flagged ──────────────────────── */

    function test_RevokedKeyCanBeReflagged() public {
        uint64 id = _mintDrainer(alice);
        vm.prank(carol);
        reg.challenge(id);
        reg.resolve(id, true); // revoked, key cleared

        // someone can mint a fresh antibody on the same subject again
        uint64 id2 = _mintDrainer(bob);
        assertGt(id2, id, "re-flag mints a new antibody");
    }

    /* ── upheld challenge: challenger slashed, publisher rewarded ─────── */

    function test_ChallengeUpheld_SlashesChallenger() public {
        uint64 id = _mintDrainer(alice);
        vm.prank(carol);
        reg.challenge(id);
        reg.resolve(id, false); // upheld

        assertTrue(_activeAfterWindow(drainer), "upheld antibody enforces");

        uint256 before = token.balanceOf(alice);
        vm.prank(alice);
        reg.claimRewards();
        assertEq(token.balanceOf(alice), before + CHAL, "publisher gets challenger bond");
    }

    /* == C-2: solvency invariant, payouts never strand other claims == */

    function test_SolvencyInvariant_AfterMixedFlows() public {
        // alice mints, carol challenges & loses (upheld)
        uint64 id = _mintDrainer(alice);
        vm.prank(carol);
        reg.challenge(id);
        reg.resolve(id, false);

        // bob mints another, matures, reclaims
        vm.prank(bob);
        uint64 id2 = reg.mintAntibody(WaneTypes.ThreatKind.Address, _subj(eve), keccak256("e"));
        assertGt(id2, 0);
        vm.roll(block.number + reg.maturity());
        vm.prank(bob);
        reg.reclaimStake(id2);

        // alice claims her reward (challenger's forfeited bond)
        vm.prank(alice);
        reg.claimRewards();

        // INVARIANT: contract balance always covers reserved liabilities
        assertGe(token.balanceOf(address(reg)), reg.reserved(), "never insolvent");
        // and alice can still reclaim her own original stake after maturity
        vm.roll(block.number + reg.maturity());
        vm.prank(alice);
        reg.reclaimStake(id); // must not revert / must be funded
        assertGe(token.balanceOf(address(reg)), reg.reserved(), "still solvent after all claims");
    }

    /* ── genesis: zero users, instant immunity, enforces immediately ── */

    function test_GenesisImmuneWithZeroUsers() public {
        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](1);
        bytes32[] memory s = new bytes32[](1);
        bytes32[] memory e = new bytes32[](1);
        k[0] = WaneTypes.ThreatKind.Address;
        s[0] = _subj(drainer);
        e[0] = keccak256("scamsniffer");
        reg.seedGenesis(k, s, e);

        // genesis (stake==0) enforces immediately, no window needed
        assertTrue(_active(drainer), "genesis drainer blocked from block one");
    }

    function test_GenesisLengthMismatchReverts() public {
        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](2);
        bytes32[] memory s = new bytes32[](1);
        bytes32[] memory e = new bytes32[](2);
        vm.expectRevert(WaneRegistry.LengthMismatch.selector);
        reg.seedGenesis(k, s, e);
    }

    /* ── admin hardening ─────────────────────────────────────────────── */

    function test_TwoStepGovernorTransfer() public {
        reg.transferGovernor(bob);
        assertEq(reg.governor(), address(this), "not yet transferred");
        vm.prank(bob);
        reg.acceptGovernor();
        assertEq(reg.governor(), bob, "transferred after accept");
    }

    function test_PublisherBpsCappedAt10000() public {
        vm.expectRevert(WaneRegistry.BadParams.selector);
        reg.setParams(MINT, CHAL, 21_600, 10_001, 0);
    }

    function test_PauseBlocksWritesAndReads() public {
        uint64 id = _mintDrainer(alice);
        vm.roll(block.number + reg.enforceWindow());
        assertTrue(_active(drainer));

        reg.setPaused(true);
        (bool active,) = reg.checkAddress(drainer);
        assertFalse(active, "paused registry returns clear");

        vm.prank(alice);
        vm.expectRevert(WaneRegistry.Paused.selector);
        reg.mintAntibody(WaneTypes.ThreatKind.Address, _subj(bob), bytes32(0));
    }

    function test_OnlyGovernorSeeds() public {
        WaneTypes.ThreatKind[] memory k = new WaneTypes.ThreatKind[](0);
        bytes32[] memory s = new bytes32[](0);
        bytes32[] memory e = new bytes32[](0);
        vm.prank(alice);
        vm.expectRevert(WaneRegistry.NotGovernor.selector);
        reg.seedGenesis(k, s, e);
    }

    /* ── read path gas (hook-friendly) ───────────────────────────────── */

    function test_CheckGasIsCheap() public {
        _mintDrainer(alice);
        vm.roll(block.number + reg.enforceWindow());
        uint256 g = gasleft();
        reg.checkAddress(drainer);
        uint256 used = g - gasleft();
        emit log_named_uint("checkAddress gas", used);
        assertLt(used, 15_000, "read path stays hook-cheap");
    }

    /* ── helpers ─────────────────────────────────────────────────────── */

    function _active(address a) internal view returns (bool x) {
        (x,) = reg.checkAddress(a);
    }

    function _activeAfterWindow(address a) internal returns (bool x) {
        vm.roll(block.number + reg.enforceWindow());
        (x,) = reg.checkAddress(a);
    }
}
