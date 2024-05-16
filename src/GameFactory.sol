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


/// TODO: separate game invocation and game creation. Invocation for new gameIndex, creation for 5 people joined
contract GameFactory is VRFConsumerBaseV2 {
    /** Errors */
    error GameIndexNotCreated(uint256 gameCount, uint256 gameIndex);
    error ParticipantFull(uint256 gameIndex);
    error GameInProgressOrIsFinished(uint256 gameIndex, GameStatus status);
    error GameNotStartedOrIsFinished(uint256 gameIndex, GameStatus status);
    error CallerNotGameContract(uint256 gameIndex, address gameAddress, address caller);

    /** Type Declarations */
    enum GameStatus {WaitingForPlayers, InProgress, Completed}

    struct GameInfo {
        address gameAddress;
        address[] participants;
        GameStatus status;
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 private numWords = 1;

    uint256 private gameCount;
    mapping(uint256 => address) private requestIdToGameAddress;
    mapping(uint256 => GameInfo) public games;

    /** Events */
    event GameCreated(address gameInstance, uint256 gameCount);
    event GameJoined(address player, uint256 gameIndex);
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

    function createGame() public {
        Game game = new Game(); // CREATE? CREATE2?

        GameInfo memory gameInfo = GameInfo({
            gameAddress: address(game),
            participants: new address[](1),
            status: GameStatus.WaitingForPlayers
        });

        gameInfo.participants[0] = msg.sender;
        games[gameCount] = gameInfo;
        gameCount++;

        emit GameCreated(address(game), gameCount);
    }

    function enterGame(uint256 _gameIndex) public validateGameIndex(_gameIndex) {
        if (games[_gameIndex].participants.length >= 5) {
            revert ParticipantFull(_gameIndex);
        }
        if (games[_gameIndex].status != GameStatus.WaitingForPlayers) {
            revert GameInProgressOrIsFinished(_gameIndex, games[_gameIndex].status);
        }

        games[_gameIndex].participants.push(msg.sender);

        emit GameJoined(msg.sender, _gameIndex);

        if (games[_gameIndex].participants.length == 5) {
            games[_gameIndex].status = GameStatus.InProgress;
        }
    }

    function endGame(uint256 _gameIndex) public validateGameIndex(_gameIndex) {
        if (msg.sender != games[_gameIndex].gameAddress) {
            revert CallerNotGameContract(_gameIndex, games[_gameIndex].gameAddress, msg.sender);
        }
        if (games[_gameIndex].status != GameStatus.InProgress) {
            revert GameNotStartedOrIsFinished(_gameIndex, games[_gameIndex].status);
        }

        games[_gameIndex].status = GameStatus.Completed;
        
        emit GameFinished(_gameIndex);
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

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        address gameAddress = requestIdToGameAddress[_requestId];
        require(gameAddress != address(0), "Invalid request ID");
        Game(gameAddress).decideRandomEvent(_randomWords[0]);
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