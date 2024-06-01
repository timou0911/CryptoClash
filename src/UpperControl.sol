// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Game.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";


/**
 * @title Upper Control Contract to handle each game instances
 * @author Tim Ou
 * @notice Users can create a game from this contract
 * @dev Implements Chainlink VRF. Handle game state and provide helper functions to game insatances
 */

// https://sepolia.etherscan.io/address/0xdb4c9fe64580e173edd5e00725276502d3816f29

contract UpperControl is VRFConsumerBaseV2, FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    /** Errors */
    error CallerNotGameContract();
    error GameNotInProgress(GameState state);
    error UpkeepNotNeeded();

    /** Type Declarations */
    /**
     * @dev The first state(default value), NotGameContract, is used to prevent users from creating game instances
     * @dev bypassing Upper Control, since functions in Game.sol require certain state, and state changing
     * @dev is managed by Upper Control.
     */
    enum GameState {
        NotGameContract,
        WaitingForPlayers,
        InProgress,
        Finished
    }

    /** State Variables */
    uint32 private constant NUMWORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant PARTICIPANT_NUMBER = 3;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;

    VRFCoordinatorV2Interface private immutable i_VRF_coordinator;
    bytes32 private immutable i_VRF_gasLane;
    uint64 private immutable i_VRF_subscriptionId;
    uint32 private immutable i_VRF_callbackGasLimit;

    address private immutable i_AI_router;
    uint64 private immutable i_AI_subscriptionId;
    uint32 private immutable i_AI_callbackGasLimit;

    uint256 public immutable i_interval;

    mapping(uint256 => address) public s_VRF_requestIdToGameAddress;
    mapping(bytes32 => address) public s_AI_requestIdToGameAddress;
    mapping(address => uint256) public s_Automation_startTime;
    mapping(address => GameState) public s_gamesState;
    address[] s_gameInWaitingForPlayersChoice;

    bytes32 public donId;

    /** Events */
    event GameCreated(address indexed gameAddress);
    event StateChange(GameState indexed prev, GameState indexed curr);
    event TimerStarted(address indexed gameAddress, uint256 indexed startTime);
    event GameFinished(address indexed gameAddr);
    event VRF_RequestSent(uint256 indexed requestId, uint32 indexed s_numWords);
    event VRF_RequestFulfilled(uint256 indexed requestId, uint256[] indexed randomWords);
    event AI_RequestSent(bytes32 requestId);
    event AI_RequestFulfilled(bytes32 requestId, bytes reponse, bytes err);

    /** Modifiers */
    modifier onlyGameContract() {
        if (s_gamesState[msg.sender] == GameState.NotGameContract) {
            revert CallerNotGameContract();
        }
        _;
    }

    constructor(
        uint64 VRF_subscriptionId, // 11797, https://vrf.chain.link/sepolia/11797
        bytes32 gasLane, // 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
        uint32 VRF_callbackGasLimit, // 500000
        address vrfCoordinator, // 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        uint64 AI_subscriptionId, // 2858, https://functions.chain.link/sepolia/2858
        uint32 AI_callbackGasLimit, // 300000
        bytes32 donID, // 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000
        address router, // 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0
        uint256 interval // 30 seconds
    ) VRFConsumerBaseV2(vrfCoordinator) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        i_VRF_coordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_VRF_gasLane = gasLane;
        i_VRF_subscriptionId = VRF_subscriptionId;
        i_VRF_callbackGasLimit = VRF_callbackGasLimit;
        i_AI_subscriptionId = AI_subscriptionId;
        i_AI_callbackGasLimit = AI_callbackGasLimit;
        donId = donID;
        i_AI_router = router;
        i_interval = interval;
    }

    /**
     * @notice Create a round of game and become the first participant
     * @dev Separate round creation and instance creation. Set game state to waiting participants
     */
    function createGame() public payable returns (address) {
        require(msg.value == PARTICIPANT_FEE, "Incorrect fee amount");

        Game game = new Game{value: PARTICIPANT_FEE}(msg.sender);
        require(address(game) != address(0), "Game instance creation failed.");

        s_gamesState[address(game)] = GameState.WaitingForPlayers;

        emit GameCreated(address(game));

        return address(game);
    }

    function checkIfTimerOut() public {
        uint256 length = s_gameInWaitingForPlayersChoice.length;
        if (length == 0) return;

        uint256 lastIndex = length - 1;

        for (uint256 i = length-1; i > length;) {
            address game = s_gameInWaitingForPlayersChoice[i];
            if (block.timestamp - s_Automation_startTime[game] > i_interval) {
                if (i == lastIndex) {
                    s_gameInWaitingForPlayersChoice.pop();
                } else {
                    s_gameInWaitingForPlayersChoice[i] = s_gameInWaitingForPlayersChoice[lastIndex];
                    s_gameInWaitingForPlayersChoice.pop();               
                }
                --lastIndex;
                Game(game).getPlayerResponse();
            }
            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Called by game instances to request random words
     * @dev Should first check caller is game instance or not
     */
    function requestRandomWords() external onlyGameContract() returns (uint256 requestId) {
        requestId = i_VRF_coordinator.requestRandomWords(
            i_VRF_gasLane,
            i_VRF_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_VRF_callbackGasLimit,
            NUMWORDS
        );

        s_VRF_requestIdToGameAddress[requestId] = msg.sender;

        emit VRF_RequestSent(requestId, NUMWORDS);
    }

    /**
     * @notice Called by Cahinlink node, than sends random words to game instances
     * @dev Game contract should implement a function to receive random words
     */
    function fulfillRandomWords( uint256 _requestId, uint256[] memory _randomWords) internal override {
        address gameAddress = s_VRF_requestIdToGameAddress[_requestId];
        require(gameAddress != address(0), "Invalid request ID");

        bool received = Game(gameAddress).decideRandomEvent(_randomWords[0]);
        
        emit VRF_RequestFulfilled(_requestId, _randomWords);
    }

    function requestAI(string calldata source,
        FunctionsRequest.Location secretsLocation,
        bytes calldata encryptedSecretsReference,
        string[] calldata args,
        bytes[] calldata bytesArgs,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) public onlyGameContract() returns (bytes32 requestId) {        FunctionsRequest.Request memory req; // Struct API reference: https://docs.chain.link/chainlink-functions/api-reference/functions-request
        req.initializeRequest(FunctionsRequest.Location.Inline, FunctionsRequest.CodeLanguage.JavaScript, source);
        req.secretsLocation = secretsLocation;
        req.encryptedSecretsReference = encryptedSecretsReference;
        if (args.length > 0) {
          req.setArgs(args);
        } 
        if (bytesArgs.length > 0) {
            req.setBytesArgs(bytesArgs);
        }
        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, callbackGasLimit, donId);
        s_AI_requestIdToGameAddress[requestId] = msg.sender;

        emit AI_RequestSent(requestId);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        address game = s_AI_requestIdToGameAddress[requestId];
        // Game(game)
        emit AI_RequestFulfilled(requestId, response, err);
    }

    /** Setter Functions */
    function setGameState(uint8 _gameState) public onlyGameContract() {
        GameState prevState = s_gamesState[msg.sender];
        s_gamesState[msg.sender] = GameState(_gameState);
        emit StateChange(prevState, GameState(_gameState));
    }

    function setTimer(uint256 _startTime) public onlyGameContract() {
        s_Automation_startTime[msg.sender] = _startTime;
        s_gameInWaitingForPlayersChoice.push(msg.sender);
        emit TimerStarted(msg.sender, _startTime);
    }

    function setDonId(bytes32 newDonId) external onlyOwner() {
        donId = newDonId;
    }

    /** Getter Functions */
    function getGameState() public view returns (GameState) {
        return s_gamesState[msg.sender];
    }
}
