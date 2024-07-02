/**
 * @package Imports
 */
const fs = require("fs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const plannedCreditABI = require("../testABI/plannedCreditABI.json");
const { Web3 } = require("web3");

/**
 * @global Initializing Global Variables
 */
const fsPromises = fs.promises;
const ZERO_ADDRESS = ethers.constants.AddressZero;
const provider = new Web3.providers.HttpProvider(
  process.env.ETHEREUM_TESTNET_RPC_URL
);
const web3 = new Web3(provider);

/**
 * @global Parent Describe Test Block
 */
describe("Planned Credit Manager Smart Contract", () => {
  /**
   * @public Block Scoped Variable Declaration
   */
  let PlannedCreditFactory,
    plannedCreditFactory,
    PlannedCreditManager,
    plannedCreditManager,
    owner;

  /**
   * @global Triggers before each describe block
   */
  beforeEach(async () => {
    [
      owner,
      projectDeveloperOne,
      projectDeveloperTwo,
      investorOne,
      investorTwo,
      investorThree,
      investorFour,
      investorFive,
    ] = await ethers.getSigners();

    PlannedCreditFactory = await hre.ethers.getContractFactory(
      "PlannedCreditFactory"
    );
    plannedCreditFactory = await upgrades.deployProxy(
      PlannedCreditFactory,
      [owner.address],
      {
        kind: "uups",
      }
    );
    await plannedCreditFactory.deployed();

    PlannedCreditManager = await hre.ethers.getContractFactory(
      "PlannedCreditManager"
    );
    plannedCreditManager = await upgrades.deployProxy(
      PlannedCreditManager,
      [owner.address, plannedCreditFactory.address],
      { kind: "uups" }
    );
    await plannedCreditManager.deployed();

    const CONTRACT_ADDRESS = plannedCreditManager.address;

    contractInstance = new web3.eth.Contract(
      plannedCreditABI,
      CONTRACT_ADDRESS
    );
  });

  /**
   * @description Creats A New Batch
   * @function mintNewBatch
   * @param projectId
   * @param commodityId
   * @param batchOwnerAddress
   * @param amountToMint
   * @param deliveryYear
   * @param deliveryEstimate
   * @param batchURI
   * @param uniqueIdentifier
   */
  describe("Creating A New Batch", () => {
    /**
     * @description Case: Setting Planned Credit Manager Address Before Every IT Block
     */
    beforeEach(
      "Should update planned credit manager contract address",
      async () => {
        await plannedCreditFactory
          .connect(owner)
          .setPlannedCreditManagerContract(plannedCreditManager.address);
      }
    );

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should create new batch successfully", async () => {
      const createNewBatch = await plannedCreditFactory.createNewBatch(
        "PZC",
        "CC",
        "https://project-1.com/1",
        2028,
        1000,
        2024,
        owner.address
      );

      expect(createNewBatch)
        .to.emit(plannedCreditFactory, "mintNewBatch")
        .withArgs(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2024,
          owner.address
        );
    });
  });

  /**
   * @description Mint More In A Batch
   */
  describe("Minting more in a batch", () => {
    let batchList;
    let batchAddress;
    let batchDetailBeforeMint;
    let batchDetailAfterMint;
    let batchSupplyBeforeMint;
    let batchSupplyAfterMint;

    /**
     * @description Call Web3 Function In Before Block
     * @function mintMoreInABatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param batchOwnerAddress
     */
    before("web3 call to mintMoreInABatch", async () => {
      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList =
        await plannedCreditFactory.getBatchListForACommodityInAProject(
          "PZC",
          "CC"
        );
      batchAddress = batchList[0];

      /**
       * @description Fetch Batch Detail Before Minting More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailBeforeMint = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchAddress
      );
      batchSupplyBeforeMint = batchDetailBeforeMint[8];

      /**
       * @description mintMoreInABatch Function Call
       */
      await plannedCreditManager.mintMoreInABatch(
        "PZC",
        "CC",
        batchAddress,
        owner.address,
        50
      );

      /**
       * @description Fetch Batch Detail After Minting More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterMint = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchAddress
      );
      batchSupplyAfterMint = batchDetailAfterMint[8];
    });

    /**
     * @description Case: Check For Project Id
     */
    it("Should fail If project Id is empty", async () => {
      await expect(
        plannedCreditManager.mintMoreInABatch(
          "",
          "CC",
          batchAddress,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Commodity Id
     */
    it("Should fail If commodity Id is empty", async () => {
      await expect(
        plannedCreditManager.mintMoreInABatch(
          "PZC",
          "",
          batchAddress,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Amount To Mint
     */
    it("Should fail If amount is zero", async () => {
      await expect(
        plannedCreditManager.mintMoreInABatch(
          "PZC",
          "CC",
          batchAddress,
          owner.address,
          0
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Id
     */
    it("Should fail If batch Id is zero", async () => {
      await expect(
        plannedCreditManager.mintMoreInABatch(
          "PZC",
          "CC",
          ZERO_ADDRESS,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should mint more in a batch successfully", async () => {
      expect(parseInt(batchSupplyAfterMint)).to.be.equal(
        parseInt(batchSupplyBeforeMint) + parseInt(50)
      );
    });
  });

  /**
   * @description Burn From A Batch
   */
  describe("Burning From A Batch", async () => {
    let batchList;
    let batchAddress;
    let batchDetailBeforeBurn;
    let batchDetailAfterBurn;
    let batchSupplyBeforeBurn;
    let batchSupplyAfterBurn;

    /**
     * @description Call Web3 Function In Before Block
     * @function burnFromABatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToBurn
     * @param batchOwnerAddress
     */
    before("web3 call to burnFromABatch", async () => {
      await plannedCreditFactory
        .connect(owner)
        .setPlannedCreditManagerContract(plannedCreditManager.address);
      await plannedCreditFactory
        .connect(owner)
        .createNewBatch(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2024,
          owner.address
        );
      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList =
        await plannedCreditFactory.getBatchListForACommodityInAProject(
          "PZC",
          "CC"
        );
      batchAddress = batchList[0];

      /**
       * @description Fetch Batch Detail After Burning More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailBeforeBurn = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchAddress
      );
      batchSupplyBeforeBurn = batchDetailBeforeBurn[8];
      await plannedCreditManager.burnFromABatch(
        "PZC",
        "CC",
        batchAddress,
        owner.address,
        50
      );

      /**
       * @description Fetch Batch Detail After Burning
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterBurn = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchAddress
      );
      batchSupplyAfterBurn = batchDetailAfterBurn[8];
    });

    /**
     * @description Case: Check For Project Id
     */
    it("Should fail If project Id is empty", async () => {
      await expect(
        plannedCreditManager.burnFromABatch(
          "",
          "CC",
          batchAddress,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Commodity Id
     */
    it("Should fail If commodity Id is empty", async () => {
      await expect(
        plannedCreditManager.burnFromABatch(
          "PZC",
          "",
          batchAddress,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Amount To Burn
     */
    it("Should fail If amount is zero", async () => {
      await expect(
        plannedCreditManager.burnFromABatch(
          "PZC",
          "CC",
          batchAddress,
          owner.address,
          0
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Id
     */
    it("Should fail If batch Id is zero", async () => {
      await expect(
        plannedCreditManager.burnFromABatch(
          "PZC",
          "CC",
          ZERO_ADDRESS,
          owner.address,
          50
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should burn from a batch successfully", async () => {
      expect(parseInt(batchSupplyAfterBurn)).to.be.equal(
        parseInt(batchSupplyBeforeBurn) - parseInt(50)
      );
    });
  });

  /**
   * @description Many To Many Planned Credit Transfer
   */
  describe("Many To Many Planned Credit Transfer", async () => {
    let batchList;
    let encodedData_1;
    let investorOneBal;
    let investorTwoBal;
    let investorThreeBal;

    /**
     * @description Call Web3 Function In Before Block
     * @function createNewBatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param deliveryYear
     * @param deliveryEstimate
     * @param uniqueIdentifier
     */
    before("web3 call to manyToManyTransfer", async () => {
      await plannedCreditFactory
        .connect(owner)
        .setPlannedCreditManagerContract(plannedCreditManager.address);
      await plannedCreditFactory
        .connect(owner)
        .createNewBatch(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2022,
          projectDeveloperOne.address
        );

      await plannedCreditFactory
        .connect(owner)
        .createNewBatch(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2023,
          projectDeveloperTwo.address
        );
      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList =
        await plannedCreditFactory.getBatchListForACommodityInAProject(
          "PZC",
          "CC"
        );

      /**
       * @description Creating Batch Instance For Both Batches Created Above
       */
      let batchContractOne = new ethers.Contract(
        batchList[0],
        plannedCreditABI,
        owner
      );
      let batchContractTwo = new ethers.Contract(
        batchList[1],
        plannedCreditABI,
        owner
      );

      /**
       * @description Approving Planned Credit Smart Contract To Perform Transfer
       * @param plannedCreditToken.address
       * @param amountToApprove
       */
      await batchContractOne
        .connect(projectDeveloperOne)
        .approve(plannedCreditManager.address, 10000000);
      await batchContractTwo
        .connect(projectDeveloperTwo)
        .approve(plannedCreditManager.address, 10000000);

      let dataToEncode_1 = [
        [
          [investorOne.address, investorTwo.address, investorThree.address],
          [10, 20, 30],
        ],
        [
          [investorOne.address, investorTwo.address, investorThree.address],
          [10, 20, 30],
        ],
      ];

      const convertEncodedDataToReadableStream_1 = async () => {
        const encodedArguments = [];
        for (let i = 0; i < dataToEncode_1.length; i++) {
          const encodedDataToTransfer =
            await encodeFunctionArgumentsForManyToManyTransfer_1(
              dataToEncode_1[i]
            );
          encodedArguments.push(encodedDataToTransfer);
        }
        return encodedArguments;
      };

      const encodeFunctionArgumentsForManyToManyTransfer_1 = async (data) => {
        const encodedData = web3.eth.abi.encodeParameters(
          ["address[]", "uint256[]"],
          data
        );
        return encodedData;
      };

      encodedData_1 = await convertEncodedDataToReadableStream_1();

      /**
       * @description Web3 Function Call
       * @function manyToManyBatchTransfer
       * @param batchList[]
       * @param addressList[]
       * @param amount[]
       */
      await plannedCreditManager
        .connect(owner)
        .manyToManyBatchTransfer(
          [batchList[0], batchList[1]],
          [projectDeveloperOne.address, projectDeveloperTwo.address],
          encodedData_1
        );

      /**
       * @description Fetching Balance Of User Address Before Transfer
       * @function balanceOf
       * @param projectDeveloperOne
       */
      investorOneBal =
        parseInt(await batchContractOne.balanceOf(investorOne.address)) +
        parseInt(await batchContractTwo.balanceOf(investorOne.address));
      investorTwoBal =
        parseInt(await batchContractOne.balanceOf(investorTwo.address)) +
        parseInt(await batchContractTwo.balanceOf(investorTwo.address));
      investorThreeBal =
        parseInt(await batchContractOne.balanceOf(investorThree.address)) +
        parseInt(await batchContractTwo.balanceOf(investorThree.address));
    });

    /**
     * @description Case: Check For Uneven Function Argument Length
     */
    it("Should fail If uneven args length", async () => {
      await expect(
        plannedCreditManager
          .connect(owner)
          .manyToManyBatchTransfer(
            [batchList[0]],
            [projectDeveloperOne.address, projectDeveloperTwo.address],
            encodedData_1
          )
      ).to.be.revertedWith("UNEVEN_ARGUMENTS_PASSED");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should perform many-to-many transfer of Planned Credit successfully", async () => {
      expect(investorOneBal).to.equal(parseInt(20));
      expect(investorTwoBal).to.equal(parseInt(40));
      expect(investorThreeBal).to.equal(parseInt(60));
    });
  });

  /**
   * @description Update Batch Delivery Year
   */
  describe("Updating Batch Delivery Year", async () => {
    let batchList = [];
    let batchDetailAfterUpdate;
    let deliveryYearAfterUpdate;

    /**
     * @description Call Web3 Function Before Each Block
     * @function createNewBatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param deliveryYear
     * @param deliveryEstimate
     * @param uniqueIdentifier
     */
    before("web3 call to updateBatchDeliveryYear", async () => {
      await plannedCreditFactory
        .connect(owner)
        .setPlannedCreditManagerContract(plannedCreditManager.address);
      await plannedCreditFactory
        .connect(owner)
        .createNewBatch(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2021,
          owner.address
        );

      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList =
        await plannedCreditFactory.getBatchListForACommodityInAProject(
          "PZC",
          "CC"
        );

      /**
       * @description Updating Batch's Delivery Year
       * @function updateBatchPlannedDeliveryYear
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedDeliveryYear
       */
      await plannedCreditManager
        .connect(owner)
        .updateBatchPlannedDeliveryYear("PZC", "CC", batchList[0], 2025);

      /**
       * @description Getting Batch Details After Update
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterUpdate = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchList[0]
      );
      deliveryYearAfterUpdate = batchDetailAfterUpdate[3];
    });

    /**
     * @description Case: Check For ProjectId
     */
    it("Should fail If projectId is empty", async () => {
      await expect(
        plannedCreditManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear("", "CC", batchList[0], 2025)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For CommodityId
     */
    it("Should fail If commodityId is empty", async () => {
      await expect(
        plannedCreditManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear("PZC", "", batchList[0], 2025)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For BatchId
     */
    it("Should fail If batchId is zero", async () => {
      await expect(
        plannedCreditManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear("PZC", "CC", ZERO_ADDRESS, 2025)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should update delivery year successfully", async () => {
      expect(deliveryYearAfterUpdate).to.equal(2025);
    });
  });

  /**
   * @description Update Batch URI
   */
  describe("Updating Batch URI", async () => {
    let batchList;
    let batchDetailAfterUpdate;
    let batchURIAfterUpdate;

    /**
     * @description Call Web3 Function Before Each Block
     * @function mintNewBatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param deliveryYear
     * @param deliveryEstimate
     * @param uniqueIdentifier
     */
    before("web3 call to updateBatchURI", async () => {
      await plannedCreditFactory
        .connect(owner)
        .setPlannedCreditManagerContract(plannedCreditManager.address);
      await plannedCreditFactory
        .connect(owner)
        .createNewBatch(
          "PZC",
          "CC",
          "https://project-1.com/1",
          2028,
          1000,
          2020,
          owner.address
        );

      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList =
        await plannedCreditFactory.getBatchListForACommodityInAProject(
          "PZC",
          "CC"
        );

      /**
       * @description Updating Batch's Delivery Estimate
       * @function updateBatchURI
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedBatchURI
       */
      await plannedCreditManager.updateBatchURI(
        "PZC",
        "CC",
        batchList[0],
        "https://project-1.com/updatedSlug"
      );
      batchDetailAfterUpdate = await plannedCreditFactory.getBatchDetails(
        "PZC",
        "CC",
        batchList[0]
      );
      batchURIAfterUpdate = batchDetailAfterUpdate[2];
    });

    /**
     * @description Case: Check For ProjectId
     */
    it("Should fail If projectId is empty", async () => {
      await expect(
        plannedCreditManager.updateBatchURI(
          "",
          "CC",
          batchList[0],
          "https://project-1.com/updatedSlug"
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For CommodityId
     */
    it("Should fail If commodityId is empty", async () => {
      await expect(
        plannedCreditManager.updateBatchURI(
          "PZC",
          "",
          batchList[0],
          "https://project-1.com/updatedSlug"
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For BatchId
     */
    it("Should fail If batchId is zero", async () => {
      await expect(
        plannedCreditManager.updateBatchURI(
          "PZC",
          "CC",
          ZERO_ADDRESS,
          "https://project-1.com/updatedSlug"
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should update batch URI successfully", async () => {
      expect(String(batchURIAfterUpdate)).to.equal(
        "https://project-1.com/updatedSlug"
      );
    });
  });
});
