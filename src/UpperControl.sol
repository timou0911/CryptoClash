// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Game.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Upper Control Contract to handle each game instances
 * @author Tim Ou
 * @notice Users can create a game from this contract
 * @dev Implements Chainlink VRF. Handle game state and provide helper functions to game insatances
 */

contract UpperControl is VRFConsumerBaseV2 {
    /** Errors */
    error CallerNotGameContract();
    error GameNotInProgress(GameState state);

    /** Type Declarations */
    enum GameState {NotGameContract, WaitingForPlayers, InProgress, Finished}

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant PARTICIPANT_NUMBER = 5;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint32 private s_numWords = 1;
    mapping(uint256 => address) private s_requestIdToGameAddress;
    mapping(address => GameState) public s_gamesState;

    /** Events */
    event GameCreated(address gameAddress);
    event RequestSent(uint256 requestId, uint32 s_numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event StateChange(GameState prev, GameState curr);
    event GameFinished(address gameAddr);

    /** Modifiers */
    modifier onlyGameContract() {
        if (s_gamesState[msg.sender] == GameState.NotGameContract) {
            revert CallerNotGameContract();
        }
        _;
    }

    constructor(uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    /**
     * @notice Create a round of game and become the first participant
     * @dev Separate round creation and instance creation. Set game state to waiting participants
     */
    function createGame() public payable {
        require(msg.value == PARTICIPANT_FEE, "Incorrect fee amount");

        Game game = new Game{value: PARTICIPANT_FEE}(msg.sender);
        require(address(game) != address(0), "Game instance creation failed.");

        s_gamesState[address(game)] = GameState.WaitingForPlayers;

        emit GameCreated(address(game));
    }

    /**
     * @notice Chnage game state to finished
     * @dev This function is called by game instances when game is over
     */
    function endGame() public onlyGameContract() {
        if (s_gamesState[msg.sender] != GameState.InProgress) {
            revert GameNotInProgress(s_gamesState[msg.sender]);
        }

        s_gamesState[msg.sender] = GameState.Finished;
        
        emit GameFinished(msg.sender);
    }

    /**
     * @notice Called by game instances to request random words
     * @dev Should first check caller is game instance or not
     */
    function requestRandomWords() external onlyGameContract() returns (uint256 requestId) {
        requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            s_numWords
        );

        s_requestIdToGameAddress[requestId] = msg.sender;

        emit RequestSent(requestId, s_numWords);
    }
    
    /**
     * @notice Called by Cahinlink node, than sends random words to game instances
     * @dev Game contract should implement a function to receive random words
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        address gameAddress = s_requestIdToGameAddress[_requestId];
        require(gameAddress != address(0), "Invalid request ID");
        
        bool received = Game(gameAddress).decideRandomEvent(_randomWords[0]);
        require(received, "random words sent failed.");

        emit RequestFulfilled(_requestId, _randomWords);
    }

    /** Setter Functions */
    function setGameState(uint8 gameState) public onlyGameContract() {
        GameState prevState = s_gamesState[msg.sender];
        s_gamesState[msg.sender] = GameState(gameState);
        emit StateChange(prevState, GameState(gameState));
    }

    /** Getter Functions */
    function getGameState() public view returns (GameState) {
        return s_gamesState[msg.sender];
    }
}