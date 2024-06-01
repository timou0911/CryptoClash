
const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();
//const axios = require('axios');
 const openAI=require('openai');
// Load OpenAI API key from environment variables
const openkey = process.env.OPENAI_API_KEY;
if (!openkey) throw new Error('OpenAI API key not found in environment variables');

// Your smart contract address and ABI
const consumerAddress = process.env.CONSUMER_ADDRESS;
const abi = JSON.parse(fs.readFileSync('../out/OpenAiConsumer.sol/OpenAiConsumer.json'));
const { encryptAndUploadSecrets, sendRequest } = require('./request.js'); // adjust the path

// Create a provider and signer
const provider = new ethers.providers.EtherscanProvider("sepolia",process.env.ETHERSCAN_API_KEY);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contract = new ethers.Contract(consumerAddress,abi.abi, wallet);

// Function to make the OpenAI API request
async function makeOpenAiRequest(text) {
  

  const openai = new openAI.OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
});

const response  = await openai.chat.completions.create({
    messages: [{ role: "user", content: text }],
    model: "gpt-4o",
});

  return response.choices[0].message.content;
}
async function sendForecast(requestId, response,player_index) {
  const tx = await contract.fulfillRequest(requestId, response,player_index);
  console.log(`Transaction sent: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`Transaction mined: ${receipt.transactionHash}`);
}
// Function to send data to the smart contract
async function sendToSmartContract(requestId, response,player_index) {
  const tx = await contract.fulfillRequest(requestId, response,player_index);
  console.log(`Transaction sent: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`Transaction mined: ${receipt.transactionHash}`);
}
// Function to send data to the smart contract
async function sendFirstTime(requestId, response) {
  const tx = await contract.firstFulfillment(requestId, response);
  console.log(`Transaction sent: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`Transaction mined: ${receipt.transactionHash}`);
}

// Main function to listen for events and handle requests
async function main() {
  
  contract.on('RequestOption', async (requestId,playerTopic,player_index,option ) => {
    const text = `player is a ${playerTopic} cryptocurrency provder,plz act like the collaborator
    with player and tell him one problem you facing, give two option for him according to the problem, according to the last messenge "${option}" he chosen option 1 what problem you will face next`;
    console.log(`Request received: ${requestId}, Prompt: ${text}`);
    try {
      const openAiResponse = await makeOpenAiRequest(text);
      console.log(`OpenAI response: ${openAiResponse}`);
   
      await sendToSmartContract( openAiResponse,player_index);
    } catch (error) {
      console.error(`Error: ${error.message}`);
    }
  });
  //////
  contract.on('FirstRequest', async (requestId,player_index) => {
    const text = `now there are three players playing a role in cryptocurrency provider, just random pick one topic (AI, GameFi, defi, etc.) they should work on for each of them, and now create a random opportunity event as a news for them that will effect the market for each of them..just provide a topic and event in one line and  a line of player's assistant ask wether to cooperate with them , only reply 1 topic for each player , lines are sperated by %,    
    "reply in this format: gamfi%there is a off-chain game company want to go on-chain and go for the gamefi crypto%there is a oppurtunity should we ..."`;
    console.log(`Request received: ${requestId}, Prompt: ${text}`);
    try {
      const openAiResponse = await makeOpenAiRequest(text);
      console.log(`OpenAI response: ${openAiResponse}`);
      const arrayResponse = (typeof openAiResponse=== 'string'? openAiResponse:openAiResponse.toString()).split('%');
      await sendToSmartContract( openAiResponse);
    } catch (error) {
      console.error(`Error: ${error.message}`);
    }
  });
  console.log(`Listening for RequestSent events from : ${consumerAddress}...`);
  ////
  contract.on('RequestForecast', async (tokenPrice,player_1,player_2,player_3) => {
    const text = `there is three currency
    1. price :${tokenPrice[0]}
    2. price :${tokenPrice[1]}
    3. price :${tokenPrice[2]} 
     and bellow 3 line are how much player buy in each currency , 
    player 1:${player_1}
    player 2:${player_2}
    player 3:${player_3}
    just according the proportion of player investment and give three new price, only give me three new  int number without other text`;
    try {
      const openAiResponse = await makeOpenAiRequest(text);
      console.log(`OpenAI response: ${openAiResponse}`);
      const arrayResponse = (typeof openAiResponse=== 'string'? openAiResponse:openAiResponse.toString()).split(',');
      await sendToSmartContract(openAiResponse);
    } catch (error) {
      console.error(`Error: ${error.message}`);
    }
  });
  console.log(`Listening for RequestForecast events from : ${consumerAddress}...`);
  ////
  contract.on('RandomRequest',async (randomEvent,price)=>{
  const prompt =`${randomEvent} origin: ${price} ,you only  reply a number `;
    encryptAndUploadSecrets()
  .then(() => {
      sendRequest(prompt)
    .then(() => {
      console.log(`RandomRequest has been sent successfully. with ${randomEvent}`);
    })
    .catch((error) => {
      console.error("An error occurred while sending the request:", error);
    });
    })
  })
  .catch((error) => {
    console.error("An error occurred while encrypting and uploading secrets:", error);
  });
  
}

main();