import { ethers } from "../ethers-5.6.esm.min.js";
import upperControlMetadata from "../../out/UpperControl.sol/UpperControl.json" with { type: 'json' };
import gameMetadata from "../../out/Game.sol/Game.json" with { type: 'json' };

const upperControlABI = upperControlMetadata.abi;
const upperControlAddr = "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9";
const gameABI = gameMetadata.abi;
const PARTICIPANT_FEE = "0.01";

const connectButton = document.getElementById("connectButton");
const createGameButton = document.getElementById("createGameButton");
const enterGame = document.getElementById("enterGameButton");
connectButton.onclick = connect;
createGameButton.onclick = createGame;
enterGameButton.onclick = enterGame;

async function connect() {
    if (typeof window.ethereum !== "undefined") {
        try {
            await ethereum.request({ method: "eth_requestAccounts" });
        } catch (error) {
            console.log(error);
        }
        const accounts = await ethereum.request({ method: "eth_accounts" });
        connectButton.innerHTML = "Connected: " + accounts;
        console.log(accounts);
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
            const txResponse = await upperControl.createGame({
                value: ethers.utils.parseEther(PARTICIPANT_FEE),
            });
            console.log("TX Response: ", txResponse);
            // const gameAddr = ethers.utils.defaultAbiCoder.decode("address", txResponse);
            // console.log("Game Address: ", gameAddr);
            // await listenForTxMine(txResponse, provider);
        } catch (error) {
            console.log(error);
        }
    } else {
        createGameButton.innerHTML = "Please install MetaMask";
    }
}

function listenForTxMine(txnResponse, provider) {
    console.log(`Mining ${txnResponse.hash}`)
    return new Promise((resolve, reject) => {
      provider.once(txnResponse.hash, (transactionReceipt) => {
        console.log(
          `Completed with ${transactionReceipt.confirmations} confirmations. `
        )
        resolve()
      })
    })
}