// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUpperControl {
    function requestRandomWord() external returns (uint256);
    function endGame() external;
    function setGameState(uint8 _gameState) external;
    function getGameState() external returns (uint8);
}

/**
 * @title Game logic
 * @author Tim Ou
 * @notice XXXXX
 * @dev XXXXX
 */

// TODO: Develop a way to save upper control's address before consturctor called
// TODO: Who can call function triggerRandomEvent (Automation?)
contract Game {
    /** Errors */
    error WrongFeeAmount();
    error ParicipantDuplicated(address player);
    error GameNotInWaitingState();
    error GameNotInProgressState();
    error CallerNotUpperControl(address caller, address upperControl);

    /** Type Declarations */

    /** State Variables */
    uint8 private constant PARTICIPANT_NUMBER = 5;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;
    IUpperControl private i_upperControl = IUpperControl(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    address private upperControlAddr;
    address[PARTICIPANT_NUMBER] public s_players;
    uint8 private playerNum = 0;

    /** Events */
    event GameJoined(address player);

    /** Modifiers */
    modifier onlyUpperControl() {
        if (msg.sender != address(i_upperControl)) {
            revert CallerNotUpperControl(msg.sender, address(i_upperControl));
        }
        _;
    }

    modifier onlyGameStateInProgress() {
        if (getState() != 2) {
            revert GameNotInProgressState();
        }
        _;
    }

    modifier noDuplicatedPlayer() {
        for (uint8 i = 0; i < playerNum; ++i) {
            if (s_players[i] == msg.sender) {
                revert ParicipantDuplicated(msg.sender);
            }
        }
        _;
    }

    constructor(address gameCreator) payable onlyUpperControl() {
        i_upperControl = IUpperControl(msg.sender);

        s_players[playerNum] = gameCreator;
        ++playerNum;
    }

    /**
     * @notice Pay fee and join an existing round
     * @dev When particpant number is full, change state to InProgress
     */
    function enterGame() public payable noDuplicatedPlayer() {
        if (getState() != 1) {
            revert GameNotInWaitingState();
        }
        if (msg.value != PARTICIPANT_FEE) {
            revert WrongFeeAmount();
        }

        s_players[playerNum] = msg.sender;
        playerNum++;

        emit GameJoined(msg.sender);

        if (playerNum == PARTICIPANT_NUMBER) {
            i_upperControl.setGameState(2);
        }
    }

    function triggerRandomEvent() public onlyGameStateInProgress() {
        i_upperControl.requestRandomWord();
    }

    function decideRandomEvent(uint256 randomWord) public onlyUpperControl() onlyGameStateInProgress() returns (bool received) {
        // take mod of randomWord to decide event
        received = true;
    }

    /** Getter Functions */
    function getState() public returns (uint8) {
        return uint8(i_upperControl.getGameState());
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
