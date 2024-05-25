import { ethers } from "../ethers-5.6.esm.min.js";
import upperControlMetadata from "../../out/UpperControl.sol/UpperControl.json" with { type: 'json' };
import gameMetadata from "../../out/Game.sol/Game.json" with { type: 'json' };

const upperControlABI = upperControlMetadata.abi;
const upperControlAddr = "0xdAE4a9dabA1f6485C95d3753a7e637847214233e";
const gameABI = gameMetadata.abi;
const PARTICIPANT_FEE = "0.01";

const connectButton = document.getElementById("connectButton");
const createGameButton = document.getElementById("createGameButton");
const enterGameButton = document.getElementById("enterGameButton");
const gameAddressText = document.getElementById("gameAddress");
const accountText = document.getElementById("account");
connectButton.onclick = connect;
createGameButton.onclick = createGame;
enterGameButton.onclick = enterGame;

let accounts;
let account;
let gameAddress;

async function connect() {
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
        accountText.innerHTML = account;
        console.log("Connected Accounts: ", accounts);
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
            console.log("TX Response: ", txResponse);
            await listenForTxMine(txResponse, provider);
            upperControl.on("GameCreated", async (gameAddress) => {
                console.log("-- Game Address: ", gameAddress);
            });
            const block = await provider.getBlockNumber()
            const event = await upperControl.queryFilter("GameCreated", block - 1, block)
            gameAddress = event[0].args.gameAddress

            const game = new ethers.Contract(gameAddress, gameABI, signer);

            console.log("-- Game Address: ", gameAddress)
            console.log("-- Game Entered: ", await game.getParticipant(0));

            gameAddressText.innerHTML = gameAddress
            console.log("Game Creating Finished");
        } catch (error) {
            console.log(error);
            console.log("Game Creating Failed");
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

async function enterGame() {
    console.log("Game Entering...");
    if (typeof window.ethereum !== "undefined") {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const game = new ethers.Contract(gameAddress, gameABI, signer);
        // game has wrong address of upperControl (maybe pass upperControl address to constructor)
        try {
            let txResponse = await game.enterGame({
                value: ethers.utils.parseEther(PARTICIPANT_FEE),
            });
            console.log("TX Response: ", txResponse);
            await listenForTxMine(txResponse, provider);

            const block = await provider.getBlockNumber()
            const event = await game.queryFilter("GameEntered", block-1, block)
            console.log(event)
            console.log("-- Game Entered: ", account);
        } catch (error) {
            console.log(error);
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

function listenForTxMine(txResponse, provider) {  
    console.log(`Mining ${txResponse.hash}`)
    return new Promise((resolve, reject) => {
      provider.once(txResponse.hash, (transactionReceipt) => {
        console.log(
          `Completed with ${transactionReceipt.confirmations} confirmations. `
        )
        resolve()
      })
    })
}