// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
require("dotenv").config();

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.

  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  let PlannedCarbonCredit;
  let plannedCarbonCredit;
  try {
    await hre.run("compile");
    PlannedCarbonCredit = await hre.ethers.getContractFactory(
      "PlannedCarbonCreditFactory"
    );
    plannedCarbonCredit = await upgrades.deployProxy(PlannedCarbonCredit, {
      kind: "uups",
    });
    await plannedCarbonCredit.deployed();
  } catch (err) {
    console.log("Smart contract deployment failed", err);
  }

  const waitForDeployment = (seconds) => {
    console.log(
      `\n\x1b[33m${"[waiting]"}\x1b[0m Preparing smart contract deployment. Just a moment... \n`
    );
    setTimeout(() => {
      console.log(
        `\x1b[1m\x1b[32m${"[success]"}\x1b[0m Planned Carbon Credit smart contrat deployed successfully to: \x1b[4mhttps://www.oklink.com/amoy/address/${
          plannedCarbonCredit.address
        }#code\x1b[0m \n`
      );
    }, seconds);
  };
  waitForDeployment(3000);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
