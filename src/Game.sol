// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IUpperControl {
    function requestRandomWord() external returns (uint256);
    function endGame() external;
    function setGameState(uint8 _gameState) external;
    function setTime(uint256 _satrtTime) external;
    function getGameState() external returns (uint8);
}

/**
 * @title Game logic
 * @author Tim Ou
 * @notice XXXXX
 * @dev XXXXX
 */

contract Game {
    /** Errors */
    error WrongFeeAmount();
    error ParticipantFull();
    error ParicipantDuplicated(address player);
    error GameNotInWaitingState();
    error GameNotInProgressState();
    error CallerNotGamePlayer(address caller);
    error CallerNotUpperControl(address caller, address upperControl);
    error AI_responseFail();

    /** Type Declarations */
    struct AI_response {
        //useful information that will response by AI (this is what claude AI told me)
        string[] player_topic;
        string[] news;
        string[] option;
        string[] messenge;
        string confidence_score;
    }

    struct Player_response {
        uint8 playerDecision;
        uint8[] playerInvestment;
    }

    struct Player_statement {
        string currencyName;
        uint64 money;
        uint64[3] investment;//5 index just like index of s_players, the array represent a player investment in each cryptocurrency
        string topic;
    }
    struct Event_holder {
        string[] newsOfPlayerDecision;
        string[] newsForEachPlayer;
        string[] msgForEachPlayer;
        string[] emailForEachPlayer;
    }
    
    /** State Variables */
    uint8 private constant PARTICIPANT_NUMBER = 5;
    uint256 private constant PARTICIPANT_FEE = 0.01 ether;
    IUpperControl private immutable i_upperControl;
    address[PARTICIPANT_NUMBER] public s_players;
    uint8 private playerNum = 0;
    address[PARTICIPANT_NUMBER] public player_point;

    uint8 private constant MAX_ROUND = 30;
    //requestion word for requesting ai at first round to get first event and decide which topic player work on.
    string private constant ROUNDSTART_REQUESTION ="we just wrote a Game featuring using you to provide game events and decide the outcome, so you should be neutral and make the game versertil for them, now there are five players playing a role in cryptocurrency provider, just random pick a topic (AI, GameFi, defi, etc.) they should work on for them, and now create a random opportunity event as a news for them that will effect the market for each of them, for instance a , for gamefi : there is a off-chain game company want to go on-chain and for the gamefi crypto . some event like this just provide in one line and  a line of player's assistant ask wether to cooperate with them, two line are seperate with / ";
    AI_response private ai_response;
    Player_response[PARTICIPANT_NUMBER] private player_response;
    Event_holder private event_holder;
    Player_statement[PARTICIPANT_NUMBER] private player_statement;
    uint8 gameRound = 0;
    uint256 bidRound = 0;
    uint8 specialEventFrequency = 5;
    uint64[] args;
    string[] information;
    /** Events */
    event GameJoined(address player);
    event GameStart();
    event RequestOption(bytes32 requestId, string playerTopic, uint8 player_index,string option);
    event FirstRequest(bytes32 requestId, uint8 player_index);
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

    modifier onlyGamePlayers() {
        bool isPlayer = false;
        for (uint256 i = 0; i < PARTICIPANT_NUMBER; ++i) {
            if (s_players[i] == msg.sender) {
                isPlayer = true;
                break;
            }
        }
        if (isPlayer) {
            _;
        } else {
            revert CallerNotGamePlayer(msg.sender);
        }
    }

   

    constructor(address gameCreator) payable {
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
        if (playerNum >= PARTICIPANT_NUMBER) {
            revert ParticipantFull();
        }
        if (getState() != 1) {
            revert GameNotInWaitingState();
        }

        s_players[playerNum] = msg.sender;
        ++playerNum;

        emit GameJoined(msg.sender);

        if (playerNum == PARTICIPANT_NUMBER) {
            i_upperControl.setGameState(2);
            emit GameStart();
        }
    }

    function gameStarting() onlyGameStateInProgress() private {
        if(gameRound == 0){
            for(int i = 0; i< PARTICIPANT_NUMBER;i++)requestAI(i);
            ++gameRound;
        }
        gameFlow();
    }

    function gameFlow() onlyGameStateInProgress()  private {
        for(gameRound; gameRound <= MAX_ROUND; ++gameRound){
            setEventHolder();
            sendNews();
            sendEmail();
            sendMsg();
            getPlayerResponse();
        }
    }

    function sendNews() onlyGameStateInProgress() private {
        i_upperControl.setTime(block.timestamp);
        emit SendNews(event_holder.newsForEachPlayer);
    }

    function sendMsg() onlyGameStateInProgress() private {
        emit SendMsg(event_holder.msgForEachPlayer);
    }

    function sendEmail() onlyGameStateInProgress() private {
        emit SendEmail(event_holder.emailForEachPlayer);
    }

    function setEventHolder() onlyGameStateInProgress() private {
        for(uint256 i = 0; i < PARTICIPANT_NUMBER; ++i){
            for(uint256 j = 0; j < PARTICIPANT_NUMBER; ++j)
            event_holder.newsForEachPlayer[i] = string.concat(event_holder.newsForEachPlayer[i],event_holder.newsOfPlayerDecision[j]);
        }
        event_holder.newsForEachPlayer = ai_response.news;
        event_holder.msgForEachPlayer = ai_response.messenge;
        event_holder.emailForEachPlayer = ai_response.option;
    }

    function setPlayerResponse() onlyGameStateInProgress() private{
        //get player response from front-end;
        // player_response  = array of player response
        //if the player didn't make the decision, playerDecided = false, and then set playerDecision = 1
        for(uint8 i = 0; i < PARTICIPANT_NUMBER; ++i){
            if(player_response[i].playerDecided){
                getPlayerResponse(player_response[i].playerDecision);
            }
            else {
                player_response[i].playerDecision = 1;
            }
        }
    }

    function getPlayerResponse() onlyGameStateInProgress() private{
        //get player's response from function setPlayerResponse
        //send player's response to AI
        for(uitn i = 0 ;i < PARTICIPANT_NUMBER ; i++){
            requestAI(i);
        }
    }
     
    function requestForcast(uint8 player_index) onlyGameStateInProgress() private returns (bytes32 requestId){
        
    }
    function requestAI(uint8 player_index) onlyGameStateInProgress() private returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(block.timestamp, msg.sender, player_index));
        if(gameRound==0){
            emit FirstRequest(requestId,player_index);
        }else{
            emit RequestOption(requestId, player_statement[player_index].topic,player_index,ai_response.option[i]);
        }
    }
    function fulfillRequest(bytes32 requestId, string memory response, uint8 player_index) public {
            ai_response.option[player_index]=response;
    }
    function firstFulfillment(bytes32 requestId,string[] memory response)public{
            for(uint i =0;i<PARTICIPANT_NUMBER;i++){
                    ai_response.player_topic[i] = response[i*3];
                    ai_response.news[i] = response[i*3+1];
                    ai_response.messenge[i] = response[i*3+2];
            }
    }
    function decideRandomEvent(
        uint256 randomWord
    ) public onlyUpperControl() onlyGameStateInProgress() returns (bool received) {
        // take mod of randomWord to decide event
        bidRound = randomWord%15 + 16; //so the bidRound would be 16 ~ 30 
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

    function getPionts(uint256 index) public view returns (address){
        return player_point[index];
    }
}
