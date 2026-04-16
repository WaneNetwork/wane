// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Script, console2 } from "forge-std/Script.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WaneTypes } from "../src/WaneTypes.sol";

/// @notice Bulk-seed the registry with known malicious addresses (MEW
///         ethereum-lists darklist, MIT-licensed). Reads addresses from
///         script/data/genesis-addresses.json and seeds in batches.
///
/// Usage:
///   forge script script/SeedGenesis.s.sol:SeedGenesis \
///     --rpc-url base_sepolia --broadcast -vvv
///
/// Env:
///   PRIVATE_KEY        deployer / governor
///   WANE_REGISTRY      deployed registry address
///   SEED_BATCH         batch size (default 100)
///   SEED_OFFSET        start index (default 0), for resuming across runs
contract SeedGenesis is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address regAddr = vm.envAddress("WANE_REGISTRY");
        uint256 batch = vm.envOr("SEED_BATCH", uint256(100));
        uint256 offset = vm.envOr("SEED_OFFSET", uint256(0));

        WaneRegistry reg = WaneRegistry(regAddr);

        // read JSON array of address strings
        string memory json = vm.readFile("script/data/genesis-addresses.json");
        address[] memory all = vm.parseJsonAddressArray(json, "");
        uint256 total = all.length;
        console2.log("total addresses in file:", total);
        console2.log("offset:", offset, "batch:", batch);

        uint256 end = offset + batch;
        if (end > total) end = total;
        uint256 n = end > offset ? end - offset : 0;
        if (n == 0) {
            console2.log("nothing to seed in this range");
            return;
        }

        WaneTypes.ThreatKind[] memory kinds = new WaneTypes.ThreatKind[](n);
        bytes32[] memory subjects = new bytes32[](n);
        bytes32[] memory evidence = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            address a = all[offset + i];
            kinds[i] = WaneTypes.ThreatKind.Address;
            subjects[i] = bytes32(uint256(uint160(a)));
            evidence[i] = keccak256(abi.encodePacked("mew-darklist", a));
        }

        vm.startBroadcast(pk);
        reg.seedGenesis(kinds, subjects, evidence);
        vm.stopBroadcast();

        console2.log("seeded range", offset, "to", end);
        console2.log("registry antibodyCount now:", reg.antibodyCount());
    }
}
