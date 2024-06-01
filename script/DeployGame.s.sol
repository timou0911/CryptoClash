// SPDX-License_Identifier: MIT

pragma solidity ^0.8.19;

import { Game } from "../src/Game.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployGame is Script {
    function run() external returns (Game, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 deployerKey,
            address deployerAddress
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        Game game = new Game(
            deployerAddress
        );
        vm.stopBroadcast();

        return (game, helperConfig);
    }
}