const { Contract } = require("ethers");
const fs = require("fs");
const path = require("path");
const { Location } = require("../@chainlink/functions-toolkit");
require('dotenv').config()
// require('dotenv').config()
//this is the script that call contract for sending request host by chainlink functions;
const { networks } = require("../networks.js");
const { signer } = require(".=./connection.js");
const  abi  = require("../out/UpperControl.sol/UpperControl.json"); // abi to the contract that send request 

const consumerAddress = "0xBf4393Eef08fB5a838008345D855167D4C587407";
const subscriptionId = "2877";
const encryptedSecretsRef = "0xa266736c6f744964006776657273696f6e1a66570b0c";
const NETWORK = "ethereumSepolia";

const functionsRouterAddress = networks[NETWORK].functionsRouter;
const donId = networks[NETWORK].donId;
const encryptAndUploadSecrets = async () => {
  const secretsManager = new SecretsManager({
    signer,
    functionsRouterAddress,
    donId,
  });

  await secretsManager.initialize();

  if (!process.env.GPT_API_KEY) {
    throw Error("GPT_API_KEY not found in .env.enc file");
  }

  const secrets = {
    apiKey: process.env.OPENAI_API_KEY,
  };
  console.log(secrets)
  const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

  const gatewayUrls = networks[NETWORK].gatewayUrls;
  const slotId = 0;
  const minutesUntilExpiration = 75;

  const {
    version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
    success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
  } = await secretsManager.uploadEncryptedSecretsToDON({
    encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
    gatewayUrls,
    slotId,
    minutesUntilExpiration,
  });

  if (success){
    console.log("\nUploaded secrets to DON...")
    encryptedSecretsRef =  secretsManager.buildDONHostedEncryptedSecretsReference({
        slotId,
        version
    })

    console.log(`\nMake a note of the encryptedSecretsReference: ${encryptedSecretsRef} `)
  }

};

/*encryptAndUploadSecrets().catch(err => {
  console.log("Error encrypting and uploading secrets:  ", err);
});*/
const sendRequest = async (prompt) => {
  if (!consumerAddress || !encryptedSecretsRef || !subscriptionId) {
    throw Error("Missing required environment variables.");
  }
  const functionsConsumer = new Contract(consumerAddress, abi, signer);

  const source = fs
    .readFileSync(path.resolve(__dirname, "./source.js"))
    .toString();


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

/*sendRequest().catch(err => {
  console.log("\nError making the Functions Request : ", err);
});*/
module.exports = {
  encryptAndUploadSecrets,
  sendRequest,
};