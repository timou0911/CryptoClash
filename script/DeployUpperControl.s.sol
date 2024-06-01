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
            uint64 VRF_subscriptionId,
            bytes32 gasLane,
            uint32 VRF_callbackGasLimit,
            address vrfCoordinator,
            uint64 AI_subscriptionId,
            uint32 AI_callbackGasLimit,
            bytes32 donID,
            address router,
            uint256 interval,
            address link,
            uint256 deployerKey,
            // address deployerAddress
        ) = helperConfig.activeNetworkConfig();

        if (VRF_subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (VRF_subscriptionId, vrfCoordinator) = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                VRF_subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        UpperControl upperControl = new UpperControl(
            VRF_subscriptionId,
            gasLane,
            VRF_callbackGasLimit,
            vrfCoordinator,
            AI_subscriptionId, // 2858, https://functions.chain.link/sepolia/2858
            AI_callbackGasLimit, // 300000
            donID, // 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000
            router, // 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
            interval // 30 seconds
        );
        vm.stopBroadcast();

        addConsumer.addConsumer(
            address(upperControl),
            vrfCoordinator,
            VRF_subscriptionId,
            deployerKey
        );
        return (upperControl, helperConfig);
    }
}