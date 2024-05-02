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
describe("PCC Factory Smart Contract", () => {
  /**
   * @public Block Scoped Variable Declaration
   */
  let PCCFactory, pccFactory, PCCManager, pccManager, owner, add1, add2;

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
   * @description Setup PCC Manager Address
   * @function setPCCManagerContract
   * @param pccManagerContract
   */
  describe("Setting Up PCC Manager Contract Address", async () => {
    /**
		 * @description Case: Check For PCC Manager Address
		 *          uint256 _projectId,
					uint256 _commodityId,
					address _batchOwner,
					uint256 _batchSupply,
					uint256 _plannedDeliveryYear,
					string calldata _vintage,
					string calldata _batchURI,
					uint256 _uniqueIdentifier
		 */
    it("Should fail if manager contract address is zero", async () => {
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
            123
          )
      ).to.be.reverted;
    });
    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should set pcc manager contract address successfully", async () => {
      await pccFactory.connect(owner).setPCCManagerContract(pccManager.address);
      expect(await pccFactory.pccManagerContract()).to.equal(
        pccManager.address
      );
    });
  });

  /**
   * @description Creats A New Batch
   * @function createNewBatch
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
        .to.emit(pccFactory, "NewBatchCreated")
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
  describe("Mint More In A Batch", () => {
    let batchList;
    let batchAddress;
    let batchDetailBeforeMint;
    let batchDetailAfterMint;
    let batchSupplyBeforeMint;
    let batchSupplyAfterMint;

    /**
     * @description Call Web3 Function In Before Block
     * @function createNewBatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param batchOwnerAddress
     */
    before(
      "web3 call to updateBatchDetailDuringDeliveryYearChange",
      async () => {
        /**
         * @description Getting List Of Batches w.r.t ProjectId & CommodityId
         * @function getBatchListForACommodityInAProject
         * @param projectId
         * @param commodityId
         */
        await pccFactory
          .connect(owner)
          .setPCCManagerContract(pccManager.address);
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
         * @description updateBatchDetailDuringMintOrBurnMore Function Call
         */
        await pccFactory.updateBatchDetailDuringMintOrBurnMore(
          1,
          1,
          batchAddress,
          50,
          0
        );

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
      }
    );

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should update contract storage when minted more in a batch successfully", async () => {
      expect(parseInt(batchSupplyAfterMint)).to.be.equal(
        parseInt(batchSupplyBeforeMint) + parseInt(50)
      );
    });
  });

  /**
   * @description Burn More In A Batch
   */
  describe("Burn More In A Batch", () => {
    let batchList;
    let batchAddress;
    let batchDetailBeforeMint;
    let batchDetailAfterMint;
    let batchSupplyBeforeMint;
    let batchSupplyAfterMint;

    /**
     * @description Call Web3 Function In Before Block
     * @function createNewBatch
     * @param projectId
     * @param commodityId
     * @param batchId
     * @param amountToMint
     * @param batchOwnerAddress
     */
    before(
      "web3 call to updateBatchDetailDuringDeliveryYearChange",
      async () => {
        /**
         * @description Getting List Of Batches w.r.t ProjectId & CommodityId
         * @function getBatchListForACommodityInAProject
         * @param projectId
         * @param commodityId
         */
        await pccFactory
          .connect(owner)
          .setPCCManagerContract(pccManager.address);

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
          .setPCCManagerContract(pccManager.address);
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
         * @description updateBatchDetailDuringMintOrBurnMore Function Call
         */
        await pccFactory.updateBatchDetailDuringMintOrBurnMore(
          1,
          1,
          batchAddress,
          50,
          1
        );

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
      }
    );

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should update contract storage when burned from a batch successfully", async () => {
      expect(parseInt(batchSupplyAfterMint)).to.be.equal(
        parseInt(batchSupplyBeforeMint) - parseInt(50)
      );
    });
  });

  /**
   * @description Update Batch Delivery Year
   */
  describe("Updating Batch Delivery Year", async () => {
    let batchList;
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
       * @description updateBatchDetailDuringDeliveryYearChange Update Batch's Delivery Year
       * @function updateBatchDeliveryYear
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedDeliveryYear
       */
      await pccFactory.updateBatchDetailDuringPlannedDeliveryYearChange(
        1,
        1,
        batchList[0],
        2025
      );

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
     * @function createNewBatch
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
       * @description updateBatchDetailDuringURIChange Update Batch's Delivery Estimate
       * @function updateBatchURI
       * @param projectId
       * @param commodityId
       * @param batchId
       * @param updatedBatchURI
       */
      await pccFactory.updateBatchDetailDuringURIChange(
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
     * @description Case: Successful Call To Web3 Function
     */
    it("Should update batch URI successfully", async () => {
      expect(String(batchURIAfterUpdate)).to.equal(
        "https://project-1.com/updatedSlug"
      );
    });
  });

  /**
   * @description Grant Manager Role For A PCCBatch Contract
   */
  describe("Grant MANAGER_ROLE", async () => {
    let batchList;
    let batchAddress;
    let batchABI;
    let batchContractInstance;
    let MANAGER_ROLE = await pccFactory.connect(owner).MANAGER_ROLE();
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
       * @function getBatchListForACommodityInABatch
       * @param projectId
       * @param commodityId
       */
      batchList = await pccFactory.getBatchListForACommodityInABatch(1, 1);
      batchAddress = batchList[0];

      /**
       * @description updateBatchDetailDuringURIChange Update Batch's Delivery Estimate
       * @function grantManagerRoleForBatch
       * @param batchId
       * @param userAddress
       */
      await pccFactory.grantManagerRoleForBatch(batchAddress, add1.address);

      /**
       * @description Fetching Batch Contract ABI
       */
      getBatchABI = async () => {
        const data = await fsPromises.readFile(batchABIPath, "utf-8");
        const abi = JSON.parse(data)["abi"];
        return abi;
      };

      batchABI = await getBatchABI();

      /**
       * @description Creating Batch Instance For Both Batches Created Above
       */
      batchContractInstance = new ethers.Contract(
        batchList[0],
        batchABI,
        owner
      );
    });

    it("Should grant MANAGER_ROLE successfully", async () => {
      expect(
        String(await batchContractInstance.hasRole(MANAGER_ROLE, add1.address))
      ).to.be.equal("true");
    });
  });

  /**
   * @description Fetch List Of Projects
   */
  describe("Fetch Project List", async () => {
    let projectListLength = 0;
    let projectList;

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
    before("web3 call to getProjectList", async () => {
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
          126
        );
      projectListLength += 1;
      await pccFactory
        .connect(owner)
        .createNewBatch(
          15,
          1,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/2",
          127
        );
      projectListLength += 1;

      /**
       * @description Fetch Project List
       * @function getProjectList
       */
      projectList = await pccFactory.connect(owner).getProjectList();
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should fetch project list successfully", async () => {
      expect(projectList.length).to.be.equal(projectListLength);
    });
  });

  /**
   * @description Fetch List Of Commodities w.r.t ProjectId
   */
  describe("Fetch Commodity List", async () => {
    let commodityList;

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
    before("web3 call to getCommodityListForAProject", async () => {
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
          13,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/2",
          124
        );

      /**
       * @description Fetch List Of Commodities
       * @function getCommodityListForAProject
       * @param projectId
       */
      commodityList = await pccFactory.getCommodityListForAProject(1);
    });

    /**
     * @description Case: Successful Call To Web2 Function
     */
    it("Should fetch commodity list successfully", async () => {
      expect(commodityList.length).to.be.equal(2);
    });
  });

  /**
   * @description Fetch Total Supply For Project-Commodity Pair
   */
  describe("Fetch Project-Commodity Total Supply", async () => {
    let currentSupply;

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
    before("web3 call to getCommodityListForAProject", async () => {
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
          2,
          owner.address,
          1000,
          2024,
          "Quarter-3",
          "https://project-1.com/2",
          124
        );

      /**
       * @description Fetch Total Supply For Project-Commodity Pair
       * @function getProjectCommodityTotalSupply
       * @param projectId
       */
      currentSupply = await pccFactory.getProjectCommodityTotalSupply(1, 1);
    });

    /**
     * @description Case: Successful Call To Web2 Function
     */
    it("Should total supply successfully", async () => {
      expect(String(currentSupply)).to.equal("1000");
    });
  });

  /**
   * @description Fetch Decimals Of A Batch Contract
   */
  describe("Fetch Batch Contract Decimals", async () => {
    let batchList;
    let batchDetail;
    let batchAddress;
    let decimals;

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
    before("web3 call to decimals", async () => {
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
       * @description Fetch Batch Details
       * @function getBatchDetails
       * @param projectId
       * @param commodityId
       * @param batchId
       */
      batchDetail = await pccFactory.getBatchDetails(1, 1, batchList[0]);
      batchAddress = batchDetail[0];

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
      let batchContractInstance = new ethers.Contract(
        batchList[0],
        batchABI,
        owner
      );

      /**
       * @description Fetch Decimals For Batch Contract
       * @function decimals
       */
      decimals = await batchContractInstance.decimals();
    });

    /**
     * @description Case: Successful Call To Web3 Function
     */
    it("Should fetch batch contract decimals successfully", async () => {
      expect(decimals).to.be.equal(5);
    });
  });
});
