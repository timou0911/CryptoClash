require("./@chainlink/env-enc").config()
// require('dotenv').config()
//this is the file contain all information for chainlink function that is listed on chainlink reference
const DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS = 2;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const networks = {
  ethereumSepolia: {
    gasPrice: undefined,
    nonce: undefined,
    accounts: [PRIVATE_KEY],
    verifyApiKey: process.env.ETHERSCAN_API_KEY || "UNSET",
    chainId: 11155111,
    confirmations: DEFAULT_VERIFICATION_BLOCK_CONFIRMATIONS,
    nativeCurrencySymbol: "ETH",
    linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    linkPriceFeed: "0x42585eD362B3f1BCa95c640FdFf35Ef899212734", // LINK/ETH
    functionsRouter: "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0",
    donId: "fun-ethereum-sepolia-1",
    gatewayUrls: [
      "https://01.functions-gateway.testnet.chain.link/",
      "https://02.functions-gateway.testnet.chain.link/",
    ],
  },
  
};

module.exports = {
  networks,
};
