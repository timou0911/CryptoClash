// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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
    error ParticipantFull();
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
    event GameStart();

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
        for (uint8 i = 0; i < PARTICIPANT_NUMBER; ++i) {
            if (s_players[i] == msg.sender) {
                revert ParicipantDuplicated(msg.sender);
            }
        }
        _;
    }

    constructor(address gameCreator) payable onlyUpperControl() {
        i_upperControl = IUpperControl(msg.sender);

        s_players.push(gameCreator);
    }

    /**
     * @notice Join an existing round
     * @dev When particpant number is full, than create a new game instance
     */
    function enterGame() public payable noDuplicatedPlayer() {
        if (msg.value != PARTICIPANT_FEE) {
            revert WrongFeeAmount();
        }
        if (s_players.length >= PARTICIPANT_NUMBER) {
            revert ParticipantFull();
        }
        if (getState() != 0) {
            revert GameNotInWaitingState();
        }

        s_players.push(msg.sender);

        emit GameJoined(msg.sender);

        if (s_players.length == PARTICIPANT_NUMBER) {
            i_upperControl.setGameState(2);
            emit GameStart();
        }
    }

    function decideRandomEvent(
        uint256 randomWord
    ) public onlyUpperControl() returns (bool received) {
        // take mod of randomWord to decide event
        return received;
    }

    function requestRandomWord() onlyGameStateInProgress() private {
        i_upperControl.requestRandomWord();
    }

    /** Getter Functions */
    function getState() public returns (uint8) {
        return uint8(i_upperControl.getGameState());
    }
}
