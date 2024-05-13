// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Game.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Contract Factory to Create Game Instances
 * @author Tim Ou
 * @notice Users can create a game from this contract
 * @dev Implements Chainlink VRF2 and Automation
 */

contract GameFactory is VRFConsumerBaseV2 {
    /** Errors */

    /** Type Declarations */

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 numWords = 2;

    uint256 private s_lastTimeStamp;

    /** Events */
    event GameCreated();
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    /** Modifiers */
    modifier onlyOwner() {
        require(msg.sender == address(this));
        _;
    }

    constructor(uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function createGame() public {
        Game game = new Game();
    }

    function enterGame() public {

    }

    function requestRandomWords() external onlyOwner returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        
    }

    function checkUpkeep(bytes calldata /*checkData*/) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {

    }

    function performUpkeep(bytes calldata /*performData*/) external {

    }

    /** Getter Functions */
}
