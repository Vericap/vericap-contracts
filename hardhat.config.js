require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-solhint");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("solidity-coverage");
require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    sepolia: {
      url: process.env.ETHEREUM_TESTNET_RPC_URL || "",
      accounts:
        process.env.ADMIN_WALLET_PRIVATE_KEY !== undefined
          ? [process.env.ADMIN_WALLET_PRIVATE_KEY]
          : [],
      gas: "auto",
    },
    polygonAmoy: {
      url: process.env.POLYGON_TESTNET_RPC_URL || "",
      accounts:
        process.env.ADMIN_WALLET_PRIVATE_KEY !== undefined
          ? [process.env.ADMIN_WALLET_PRIVATE_KEY]
          : [],
      gas: "auto",
    },
    polygon: {
      url: process.env.POLYGON_MAINNET_RPC_URL || "",
      accounts:
        process.env.ADMIN_WALLET_PRIVATE_KEY !== undefined
          ? [process.env.ADMIN_WALLET_PRIVATE_KEY]
          : [],
      gas: "auto",
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS_API_KEY !== undefined ? true : false,
    currency: "USD",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHEREUM_API_KEY,
      polygonAmoy: process.env.POLYGON_API_KEY,
      polygon: process.env.POLYGON_API_KEY,
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL:
            "https://www.oklink.com/api/explorer/v1/contract/verify/async/api/polygonAmoy",
          browserURL: "https://www.okx.com/polygonAmoy/",
        },
      },
    ],
  },
  mocha: {
    timeout: 80000,
  },
};
