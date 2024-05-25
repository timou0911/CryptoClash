// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { UpperControl } from "../src/UpperControl.sol";
import { Game } from "../src/Game.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";
import { DeployUpperControl } from "../script/DeployUpperControl.s.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { CreateSubscription } from "../script/Interactions.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { Test, console } from "forge-std/Test.sol";

contract UpperControlTest is Test {
    UpperControl public upperControl;
    HelperConfig public helperConfig;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant PARTICIPANT_NUMBER = 5;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;

    uint64 subscriptionId;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    uint256 deployerKey;

    address public PLAYER1 = makeAddr("PLAYER1");
    address public PLAYER2 = makeAddr("PLAYER2");
    address public PLAYER3 = makeAddr("PLAYER3");
    address public PLAYER4 = makeAddr("PLAYER4");
    address public PLAYER5 = makeAddr("PLAYER5");
    uint256 public constant STARTING_BALANCE = 1 ether;
    address game;
    
    /** Modifiers */
    modifier createGame() {
        vm.prank(PLAYER1);
        game = upperControl.createGame{value: PARTICIPANT_FEE}();
        _;
    }

    modifier makeFourOtherPlayersJoin() {
        vm.prank(PLAYER2);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        vm.prank(PLAYER3);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        vm.prank(PLAYER4);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        vm.prank(PLAYER5);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        _;
    }

    function setUp() external {
        DeployUpperControl deployUpperControl = new DeployUpperControl();
        (upperControl, helperConfig) = deployUpperControl.run();
        console.log("Upper Control Address: ", address(upperControl));

        vm.deal(PLAYER1, STARTING_BALANCE);
        vm.deal(PLAYER2, STARTING_BALANCE);
        vm.deal(PLAYER3, STARTING_BALANCE);
        vm.deal(PLAYER4, STARTING_BALANCE);
        vm.deal(PLAYER5, STARTING_BALANCE);

        (
            subscriptionId,
            gasLane,
            callbackGasLimit,
            vrfCoordinator,
            ,
            deployerKey
            ,
        ) = helperConfig.activeNetworkConfig();
    }

    /*            */
    /* createGame */
    /*            */
    function testGameCanBeCreated() public createGame() {
        assert(game != address(0));
    }

    function testGameInWaitingPlayersStateAfterCreated() public createGame() {
        assert(Game(game).getState() == uint8(UpperControl.GameState.WaitingForPlayers));
    }

    function testGameHasBalanceAfterCreated() public createGame() {
        assert(game.balance == PARTICIPANT_FEE);
    }

    function testGameCreationFailedWithParicipantFeeIncorrect() public {
        vm.prank(PLAYER1);

        vm.expectRevert();
        game = upperControl.createGame{value: 0.005 ether}();
    }

    /*           */
    /* enterGame */
    /*           */
    function testPlayerCanJoin() public createGame() {
        vm.prank(PLAYER2);
        Game(game).enterGame{value: PARTICIPANT_FEE}();

        assert(PLAYER2 == Game(game).getParticipant(1));
    }

    function testPlayerCantJoinAfterParticipantNumberIsFull() public createGame() makeFourOtherPlayersJoin() {
        address PLAYER6 = makeAddr("PLAYER6");
        vm.deal(PLAYER6, STARTING_BALANCE);
        vm.prank(PLAYER6);

        vm.expectRevert();
        Game(game).enterGame{value: PARTICIPANT_FEE}();
    }

    function testGameJoinFailedWithParicipantFeeIncorrect() public createGame() {
        vm.prank(PLAYER2);

        vm.expectRevert();
        Game(game).enterGame{value: 0.005 ether}();
    }

    function testGameJoinFailedWhenDuplicatedPlayerJoin() public createGame() {
        vm.prank(PLAYER2);
        Game(game).enterGame{value: PARTICIPANT_FEE}();

        vm.prank(PLAYER2);
        vm.expectRevert();
        Game(game).enterGame{value: PARTICIPANT_FEE}();
    }

    function testStateChangeToInProgressWhenPlayerNumberIsFull() public createGame() makeFourOtherPlayersJoin() {
        assert(Game(game).getState() == uint8(UpperControl.GameState.InProgress));
    }


    /*          */
    /* endeGame */
    /*          */
    function testGameFinishedSuccessfully() public createGame() makeFourOtherPlayersJoin() {
        vm.prank(game);
        upperControl.endGame();

        assert(Game(game).getState() == uint8(UpperControl.GameState.Finished));
    }

    function testGameCantFinishIfNotContractCalls() public createGame() makeFourOtherPlayersJoin() {
        vm.prank(PLAYER1);
        vm.expectRevert();

        upperControl.endGame();
    }

    function testGameCantFinishIfStateIsNotInProgress() public createGame() {
        vm.prank(PLAYER2);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        vm.prank(PLAYER3);
        Game(game).enterGame{value: PARTICIPANT_FEE}();
        vm.prank(PLAYER4);
        Game(game).enterGame{value: PARTICIPANT_FEE}();

        vm.prank(game);
        vm.expectRevert();

        upperControl.endGame();
    }

    /*                    */
    /* requestRandomWords */
    /*                    */
    function testRequestRandomWordsWorks() public createGame() makeFourOtherPlayersJoin() {
        vm.prank(game);
        uint256 requestId = upperControl.requestRandomWords();

        assert(requestId > 0);
    }

    /*                    */
    /* fulfillRandomWords */
    /*                    */
    function testFulfillRandomWordsWorks() public createGame() makeFourOtherPlayersJoin() {
        vm.prank(game);
        uint256 requestId = upperControl.requestRandomWords();
        console.log("Request ID 1: ", requestId);

        
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(upperControl));
        
        // Vm.Log[] memory entries = vm.getRecordedLogs();
        // requestId = uint256(entries[1].topics[0]);
        // console.log("Request ID 2: ", requestId);
        //console.log("Random Words: ", entries[1].topics[1]);
    }

    function testFulfillRandomWordsFailsWithNonexistentRequestId() public createGame() makeFourOtherPlayersJoin() {
        vm.prank(game);
        uint256 requestId = upperControl.requestRandomWords();
        console.log("Request ID 1: ", requestId);

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(255, address(upperControl));
    }
}
