<img src = "https://i.postimg.cc/15ZnnGrT/favicon-256x256.png" width="80" height="80">

Vericap offers a simple and convenient platform to fund early stage projects
and trade future carbon credits.

#### Clone repository
```bash
git clone https://github.com/Vericap/vericap-contracts.git
```
```bash
git checkout development
```
***
#### Installation
```bash
cd vericap-contracts
npm install
```
***
#### Compile smart contracts
```bash
npx hardhat compile
```
***
#### Test smart contracts
```bash
npx hardhat test
```
***
#### Deployment
Create a .env file in the root directory and add the following variables\
|`REPORT_GAS_API_KEY = ""`\
|`ETHERSCAN_API_KEY = ""`\
|`BSC_API_KEY = ""`\
|`POLYGON_API_KEY = ""`\
|`BSC_TESTNET_RPC_URL = ""`\
|`POLYGON_MAINNET_RPC_URL = ""`\
|`POLYGON_TESTNET_RPC_URL = ""`\
|`GOERLI_TESTNET_RPC_URL = ""`\
|`PCC_FACTORY_CONTRACT_ADDRESS = ""`\
|`ADMIN_WALLET_ADDRESS = ""`\
|`ADMIN_WALLET_PRIVATE_KEY = ""`\
|`TEMP_USER_PRIVATE_KEY = ""`\

Supported networks for deployment
-   localhost
-   goerli
-   bsc testnet
-   polygon (mumbai testnet)

##### Deploying PCC Manager Smart Contract On Mainnet
```bash
npx hardhat run --network localhost scripts/deploy-pcc-manager-v2-mainnet.js
```

##### Deploying PCC Manager Smart Contract On Testnet
```bash
npx hardhat run --network localhost scripts/deploy-pcc-manager-v2-testnet.js
```

***
#### Verify Deployed Smart Contract Mainnet
```bash
npx hardhat verify --network polygon DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```

#### Verify Deployed Smart Contract Testnet
```bash
npx hardhat verify --network polygonTestnet DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```
