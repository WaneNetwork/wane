// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Script, console2 } from "forge-std/Script.sol";
import { WaneToken } from "../src/WaneToken.sol";
import { WaneRegistry } from "../src/WaneRegistry.sol";
import { WanePolicy } from "../src/WanePolicy.sol";
import { WaneDelegate } from "../src/WaneDelegate.sol";

/// @notice Base mainnet deploy: the four core contracts in one broadcast.
///         token -> registry -> policy -> delegate. The v4 hook is optional and
///         deployed separately (needs a CREATE2-mined address + a PoolManager).
///         Genesis seeding is done afterward via SeedGenesis.s.sol.
///
/// Env:
///   PRIVATE_KEY  deployer (also initial governor)
///   TREASURY     treasury (defaults to deployer)
contract DeployMainnet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address treasury = vm.envOr("TREASURY", deployer);

        vm.startBroadcast(pk);

        WaneToken token = new WaneToken(treasury);
        console2.log("WaneToken   :", address(token));

        WaneRegistry reg = new WaneRegistry(address(token), treasury);
        console2.log("WaneRegistry:", address(reg));

        WanePolicy pol = new WanePolicy(address(reg));
        console2.log("WanePolicy  :", address(pol));

        WaneDelegate del = new WaneDelegate(address(reg), address(pol));
        console2.log("WaneDelegate:", address(del));

        vm.stopBroadcast();

        console2.log("--- deployed on chainid", block.chainid, "---");
    }
}
