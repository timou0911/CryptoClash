const { Contract } = require("ethers");
const fs = require("fs");
const path = require("path");
const { Location } = require("../@chainlink/functions-toolkit");
require("../@chainlink/env-enc").config();
// require('dotenv').config()
//this is the script that call contract for sending request host by chainlink functions;
const { signer } = require(".=./connection.js");
const  abi  = require("../contracts/abi/FunctionsConsumer.json"); // abi to the contract that send request 

const consumerAddress = "0xBf4393Eef08fB5a838008345D855167D4C587407";
const subscriptionId = "2877";
const encryptedSecretsRef = "0xa266736c6f744964006776657273696f6e1a66570b0c";
 
const sendRequest = async () => {
  if (!consumerAddress || !encryptedSecretsRef || !subscriptionId) {
    throw Error("Missing required environment variables.");
  }
  const functionsConsumer = new Contract(consumerAddress, abi, signer);

  const source = fs
    .readFileSync(path.resolve(__dirname, "../source.js"))
    .toString();

  const prompt = "Pick five topic of cryptocurrency and seprated with /";
  const args = [prompt];
  const callbackGasLimit = 300_000;

  console.log("\n Sending the Request....")
  const requestTx = await functionsConsumer.sendRequest(
    source,
    Location.DONHosted,
    encryptedSecretsRef,
    args,
    [], // bytesArgs can be empty
    subscriptionId,
    callbackGasLimit
  );

  const txReceipt = await requestTx.wait(1);
  const requestId = txReceipt.events[2].args.id;
  console.log(
    `\nRequest made.  Request Id is ${requestId}. TxHash is ${requestTx.hash}`
  );
};

sendRequest().catch(err => {
  console.log("\nError making the Functions Request : ", err);
});