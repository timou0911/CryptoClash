require("./@chainlink/env-enc").config();
// require('dotenv').config()

const { providers, Wallet } = require("ethers");

const RPC_URL = process.env.RPC_URL;

if (!RPC_URL) {
  throw new Error("Please set the RPC_URL environment variable");
}

const provider = new providers.EtherscanProvider("sepolia",process.env.ETHERSCAN_API_KEY);
const wallet = new Wallet(process.env.PRIVATE_KEY);
const signer = wallet.connect(provider);

module.exports = { provider, wallet, signer };
