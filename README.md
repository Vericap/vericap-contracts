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

---

#### Installation

```bash
cd vericap-contracts
npm install
```

---

#### Compile smart contracts

```bash
npx hardhat compile
```

---

#### Test smart contracts

```bash
npx hardhat test
```

---

#### Generate hardhat coverage report

```bash
npx hardhat coverage
```

---

#### Deployment

Create a .env file in the root directory and add the following variables\
|`POLYGON_API_KEY = ""`\
|`ETHEREUM_API_KEY = ""`\
|`ETHEREUM_TESTNET_RPC_URL = ""`\
|`POLYGON_TESTNET_RPC_URL = ""`\
|`POLYGON_MAINNET_RPC_URL = ""`\
|`ADMIN_WALLET_PRIVATE_KEY = ""`\
|`ADMIN_WALLET_ADDRESS = ""`\
|`PLANNED_CREDIT_FACTORY_CONTRACT_ADDRESS = ""`\

Supported networks for deployment

- localhost
- sepolia testnet
- polygon (amoy testnet)

##### Deploying Smart Contract Over Mainnet

```bash
npx hardhat run --network polygon scripts/${script name}
```

##### Deploying Smart Contract On Testnet

```bash
npx hardhat run --network sepolia scripts/${script name}
```

---

#### Verify Deployed Smart Contract Mainnet

```bash
npx hardhat verify --network polygon DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```

#### Verify Deployed Smart Contract Testnet

```bash
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS "Constructor argument 1"
```
