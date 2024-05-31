
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


// Create a provider and signer
const provider = new ethers.providers.EtherscanProvider("sepolia",process.env.ETHERSCAN_API_KEY);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contract = new ethers.Contract(consumerAddress,abi.abi, wallet);

// Function to make the OpenAI API request
async function makeOpenAiRequest(prompt) {
  

  const openai = new openAI.OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
});

const response  = await openai.chat.completions.create({
    messages: [{ role: "user", content: prompt }],
    model: "gpt-3.5-turbo-16k",
});

  return response.choices[0].message.content;
}

// Function to send data to the smart contract
async function sendToSmartContract(requestId, response) {
  const tx = await contract.fulfillRequest(requestId, response);
  console.log(`Transaction sent: ${tx.hash}`);
  const receipt = await tx.wait();
  console.log(`Transaction mined: ${receipt.transactionHash}`);
}

// Main function to listen for events and handle requests
async function main() {
  
  contract.on('RequestOption', async (requestId, prompt) => {
    console.log(`Request received: ${requestId}, Prompt: ${prompt}`);
    try {
      const openAiResponse = await makeOpenAiRequest(prompt);
      console.log(`OpenAI response: ${openAiResponse}`);
      await sendToSmartContract(requestId, openAiResponse);
    } catch (error) {
      console.error(`Error: ${error.message}`);
    }
  });
  console.log(`Listening for RequestSent events from : ${consumerAddress}...`);
  
}

main();
