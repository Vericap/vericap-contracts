/**
 * @package Imports
 */
const fs = require("fs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const batchABIPath =
  "artifacts/contracts/PlannedCredit/PlannedCreditFactory.sol/PlannedCredit.json";

/**
 * @global Initializing Global Variables
 */
const fsPromises = fs.promises;
const ZERO_ADDRESS = ethers.constants.AddressZero;

/**
 * @global Parent Describe Test Block
 */
describe("Planned Credit Factory Smart Contract", () => {
  /**
   * @public Block Scoped Variable Declaration
   */
  let VerifiedCreditFactory,
    verifiedCreditFactory,
    owner,
    add1,
    add2;

  /**
   * @global Triggers before each describe block
   */
  beforeEach(async () => {
    [owner, add1, add2] = await ethers.getSigners();

    VerifiedCreditFactory = await hre.ethers.getContractFactory(
      "VerifiedCreditFactory"
    );
    verifiedCreditFactory = await upgrades.deployProxy(
        VerifiedCreditFactory,
      [owner.address],
      {
        kind: "uups",
      }
    );
    await verifiedCreditFactory.deployed();
  });

  describe("Setting Up Planned Credit Manager Contract Address", async () => {

    it("Should Create Verified Credit", async () => {
        const createVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerfiedCredit(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2024,
          2028,
          1000
        );

        console.log("Created");

        const detail = await getVerifiedCreditDetail.connect(owner).getVerifiedCreditDetail("PZC", "CC", 2024);
        console.log(detail);
    })
  })
});
