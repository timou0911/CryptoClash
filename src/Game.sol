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
// TODO: Change array players from dynamic to static
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
    IUpperControl private immutable i_upperControl;
    address[] private s_players;

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
        bidRound = randomWord%15 + 16; 
        return received;
    }

    /** Getter Functions */
    function getState() public returns (uint8) {
        return uint8(i_upperControl.getGameState());
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
