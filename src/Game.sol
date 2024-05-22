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

    error AI_responseFail();
    /** Type Declarations */
    struct AI_response{
        //useful information that will response by AI (this is what claude AI told me)
        bool success;
        string[] news;
        string[] option;
        string[] messenge;
        string confidence_score;
    }

    struct Player_response{
        bool playerDecided;
        uint8 playerDecision;
    }

    struct Player_statement{
        string currencyName;
        uint64 money;
        uint64[] investment;//5 index just like index of s_players, the array represent a player investment in each cryptocurrency
        string topic;
    }
    struct Event_holder{
        string[] newsOfPlayerDecision;
        string[] newsForEachPlayer;
        string[] msgForEachPlayer;
        string[] emailForEachPlayer;
    }
    
    /** State Variables */
    uint8 private constant PARTICIPANT_NUMBER = 5;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;
    IUpperControl private immutable i_upperControl;
    address[] private s_players;

    uint8 private constant MAX_ROUND = 30;
        //requestion word for requesting ai at first round to get first event and decide which topic player work on.
    string private constant ROUNDSTART_REQUESTION ="we just wrote a Game featuring using you to provide game events and decide the outcome, so you should be neutral and make the game versertil for them, now there are five players playing a role in cryptocurrency provider, just random pick a topic (AI, GameFi, defi, etc.) they should work on for them, and now create a random opportunity event as a news for them that will effect the market for each of them, for instance a , for gamefi : there is a off-chain game company want to go on-chain and for the gamefi crypto . some event like this just provide in one line and  a line of player's assistant ask wether to cooperate with them, two line are seperate with / ";
    AI_response private ai_response;
    Player_response[] private player_response;
    Event_holder private event_holder;
    //Player_statement[] private
    uint8 gameRound = 0;
    uint256 bidRound = 0;
    uint8 specialEventFrequency = 5;
    /** Events */
    event GameJoined(address player);
    event GameStart();

    event SendNews(string[] news);//each player hold a index
    event SendEmail(string[] events);
    event SendMsg(string[] suggention);
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
    modifier onlyResponseSuccess(){
        if(ai_response.success = false){
            revert AI_responseFail();
        }
        _;
    }
    constructor(address gameCreator) payable onlyUpperControl() {
        i_upperControl = IUpperControl(msg.sender);

        s_players[playerNum] = gameCreator;
        ++playerNum;
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

        s_players[playerNum] = msg.sender;
        playerNum++;

        emit GameJoined(msg.sender);

        if (playerNum == PARTICIPANT_NUMBER) {
            i_upperControl.setGameState(2);
            emit GameStart();
        }
    }
    function gameStarting() onlyGameStateInProgress() private {
        if(gameRound == 0){
            requestAI();
            gameRound++;
        }
        gameFlow();
    }
    function gameFlow() onlyGameStateInProgress() onlyResponseSuccess() private {
        for(gameRound; gameRound <= MAX_ROUND ; gameRound++){
            setEventHolder();
            sendNews();
            sendEmail();
            sendMsg();
            getPlayerResponse();
            requestAI();
        }
    }
    function sendNews() onlyGameStateInProgress() private {
        emit SendEmail(event_holder.newsForEachPlayer);
    }
    function sendMsg() onlyGameStateInProgress() private {
        emit SendMsg(event_holder.msgForEachPlayer);
    }
    function sendEmail() onlyGameStateInProgress() private {
        emit SendEmail(event_holder.emailForEachPlayer);
    }
    function setEventHolder() onlyGameStateInProgress() private {
        for(uint i =0 ; i < PARTICIPANT_NUMBER ; i++){
            for(uint j = 0 ;j < PARTICIPANT_NUMBER ; j++)
            event_holder.newsForEachPlayer[i] = string.concat(event_holder.newsForEachPlayer[i],event_holder.newsOfPlayerDecision[j]);
        }
        event_holder.newsForEachPlayer = ai_response.news;
        event_holder.msgForEachPlayer = ai_response.messenge;
        event_holder.emailForEachPlayer = ai_response.option;
    }
    function getPlayerResponse() onlyGameStateInProgress() private{
        //get player response from front-end;
        // player_response  = array of player response
        for(uint8 i =0;i < PARTICIPANT_NUMBER; ++i){
            if(player_response[i].playerDecided==false){
                player_response[i].playerDecision = 1;
            }
        }
    }
    
    function requestAI() onlyGameStateInProgress() private  {
        if(gameRound == 0){
            string memory requestWord = ROUNDSTART_REQUESTION;
            // send request with requestWord the response with be : 
            // event/invite for each player , event shows on news , invite shows on Msg
            AI_response storage ai_response ;//
        }else{
            
        }
        //calling js script to send request to AI, and request that AI should provide options seperate by / ; 
       // AI_response storage ai_response = ...    
       //solidity cant split string unless using other library 
       //should we split it in javascript or in the contract?
    }
   
    function decideRandomEvent(
        uint256 randomWord
    ) public onlyUpperControl() returns (bool received) {
        // take mod of randomWord to decide event
        bidRound = randomWord%15 + 16; 
        return received;
    }

    function requestRandomWord() onlyGameStateInProgress() private {
        i_upperControl.requestRandomWord();
    }

    /** Getter Functions */
    function getState() public returns (uint8) {
        return uint8(i_upperControl.getGameState());
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
