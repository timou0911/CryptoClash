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
 * @author Sean Yu, Hunter Lee, Tim Ou 
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
    error NotEnoughBalance(uint256 id, uint256 amount, uint256 balance);
    error NotEnoughListedBalance(uint256 id, uint256 amount, uint256 sellerListedBalance);

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
    }

    struct Player_statement {
        string currencyName;
        uint64 money;
        uint64[5] investment;//5 index just like index of s_players, the array represent a player investment in each cryptocurrency
        string topic;
    }
    struct Event_holder {
        string[] newsForEachPlayer;
        string[] msgForEachPlayer;
        string[] emailForEachPlayer;
    }
    
    /** State Variables */
     uint256 private constant PARTICIPANT_FEE = 0.01 ether;
    uint8 private constant PARTICIPANT_NUMBER = 3;
    uint8 private constant STABLE_COIN_ID = 3;
    uint8 private constant MAX_ROUND = 10;
    uint8 private constant SPECIAL_EVENT_FREQUENCY = 3;
    string private constant ROUNDSTART_REQUESTION = "we just wrote a Game featuring using you to provide game events and decide the outcome, so you should be neutral and make the game versertil for them, now there are five players playing a role in cryptocurrency provider, just random pick a topic (AI, GameFi, defi, etc.) they should work on for them, and now create a random opportunity event as a news for them that will effect the market for each of them, for instance a , for gamefi : there is a off-chain game company want to go on-chain and for the gamefi crypto . some event like this just provide in one line and  a line of player's assistant ask wether to cooperate with them, two line are seperate with / ";

    IUpperControl private immutable i_upperControl;

    uint8 private playerNum = 0;
    uint8 gameRound = 0;
    uint256 bidRound = 0;
    
    //requestion word for requesting ai at first round to get first event and decide which topic player work on.
    AI_response private ai_response;
    Event_holder private event_holder;

    address[PARTICIPANT_NUMBER] public s_players;
    Player_statement[PARTICIPANT_NUMBER] private player_statement;
    uint256[][] args;
    uint256[] information;
    string[] specialEvents = ["Major advancements in blockchain technology lead to price increases.","The approval by the U.S. Securities and Exchange Commission (SEC) results in price increases.","the exchanges are hacked, prices tend to decrease.","Global economic instability causes prices to decrease."];

    mapping(address player => Player_response) private player_response; // Player_response[PARTICIPANT_NUMBER] private player_response;
    mapping(uint256 id => mapping(address account => uint256)) private availableBalance;
    mapping(uint256 id => mapping(address account => uint256)) private listedBalance;
    mapping(uint256 id => uint256 price) private tokenPrice; // Token price per stable coin

    /** Events */
    event GameJoined(address player);
    event GameStart();
    event SendNews(string[] news);//each player hold a index
    event SendEmail(string[] events);
    event SendMsg(string[] suggention);
    event PlayerResponded(address player, uint8 choice);
    event RequestOption(bytes32 requestId, string playerTopic, uint256 player_index,string option);
    event FirstRequest(bytes32 requestId, uint256 player_index);
    event RandomRequest(string randomEvent,uint256 prince);
    event RequestForecast(uint256[] price,uint256[] player_1, uint256[] player_2 ,uint256[] player_3  );
    event TokenListed(uint256 indexed id, address indexed player, uint256 indexed amount);
    event TokenUnlisted(uint256 indexed id, address indexed player, uint256 indexed amount);
    event TokenBought(uint256 indexed id, address indexed seller, uint256 indexed amount);
    
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
        availableBalance[STABLE_COIN_ID][gameCreator] = 10000;
        availableBalance[playerNum][gameCreator] = 1000;
        tokenPrice[playerNum] = 100;
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
        availableBalance[STABLE_COIN_ID][msg.sender] = 10000;
        availableBalance[playerNum][msg.sender] = 1000;
        tokenPrice[playerNum] = 100;
        ++playerNum;

        emit GameJoined(msg.sender);

        if (playerNum == PARTICIPANT_NUMBER) {
            i_upperControl.setGameState(2);
            emit GameStart();
        }
    }

    function gameStarting() private onlyGameStateInProgress() {
        if (gameRound == 0) {
            requestAI(0);
            ++gameRound;
        }
        gameFlow();
    }

    // idea: each process has its event emitted, and let Automation listen to them
    function gameFlow() onlyGameStateInProgress() private {
        setEventHolder();
        sendNews();
        sendEmail();
        sendMsg();
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
        
        event_holder.newsForEachPlayer = ai_response.news;
        event_holder.msgForEachPlayer = ai_response.messenge;
        event_holder.emailForEachPlayer = ai_response.option;
    }

    function setPlayerResponse(uint8 choice) onlyGamePlayers() onlyGameStateInProgress() public {
        player_response[msg.sender].playerDecision = choice;
        emit PlayerResponded(msg.sender, choice);
    }

    function getPlayerResponse() public onlyGameStateInProgress() onlyUpperControl() {
        //get player response from front-end;
        // player_response  = array of player response
        for(uint256 i = 0; i < PARTICIPANT_NUMBER; ++i){
            requestAI(i);
        }
        if(gameRound%3==0){
            requestRandomWord();
        }
        requestForecast();
        gameFlow();
    }
    function requestForecast() onlyGameStateInProgress() private {
        delete args;
        delete information;
        for(uint i = 0;i<PARTICIPANT_NUMBER;i++){
            information.push(getTokenPrice(i));
            for(uint j =0 ;j<PARTICIPANT_NUMBER;j++){
                args[i].push(listedBalanceOf(s_players[i],j));
            }
        }
        emit RequestForecast(information,args[0],args[1],args[2]);
    }
    function finishGame() private onlyGameStateInProgress() {
        i_upperControl.endGame();
    }
    
    function requestAI(uint256 player_index) onlyGameStateInProgress() private returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(block.timestamp, msg.sender, player_index));
        if(gameRound == 0) {
            emit FirstRequest(requestId, player_index);
        } else {
            emit RequestOption(requestId, player_statement[player_index].topic, player_index, ai_response.option[player_index]);
        }
    }
    function fulfillForecast(uint256[] memory newPrice) public onlyGameStateInProgress(){
            for(uint i =0 ;i<PARTICIPANT_NUMBER;i++)tokenPrice[i] = newPrice[i];
    }
    function fulfillRequest( string memory response, uint8 player_index) public {//requestId
            ai_response.option[player_index]=response;
    }

    function firstFulfillment( string[] memory response) public {
        for (uint256 i =0; i < PARTICIPANT_NUMBER; ++i){
            ai_response.player_topic[i] = response[i*3];
            ai_response.news[i] = response[i*3+1];
            ai_response.messenge[i] = response[i*3+2];
        }
    }
    function fuilfillRandom(uint256 price) public onlyGameStateInProgress() {
        for(uint i = 0 ;i< PARTICIPANT_NUMBER;i++)tokenPrice[i]+=(price%tokenPrice[i]);
    }
    function decideRandomEvent(uint256 randomWord) public onlyUpperControl() onlyGameStateInProgress()  {
        for(uint i =0 ;i<PARTICIPANT_NUMBER;i++)ai_response.news[i]= string.concat(ai_response.news[i],specialEvents[randomWord%4]);
        emit RandomRequest(specialEvents[randomWord%4],getTokenPrice(randomWord%4));
    }

    function requestRandomWord() onlyGameStateInProgress() private {
        i_upperControl.requestRandomWord();
    }

    /** Token Related */
    function listToken(uint256 id, uint256 amount) public onlyGamePlayers() onlyGameStateInProgress() {
        uint256 balance = availableBalanceOf(msg.sender, id);
        if (balance < amount) {
            revert NotEnoughBalance(id, amount, balance);
        }

        listedBalance[id][msg.sender] += amount;
        availableBalance[id][msg.sender] -= amount;
        emit TokenListed(id, msg.sender, amount);
    }

    function unlistToken(uint256 id, uint256 amount) public onlyGamePlayers() onlyGameStateInProgress() {
        uint256 playerListedBalance = listedBalanceOf(msg.sender, id);
        if (playerListedBalance < amount) {
            revert NotEnoughListedBalance(id, amount, playerListedBalance);
        }

        listedBalance[id][msg.sender] -= amount;
        availableBalance[id][msg.sender] += amount;
        emit TokenUnlisted(id, msg.sender, amount);
    }

    function buyToken(uint256 id, address seller, uint256 amount) public onlyGamePlayers() onlyGameStateInProgress() {
        uint256 sellerListedBalance = listedBalanceOf(seller, id);
        if (sellerListedBalance < amount) {
            revert NotEnoughListedBalance(id, amount, sellerListedBalance);
        }

        listedBalance[id][seller] -= amount;
        availableBalance[STABLE_COIN_ID][seller] += amount * getTokenPrice(id);
        availableBalance[id][msg.sender] += amount;
        emit TokenBought(id, seller, amount);
    }

    function availableBalanceOf(address account, uint256 id) public view returns (uint256) {
        return availableBalance[id][account];
    }

    function listedBalanceOf(address account, uint256 id) public view returns (uint256) {
        return listedBalance[id][account];
    }

    function getTokenPrice(uint256 id) public view returns (uint256) {
        return tokenPrice[id];
    }

    function getNetWealth(address account) public view returns (uint256 netWealth) {
        netWealth = 0;
        for (uint256 i = 0; i < PARTICIPANT_NUMBER; ++i) {
            netWealth += (availableBalanceOf(account, i) + listedBalanceOf(account, i)) * tokenPrice[i];
        }
        netWealth += (availableBalanceOf(account, STABLE_COIN_ID) + listedBalanceOf(account, STABLE_COIN_ID));
    }


    /** Getter Functions */
    function getState() public returns (uint8) {
        return uint8(i_upperControl.getGameState());
    }

    function getParticipant(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getPoints(uint256 index) public view returns (address){
        return player_point[index];
    }
}
