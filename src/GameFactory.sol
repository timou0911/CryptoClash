// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Game.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Contract Factory to Create Game Instances
 * @author Tim Ou
 * @notice Users can create a game from this contract
 * @dev Implements Chainlink VRF and Automation
 */

contract GameFactory is VRFConsumerBaseV2 {
    /** Errors */

    /** Type Declarations */

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 private numWords = 1;

    mapping(uint256 => address) private requestIdToGameAddress;

    /** Events */
    event GameCreated(address gameInstance);
    event GameJoined(address player);
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    /** Modifiers */


    constructor(address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function createGame() public {
        Game game = new Game(); // CREATE? CREATE2?
        emit GameCreated(address(game));
    }

    function enterGame() public {
        emit GameJoined(msg.sender);
    }

    function requestRandomWords() external returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            numWords
        );

        requestIdToGameAddress[requestId] = msg.sender;

        emit RequestSent(requestId, numWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address gameAddress = requestIdToGameAddress[requestId];
        require(gameAddress != address(0), "Invalid request ID");
        Game(gameAddress).decideRandomEvent(randomWords[0]);
    }


    /** Getter Functions */
}
