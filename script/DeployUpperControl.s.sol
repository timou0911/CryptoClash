// SPDX-License_Identifier: MIT

pragma solidity ^0.8.19;

import { UpperControl } from "../src/UpperControl.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { AddConsumer, CreateSubscription, FundSubscription } from "./Interactions.s.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployUpperControl is Script {
    function run() external returns (UpperControl, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        (
            uint64 subscriptionId,
            bytes32 gasLane,
            uint32 callbackGasLimit,
            address vrfCoordinator,
            address link,
            uint256 deployerKey,
            address deployerAddress
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subscriptionId, vrfCoordinator) = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        UpperControl upperControl = new UpperControl(
            subscriptionId,
            gasLane,
            callbackGasLimit,
            vrfCoordinator
        );
        vm.stopBroadcast();

        addConsumer.addConsumer(
            address(upperControl),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );
        return (upperControl, helperConfig);
    }
}