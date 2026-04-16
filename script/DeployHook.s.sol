// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Script, console2 } from "forge-std/Script.sol";
import { WaneHook } from "../src/WaneHook.sol";

/// @notice Mine a CREATE2 salt so the hook address ends in the BEFORE_SWAP_FLAG
///         bit (1<<7 = 0x80) that Uniswap v4 requires, then deploy via the
///         canonical CREATE2 deployer.
///
/// Env: PRIVATE_KEY, WANE_REGISTRY, V4_POOL_MANAGER, GUARDIAN
contract DeployHook is Script {
    // canonical deterministic CREATE2 deployer (same address on every chain)
    address constant CREATE2 = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint160 constant FLAGS = uint160(1 << 7); // BEFORE_SWAP_FLAG
    uint160 constant FLAG_MASK = uint160(0x3FFF); // v4 uses low 14 bits for flags

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address registry = vm.envAddress("WANE_REGISTRY");
        address pm = vm.envAddress("V4_POOL_MANAGER");
        address guardian = vm.envAddress("GUARDIAN");

        bytes memory creation = abi.encodePacked(
            type(WaneHook).creationCode,
            abi.encode(registry, pm, guardian)
        );
        bytes32 initHash = keccak256(creation);

        // mine salt: address low 14 bits must equal FLAGS exactly
        bytes32 salt;
        address predicted;
        for (uint256 i = 0; i < 500_000; i++) {
            bytes32 s = bytes32(i);
            address a = _create2Addr(s, initHash);
            if (uint160(a) & FLAG_MASK == FLAGS) {
                salt = s;
                predicted = a;
                break;
            }
        }
        require(predicted != address(0), "salt not found");
        console2.log("mined salt index:", uint256(salt));
        console2.log("predicted hook  :", predicted);

        vm.startBroadcast(pk);
        // deploy through CREATE2 deployer: salt ++ creationCode
        (bool ok,) = CREATE2.call(abi.encodePacked(salt, creation));
        require(ok, "create2 deploy failed");
        vm.stopBroadcast();

        require(predicted.code.length > 0, "hook has no code at predicted addr");
        console2.log("WaneHook deployed:", predicted);
    }

    function _create2Addr(bytes32 salt, bytes32 initHash) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2, salt, initHash))))
        );
    }
}
