// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UpperControl } from "../src/UpperControl.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { Script, console } from "forge-std/Script.sol";
import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol";


contract CreateSubscription is Script {
    function run() external returns (uint64, address) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint64, address) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 deployerPrivateKey
            ,
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerPrivateKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerPrivateKey
    ) public returns (uint64, address) {
        console.log("Creating subscription on chainId: ", block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created with Id: ", subId);
        console.log("Remember to update the subscription ID in HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "UpperControl",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subId,
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 deployerPrivateKey
            ,
        ) = helperConfig.activeNetworkConfig();
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, deployerPrivateKey);
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerPrivateKey
    ) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using VRF coordinator: ", vrfCoordinator);
        console.log("On chain ID: ", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function run() external {
        fundSubscriptionscriptionUsingConfig();
    }

    function fundSubscriptionscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint64 subId,
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            ,
            address link,
            uint256 deployerPrivateKey
            ,
        ) = helperConfig.activeNetworkConfig();

        if (subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (uint64 updatedSubId, address updatedVRFCoordinator) = createSubscription.run();
            subId = updatedSubId;
            vrfCoordinator = updatedVRFCoordinator;
            console.log("New subId created: ", subId, "VRF coordinator address: ", vrfCoordinator);
        }

        fundSubscription(vrfCoordinator, subId, link, deployerPrivateKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerPrivateKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using VRF coordinator: ", vrfCoordinator);
        console.log("On chain ID: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerPrivateKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log("Address: ", msg.sender, "with LINK balance: ", LinkToken(link).balanceOf(msg.sender));
            console.log("Address: ", address(this), "with LINK balance: ", LinkToken(link).balanceOf(address(this)));

            vm.startBroadcast(deployerPrivateKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
}