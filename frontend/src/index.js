import { ethers } from "../ethers-5.6.esm.min.js";
import upperControlMetadata from "../../out/UpperControl.sol/UpperControl.json" with { type: 'json' };
import gameMetadata from "../../out/Game.sol/Game.json" with { type: 'json' };

const upperControlABI = upperControlMetadata.abi;
const upperControlAddr = "0xAa6C08849Da3A9Ca69f52558525A8C443B561a45";
const gameABI = gameMetadata.abi;
const PARTICIPANT_FEE = "0.01";

const connectButton = document.getElementById("connectButton");
const createGameButton = document.getElementById("createGameButton");
const enterGameButton = document.getElementById("enterGameButton");
const setGameButton = document.getElementById("setGameButton");
const choiceButton = document.getElementById("choiceButton");
const listTokenButton = document.getElementById("listTokenButton");
const unlistTokenButton = document.getElementById("unlistTokenButton");
const buyTokenButton = document.getElementById("buyTokenButton");

connectButton.onclick = connect;
createGameButton.onclick = createGame;
enterGameButton.onclick = enterGame;
setGameButton.onclick = setGame;
choiceButton.onclick = setPlayerResponse;
listTokenButton.onclick = listToken;
unlistTokenButton.onclick = unlistToken;
buyTokenButton.onclick = buyToken;

let accounts;
let account;
let gameAddress;
let players = [];
let tokenPrice = [0, 0, 0];
let availableBalance = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
let listedBalance = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
let totalBalance = [0, 0, 0];

async function connect() {
    console.log("Connecting...");

    if (typeof window.ethereum !== "undefined") {
        try {
            await ethereum.request({ method: "eth_requestAccounts" });
        } catch (error) {
            console.log(error);
        }

        const provider = new ethers.providers.Web3Provider(window.ethereum);
        const network = await provider.getNetwork();
        accounts = await provider.listAccounts();
        account = ethers.utils.getAddress(accounts[0]);

        document.getElementById("account").innerHTML = account;

        console.log("Account Connected: ", account);
        console.log("With Chain ID: ", network.chainId);
    } else {
        connectButton.innerHTML = "Please install MetaMask";
    }
}

async function createGame() {
    console.log("Game Creating...");

    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const upperControl = new ethers.Contract(upperControlAddr, upperControlABI, signer);

        try {
            let txResponse = await upperControl.createGame({
                value: ethers.utils.parseEther(PARTICIPANT_FEE),
            });
            await listenForTxMine(txResponse, provider);

            upperControl.on("GameCreated", async (gameAddress) => {
                console.log("-- Game Address: ", gameAddress);
            });

            const block = await provider.getBlockNumber();
            const event = await upperControl.queryFilter("GameCreated", block - 1, block);
            gameAddress = event[0].args.gameAddr;
            const game = new ethers.Contract(gameAddress, gameABI, signer);
            let player = await game.getPlayer(0);
            players.push(player);
            document.getElementById("player1").innerHTML = player.substring(0, 6) + "...Balance";
            document.getElementById("token1").innerHTML = "Token " + player.substring(0, 6);

            document.getElementById("gameAddress").innerHTML = gameAddress;

            console.log("-- Game Address Created: ", gameAddress);
            console.log("-- Game Entered with Player Address: ", player);
            console.log("Game Creating Finished");

            updateData();
            setInterval(updateData, 10000);

        } catch (error) {
            console.log(error);
            console.log("Game Creating Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function enterGame() {
    const gameAddressToJoin = document.getElementById("gameToEnter").value;
    console.log("Entering Game with Game Address... ", gameAddressToJoin);
    
    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToJoin, gameABI, signer);

        try {
            let txResponse = await game.enterGame({
                value: ethers.utils.parseEther(PARTICIPANT_FEE),
            });
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber();
            const event = await game.queryFilter("GameJoined", block - 1, block);
            let player = event[0].args.player;
            players.push(player);
            if (players.length === 2) {
                document.getElementById("player2").innerHTML = player.substring(0, 6) + "...Balance";
                document.getElementById("token2").innerHTML = "Token " + player.substring(0, 6);
            } else {
                document.getElementById("player3").innerHTML = player.substring(0, 6) + "...Balance";
                document.getElementById("token3").innerHTML = "Token " + player.substring(0, 6);
            }
            
            console.log("-- Game Entered with Player Address: ", player);
            updateData();
            setInterval(updateData, 10000);
        } catch (error) {
            console.log(error);
            console.log("Game Entering Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function setGame() {
    const gameAddressToSet = document.getElementById("setGame").value;
    gameAddress = gameAddressToSet;
    console.log("Setting Game Address... ", gameAddressToSet);
    
    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToSet, gameABI, signer);

        try {
            players = [];
            for (let i = 0; i < 3; ++i) {
                let player = await game.getPlayer(i);
                let playerid = "player" + (i + 1);
                let tokenid = "token" + (i + 1);
                document.getElementById(playerid).innerHTML = player.substring(0, 6) + "...Balance";
                document.getElementById(tokenid).innerHTML = "Token " + player.substring(0, 6);
                players.push(player);
            }
            
            console.log("-- Game Set: ");
            updateData();
            setInterval(updateData, 10000);
        } catch (error) {
            console.log(error);
            console.log("Game Entering Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function setPlayerResponse() {
    const choice = parseInt(document.getElementById("choiceList").value);
    console.log("Choice: ", choice)
    console.log("Getting Player Response... ");

    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToJoin, gameABI, signer);

        try {
            let txResponse = await game.setPlayerResponse(choice);
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber();
            const event = await game.queryFilter("ResponseSet", block - 1, block);
            
            console.log("-- Player Set Choice: ", event[0].args.choice);
        } catch (error) {
            console.log(error);
            console.log("Choice Set Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function listToken() {
    const tokenId = parseInt(document.getElementById("listTokenList").value);
    const amount = document.getElementById("listTokenAmount").value;
    console.log("Token ID to List", tokenId, "with Amount", amount);
    console.log("Listing Token... ");

    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToJoin, gameABI, signer);

        try {
            let txResponse = await game.listToken(tokenId, amount);
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber();
            const event = await game.queryFilter("TokenListed", block - 1, block);
            
            console.log("-- Token Listed with ID: ", event[0].args.id, " and Amount", event[0].args.amount);
        } catch (error) {
            console.log(error);
            console.log("Token Listing Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function unlistToken() {
    const tokenId = parseInt(document.getElementById("unlistTokenList").value);
    const amount = document.getElementById("lunistTokenAmount").value;
    console.log("Token ID to Unlist", tokenId, "with Amount", amount);
    console.log("Unlisting Token... ");
    
    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToJoin, gameABI, signer);

        try {
            let txResponse = await game.unlistToken(tokenId, amount);
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber();
            const event = await game.queryFilter("TokenUnlisted", block - 1, block);
            
            console.log("-- Token Unlisted with ID: ", event[0].args.id, " and Amount", event[0].args.amount);
        } catch (error) {
            console.log(error);
            console.log("Token Unlisting Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function buyToken() {
    const tokenId = parseInt(document.getElementById("buyTokenList").value);
    const amount = document.getElementById("buyTokenAmount").value;
    const seller = document.getElementById("buyTokenFrom").value;
    console.log("Token ID to Buy", tokenId, "with Amount", amount);
    console.log("Buying Token... ");
    
    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddressToJoin, gameABI, signer);

        try {
            let txResponse = await game.buyToken(tokenId, seller, amount);
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber();
            const event = await game.queryFilter("TokenBought", block - 1, block);
            
            console.log("-- Token Bought with ID: ", event[0].args.id, " and Amount ", event[0].args.amount, " From ", event[0].args.seller);
        } catch (error) {
            console.log(error);
            console.log("Token Buying Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function updateData() {
    console.log("Retrieving Data... ");

    if (typeof window.ethereum !== "undefined" && gameAddress !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddress, gameABI, signer);

        try {
            console.log("Player length", players.length);
            for (let i = 0; i < players.length; ++i) {
                let price = await game.getTokenPrice(i);
                tokenPrice[i] = price;
                for (let j = 0; j < players.length; ++j) {
                    availableBalance[i][j] = await game.availableBalanceOf(players[i], j);
                    listedBalance[i][j] = await game.listedBalanceOf(players[i], j);
                }
                availableBalance[i][3] = await game.availableBalanceOf(players[i], 3);
                let balance = await game.getNetWealth(players[i]);
                totalBalance[i] = balance;
            }

            document.getElementById("token1Price").innerHTML = tokenPrice[0];
            document.getElementById("token2Price").innerHTML = tokenPrice[1];
            document.getElementById("token3Price").innerHTML = tokenPrice[2];
            document.getElementById("player1Token1Balance").innerHTML = availableBalance[0][0] + "/" + listedBalance[0][0];
            document.getElementById("player2Token1Balance").innerHTML = availableBalance[1][0] + "/" + listedBalance[1][0];
            document.getElementById("player3Token1Balance").innerHTML = availableBalance[2][0] + "/" + listedBalance[2][0];            document.getElementById("player1Token2Balance").innerHTML = availableBalance[0][1] + "/" + listedBalance[0][1];
            document.getElementById("player2Token2Balance").innerHTML = availableBalance[1][1] + "/" + listedBalance[1][1];
            document.getElementById("player3Token2Balance").innerHTML = availableBalance[2][1] + "/" + listedBalance[2][1];
            document.getElementById("player1Token3Balance").innerHTML = availableBalance[0][2] + "/" + listedBalance[0][2];
            document.getElementById("player2Token3Balance").innerHTML = availableBalance[1][2] + "/" + listedBalance[1][2];
            document.getElementById("player3Token3Balance").innerHTML = availableBalance[2][2] + "/" + listedBalance[2][2];
            document.getElementById("player1StableCoinBalance").innerHTML = availableBalance[0][3];
            document.getElementById("player2StableCoinBalance").innerHTML = availableBalance[1][3];
            document.getElementById("player3StableCoinBalance").innerHTML = availableBalance[2][3];
            document.getElementById("player1TotalBalance").innerHTML = totalBalance[0];
            document.getElementById("player2TotalBalance").innerHTML = totalBalance[1];
            document.getElementById("player3TotalBalance").innerHTML = totalBalance[2];

            console.log("Data Retrieving Finished");
        } catch (error) {
            console.log(error);
            console.log("Data Retrieving Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

function listenForTxMine(txResponse, provider) {  
    console.log(`Mining ${txResponse.hash}`);
    return new Promise((resolve, reject) => {
      provider.once(txResponse.hash, (transactionReceipt) => {
          console.log(
              `Completed with ${transactionReceipt.confirmations} confirmations. `
          );
          resolve();
      })
    })
}

choiceButton.onclick = (event) => {
    event.preventDefault();
    setPlayerResponse();
}

listTokenButton.onclick = (event) => {
    event.preventDefault();
    listToken();
}

unlistTokenButton.onclick = (event) => {
    event.preventDefault();
    unlistToken();
}

buyTokenButton.onclick = (event) => {
    event.preventDefault();
    buyToken();
}