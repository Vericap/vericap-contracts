/**
 * @package Imports
 */
const fs = require("fs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const batchABIPath =
  "artifacts/contracts/PlannedCarbonCredit/PCCFactory.sol/PlannedCarbonCredit.json";

/**
 * @global Initializing Global Variables
 */
const fsPromises = fs.promises;
const ZERO_ADDRESS = ethers.constants.AddressZero;

/**
 * @global Parent Describe Test Block
 */
describe("PCC Manager Smart Contract", () => {
  /**
   * @public Block Scoped Variable Declaration
   */
  let PCCFactory, pccFactory, PCCManager, pccManager, owner;

  /**
   * @global Triggers before each describe block
   */
  beforeEach(async () => {
    [owner, add1, add2] = await ethers.getSigners();

    PCCFactory = await hre.ethers.getContractFactory("PCCFactory");
    pccFactory = await upgrades.deployProxy(PCCFactory, [owner.address], {
      kind: "uups",
    });
    await pccFactory.deployed();

    PCCManager = await hre.ethers.getContractFactory("PCCManager");
    pccManager = await upgrades.deployProxy(
      PCCManager,
      [owner.address, pccFactory.address],
      { kind: "uups" }
    );
    await pccManager.deployed();
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
     * @description Case: Setting PCCManager Address Before Every IT Block
     */
    beforeEach("Should update pcc manager contract address", async () => {
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
    });
    /**
     * @description Case: Check For Project Id
     */
    it("Should fail if project Id is zero", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            0,
            1,
            owner.address,
            1000,
            2024,
            "Quarter-3",
            "https://project-1.com/1",
            123
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Commodity Id
     */
    it("Should fail if commodity Id is zero", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            1,
            0,
            owner.address,
            1000,
            2024,
            "Quarter-3",
            "https://project-1.com/1",
            123
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Owner Address
     */
    it("Should fail if batch owner address is a zero address", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            1,
            1,
            ZERO_ADDRESS,
            1000,
            2024,
            "Quarter-3",
            "https://project-1.com/1",
            123
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Supply
     */
    it("Should fail If batch supply is zero", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            1,
            1,
            owner.address,
            0,
            2024,
            "Quarter-3",
            "https://project-1.com/1",
            123
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Delivery Year
     */
    it("Should fail if delivery year is empty", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            1,
            1,
            owner.address,
            1000,
            0,
            "Quarter-3",
            "https://project-1.com/1",
            123
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch URI
     */
    it("Should fail if batch URI is empty", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(1, 1, owner.address, 1000, 2024, "Quarter-3", "", 123)
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Salt/UniqueIdentifier
     */
    it("Should fail if salt is not an integer value", async () => {
      await expect(
        pccFactory
          .connect(owner)
          .createNewBatch(
            1,
            1,
            owner.address,
            1000,
            2024,
            "Quarter-3",
            "https://project-1.com/1",
            0
          )
      ).to.be.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should create new batch successfully", async () => {
      const createNewBatch = await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          123
        );

      expect(createNewBatch)
        .to.emit(pccFactory, "mintNewBatch")
        .withArgs(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          123
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
      batchList = await pccFactory.getBatchListForACommodityInAProject(1, 1);
      batchAddress = batchList[0];

      /**
       * @description Fetch Batch Detail Before Minting More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailBeforeMint = await pccFactory.getBatchDetails(
        1,
        1,
        batchAddress
      );
      batchSupplyBeforeMint = batchDetailBeforeMint[8];

      /**
       * @description mintMoreInABatch Function Call
       */
      await pccManager.mintMoreInABatch(1, 1, batchAddress, 50, owner.address);

      /**
       * @description Fetch Batch Detail After Minting More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterMint = await pccFactory.getBatchDetails(
        1,
        1,
        batchAddress
      );
      batchSupplyAfterMint = batchDetailAfterMint[8];
    });

    /**
     * @description Case: Check For Project Id
     */
    it("Should fail If project Id is zero", async () => {
      await expect(
        pccManager.mintMoreInABatch(0, 1, batchAddress, 50, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Commodity Id
     */
    it("Should fail If commodity Id is zero", async () => {
      await expect(
        pccManager.mintMoreInABatch(1, 0, batchAddress, 50, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Amount To Mint
     */
    it("Should fail If amount is zero", async () => {
      await expect(
        pccManager.mintMoreInABatch(1, 1, batchAddress, 0, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Id
     */
    it("Should fail If batch Id is zero", async () => {
      await expect(
        pccManager.mintMoreInABatch(1, 1, ZERO_ADDRESS, 50, owner.address)
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
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
      await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          123
        );
      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList = await pccFactory.getBatchListForACommodityInAProject(1, 1);
      batchAddress = batchList[0];

      /**
       * @description Fetch Batch Detail After Burning More
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailBeforeBurn = await pccFactory.getBatchDetails(
        1,
        1,
        batchAddress
      );
      batchSupplyBeforeBurn = batchDetailBeforeBurn[8];
      await pccManager.burnFromABatch(1, 1, batchAddress, 50, owner.address);

      /**
       * @description Fetch Batch Detail After Burning
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterBurn = await pccFactory.getBatchDetails(
        1,
        1,
        batchAddress
      );
      batchSupplyAfterBurn = batchDetailAfterBurn[8];
    });

    /**
     * @description Case: Check For Project Id
     */
    it("Should fail If project Id is zero", async () => {
      await expect(
        pccManager.burnFromABatch(0, 1, batchAddress, 50, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Commodity Id
     */
    it("Should fail If commodity Id is zero", async () => {
      await expect(
        pccManager.burnFromABatch(1, 0, batchAddress, 50, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Amount To Burn
     */
    it("Should fail If amount is zero", async () => {
      await expect(
        pccManager.burnFromABatch(1, 1, batchAddress, 0, owner.address)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For Batch Id
     */
    it("Should fail If batch Id is zero", async () => {
      await expect(
        pccManager.burnFromABatch(1, 1, ZERO_ADDRESS, 50, owner.address)
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
   * @description Many To Many PCC Transfer
   */
  describe("Many To Many PCC Transfer", async () => {
    let batchList;
    let balanceBeforeTransfer;
    let balanceAfterTransfer;

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
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
      await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          123
        );
      await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          124
        );
      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInABatch
       * @param projectId
       * @param commodityId
       */
      batchList = await pccFactory.getBatchListForACommodityInABatch(1, 1);

      /**
       * @description Fetching Batch Contract ABI
       */
      let getBatchABI = async () => {
        const data = await fsPromises.readFile(batchABIPath, "utf-8");
        const abi = JSON.parse(data)["abi"];
        return abi;
      };

      let batchABI = await getBatchABI();

      /**
       * @description Creating Batch Instance For Both Batches Created Above
       */
      let batchContractOne = new ethers.Contract(batchList[0], batchABI, owner);
      let batchContractTwo = new ethers.Contract(batchList[1], batchABI, owner);

      /**
       * @description Fetching Balance Of User Address Before Transfer
       * @function balanceOf
       * @param add1
       */
      balanceBeforeTransfer = await batchContractOne.balanceOf(add1.address);

      /**
       * @description Approving PCC Smart Contract To Perform Transfer
       * @param pccToken.address
       * @param amountToApprove
       */
      await batchContractOne.connect(owner).approve(pccManager.address, 1000);
      await batchContractTwo.connect(owner).approve(pccManager.address, 1000);

      /**
       * @description Web3 Function Call
       * @function manyToManyBatchTransfer
       * @param batchList[]
       * @param addressList[]
       * @param amount[]
       */
      await pccManager
        .connect(owner)
        .manyToManyBatchTransfer(
          [batchList[0], batchList[0]],
          [add1.address, add2.address],
          [50, 50]
        );

      /**
       * @description Fetching Balance Of User Address Before Transfer
       * @function balanceOf
       * @param add1
       */
      balanceAfterTransfer = await batchContractOne.balanceOf(add1.address);
    });

    /**
     * @description Case: Check For Uneven Function Argument Length
     */
    it("Should fail If uneven args length", async () => {
      await expect(
        pccManager
          .connect(owner)
          .manyToManyBatchTransfer(
            [batchList[0], batchList[1]],
            [add1.address, add2.address],
            [50]
          )
      ).to.be.revertedWith("UNEVEN_ARGUMENTS_PASSED");
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should perform many-to-many transfer of PCC successfully", async () => {
      expect(balanceAfterTransfer).to.equal(balanceBeforeTransfer + 50);
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
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
      await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          128
        );

      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList = await pccFactory.getBatchListForACommodityInAProject(1, 1);

      /**
       * @description Updating Batch's Delivery Year
       * @function updateBatchPlannedDeliveryYear
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedDeliveryYear
       */
      await pccManager
        .connect(owner)
        .updateBatchPlannedDeliveryYear(1, 1, batchList[0], 2025);

      /**
       * @description Getting Batch Details After Update
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetailAfterUpdate = await pccFactory.getBatchDetails(
        1,
        1,
        batchList[0]
      );
      deliveryYearAfterUpdate = batchDetailAfterUpdate[7];
    });

    /**
     * @description Case: Check For ProjectId
     */
    it("Should fail If projectId is zero", async () => {
      await expect(
        pccManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear(0, 1, batchList[0], 2025)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For CommodityId
     */
    it("Should fail If commodityId is zero", async () => {
      await expect(
        pccManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear(1, 0, batchList[0], 2025)
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For BatchId
     */
    it("Should fail If batchId is zero", async () => {
      await expect(
        pccManager
          .connect(owner)
          .updateBatchPlannedDeliveryYear(1, 1, ZERO_ADDRESS, 2025)
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
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
      await pccFactory
        .connect(owner)
        .createNewBatch(
          1,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/1",
          123
        );

      /**
       * @description Geting List Of Batches w.r.t ProjectId & CommodityId
       * @function getBatchListForACommodityInAProject
       * @param projectId
       * @param commodityId
       */
      batchList = await pccFactory.getBatchListForACommodityInAProject(1, 1);

      /**
       * @description Updating Batch's Delivery Estimate
       * @function updateBatchURI
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedBatchURI
       */
      await pccManager.updateBatchURI(
        1,
        1,
        batchList[0],
        "https://project-1.com/updatedSlug"
      );
      batchDetailAfterUpdate = await pccFactory.getBatchDetails(
        1,
        1,
        batchList[0]
      );
      batchURIAfterUpdate = batchDetailAfterUpdate[3];
    });

    /**
     * @description Case: Check For ProjectId
     */
    it("Should fail If projectId is zero", async () => {
      await expect(
        pccManager.updateBatchURI(
          0,
          1,
          batchList[0],
          "https://project-1.com/updatedSlug"
        )
      ).to.revertedWith("ARGUMENT_PASSED_AS_ZERO");
    });

    /**
     * @description Case: Check For CommodityId
     */
    it("Should fail If commodityId is zero", async () => {
      await expect(
        pccManager.updateBatchURI(
          1,
          0,
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
        pccManager.updateBatchURI(
          1,
          1,
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
