const HDWalletProvider = require('@truffle/hdwallet-provider');
var secret = require("./secret");

module.exports = {
  plugins: ["solidity-coverage"],
  networks: {
    development: {
      // truffle deploy --network development
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      from: "0x7f87C43136F7A4c78788bEb8e39EE400328f184a"
    },
    test: {
      // truffle deploy --network test
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    ropsten: {
      // https://infura.io/dashboard/ethereum
      // truffle deploy --network ropsten
      provider: () => new HDWalletProvider(secret.MMENOMIC, `https://ropsten.infura.io/v3/${secret.API_KEY}`),
      network_id: 3,      // Ropsten's id
      gas: 5500000        // Ropsten has a lower block limit than mainnet
    },
    mainnet: {
      // https://infura.io/dashboard/ethereum
      // truffle deploy --network mainnet
      provider: () => new HDWalletProvider(secret.MMENOMIC, `https://mainnet.infura.io/v3/${secret.API_KEY}`),
      network_id: 1,      // Ropsten's id
      gas: 5500000        // Ropsten has a lower block limit than mainnet
    }
  },
  compilers: {
    solc: {
      version: "0.8.9"
    }
  }
};