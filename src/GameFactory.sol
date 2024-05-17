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


// TODO: Solve potential front-running issue in function enterGame
contract GameFactory is VRFConsumerBaseV2 {
    /** Errors */
    error GameIndexNotCreated(uint256 gameCount, uint256 gameIndex);
    error ParticipantFull(uint256 gameIndex);
    error CallerNotGameContract(uint256 gameIndex, address gameAddress, address caller);
    error GameInProgressOrIsFinished(uint256 gameIndex, GameStatus status);
    error GameNotStartedOrIsFinished(uint256 gameIndex, GameStatus status);

    /** Type Declarations */
    enum GameStatus {WaitingForPlayers, InProgress, Finished}

    struct GameInfo {
        uint256 gameIndex;
        address gameAddress;
        address[] participants;
        GameStatus status;
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant PARTICIPANT_NUMBER = 5;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 private numWords = 1;

    uint256 private gameCount;
    mapping(uint256 => address) private requestIdToGameAddress;
    mapping(uint256 => GameInfo) public games;

    /** Events */
    event GameCreated(uint256 gameCount);
    event GameJoined(uint256 gameIndex, address player);
    event GameInvoked(uint256 gameIndex, address gameInstance);
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event GameFinished(uint256 gameIndex);

    /** Modifiers */
    modifier validateGameIndex(uint256 _gameIndex) {
        if (_gameIndex >= gameCount) {
            revert GameIndexNotCreated(gameCount, _gameIndex);
        }
        _;
    }

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

    /**
     * @notice Create a round of game and become the first participant
     * @dev Separate round creation and instance creation. Set game status to waiting participants
     */
    function createGame() public {
        GameInfo memory gameInfo = GameInfo({
            gameIndex: gameCount,
            gameAddress: address(0), // Set to zero address initially
            participants: new address[](1),
            status: GameStatus.WaitingForPlayers
        });

        gameInfo.participants[0] = msg.sender;
        games[gameCount] = gameInfo;
        gameCount++;

        emit GameCreated(gameCount);
    }

    /**
     * @notice Join an existing round
     * @dev When particpant number is full, than create a new game instance
     * @param _gameIndex Game index used to check participant number, game status, and perform adding participants
     */
    function enterGame(uint256 _gameIndex) public validateGameIndex(_gameIndex) {
        if (games[_gameIndex].participants.length >= PARTICIPANT_NUMBER) {
            revert ParticipantFull(_gameIndex);
        }
        if (games[_gameIndex].status != GameStatus.WaitingForPlayers) {
            revert GameInProgressOrIsFinished(_gameIndex, games[_gameIndex].status);
        }

        games[_gameIndex].participants.push(msg.sender);

        emit GameJoined(_gameIndex, msg.sender);

        if (games[_gameIndex].participants.length == PARTICIPANT_NUMBER) {
            invokeGame(_gameIndex);
        }
    }

    /**
     * @notice Create a new game instance
     * @dev Invoked when participant number is full
     * @param _gameIndex Game index used to set game instance address and status to in progress
     */
    function invokeGame(uint256 _gameIndex) private validateGameIndex(_gameIndex) {
        Game game = new Game();
        require(address(game) != address(0), "game instance creation failed.");
        games[_gameIndex].gameAddress = address(game);
        games[_gameIndex].status = GameStatus.InProgress;

        emit GameInvoked(_gameIndex, address(game));
    }

    /**
     * @notice Chnage game status to finished
     * @dev This function is called by game instances when game is over
     * @param _gameIndex Game index used to check if caller is game instance and set game status
     */
    function endGame(uint256 _gameIndex) public validateGameIndex(_gameIndex) {
        if (msg.sender != games[_gameIndex].gameAddress) {
            revert CallerNotGameContract(_gameIndex, games[_gameIndex].gameAddress, msg.sender);
        }
        if (games[_gameIndex].status != GameStatus.InProgress) {
            revert GameNotStartedOrIsFinished(_gameIndex, games[_gameIndex].status);
        }

        games[_gameIndex].status = GameStatus.Finished;
        
        emit GameFinished(_gameIndex);
    }

    /**
     * @notice Called by game instances to request random words
     * @dev Should first check caller is game instance or not
     * @param _gameIndex Game index used to check if caller is game instance
     */
    function requestRandomWords(uint256 _gameIndex) external returns (uint256 requestId) {
        if (msg.sender != games[_gameIndex].gameAddress) {
            revert CallerNotGameContract(_gameIndex, games[_gameIndex].gameAddress, msg.sender);
        }

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

    
    /**
     * @notice Called by Cahinlink node, than sends random words to game instances
     * @dev Game contract should implement a function to receive random words
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        address gameAddress = requestIdToGameAddress[_requestId];
        require(gameAddress != address(0), "Invalid request ID");
        
        bool received = Game(gameAddress).decideRandomEvent(_randomWords[0]);
        require(received, "random words sent failed.");

        emit RequestFulfilled(_requestId, _randomWords);
    }


    /** Getter Functions */
    function getGameParticipants(uint256 _gameIndex) public view validateGameIndex(_gameIndex) returns (address[] memory) {
        return games[_gameIndex].participants;
    }

    function getGameAddress(uint256 _gameIndex) public view validateGameIndex(_gameIndex) returns (address) {
        return games[_gameIndex].gameAddress;
    }

    function isPlayerInGame(uint256 _gameIndex, address _player) public view validateGameIndex(_gameIndex)returns (bool) {
        address[] memory participants = games[_gameIndex].participants;

        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == _player) {
                return true;
            }
        }

        return false;
    }

    function getGameStatus(uint256 _gameIndex) public view validateGameIndex(_gameIndex) returns (GameStatus) {
        return games[_gameIndex].status;
    }
}