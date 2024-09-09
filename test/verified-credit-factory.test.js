/**
 * @package Imports
 */
const fs = require("fs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

/**
 * @global Initializing Global Variables
 */
const fsPromises = fs.promises;
const ZERO_ADDRESS = ethers.constants.AddressZero;

/**
 * @global Parent Describe Test Block
 */
describe("Verified Credit Factory Smart Contract", () => {
  /**
   * @public Block Scoped Variable Declaration
   */
  let VerifiedCreditFactory,
    verifiedCreditFactory,
    PlannedCreditFactory,
    plannedCreditFactory,
    PlannedCreditManager,
    plannedCreditManager,
    owner,
    add1,
    add2;

  /**
   * @global Triggers before each describe block
   */
  beforeEach(async () => {
    [owner, add1, add2] = await ethers.getSigners();

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

    VerifiedCreditFactory = await hre.ethers.getContractFactory(
      "VerifiedCreditFactory"
    );
    verifiedCreditFactory = await upgrades.deployProxy(
      VerifiedCreditFactory,
      [
        owner.address,
        plannedCreditFactory.address,
        plannedCreditManager.address,
      ],
      {
        kind: "uups",
      }
    );
    await verifiedCreditFactory.deployed();
  });

  describe("Create A New Verified Credit", async () => {
    it("Should Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/04/2025",
          "VCC-PZC-CC-2024",
          2000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();

      await expect(verifiedCredit)
        .to.emit(verifiedCreditFactory, "VerifiedCreditCreated")
        .withArgs(
          "PZC",
          "CC",
          2024,
          "22/04/2025",
          0,
          "VCC-PZC-CC-2024",
          2000,
          "https://project-1.com/1"
        );
    });
  });

  describe("Issued More Verified Credits To A Vinatag-Issuance Date Pair", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "VCC-PZC-CC-2024",
          2000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();
    });

    it("Should Issue More Verified Credits", async () => {
      const issueVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .issueVerifiedCredit("PZC", "CC", 2024, "22/06/2025", 1000);

      await issueVerifiedCredit.wait();

      await expect(issueVerifiedCredit)
        .to.emit(verifiedCreditFactory, "IssuedVerifiedCredit")
        .withArgs("PZC", "CC", 2024, "22/06/2025", 0, 1000, 3000);
    });
  });

  describe("Block Verified Credits To A Vinatag-Issuance Date Pair", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/08/2025",
          "VCC-PZC-CC-2024",
          3000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();
    });

    it("Should Block Verified Credits", async () => {
      const blockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .blockVerifiedCredits("PZC", "CC", 2024, "22/08/2025", 1000);

      await blockVerifiedCredit.wait();

      await expect(blockVerifiedCredit)
        .to.emit(verifiedCreditFactory, "BlockedVerifiedCredit")
        .withArgs("PZC", "CC", 2024, "22/08/2025", 0, 1000, 2000);
    });
  });

  describe("Unblock Verified Credits To A Vinatag-Issuance Date Pair", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/10/2025",
          "VCC-PZC-CC-2024",
          4000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();

      const blockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .blockVerifiedCredits("PZC", "CC", 2024, "22/10/2025", 1000);

      await blockVerifiedCredit.wait();
    });

    it("Should Unblock Verified Credits", async () => {
      const unblockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .unBlockVerifiedCredits("PZC", "CC", 2024, "22/10/2025", 1000);

      await unblockVerifiedCredit.wait();

      await expect(unblockVerifiedCredit)
        .to.emit(verifiedCreditFactory, "UnblockedVerifiedCredit")
        .withArgs("PZC", "CC", 2024, "22/10/2025", 0, 1000, 4000);
    });
  });

  describe("Transfer Verified Credit", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/02/2025",
          "VCC-PZC-CC-2024",
          4000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();
    });

    it("Should Transfer Verified Credits", async () => {
      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/02/2025");

      const approveAdminToTransfer = await verifiedCreditFactory
        .connect(owner)
        .approveAdminToTransfer(owner.address);

      approveAdminToTransfer.wait();

      const transferVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .transferVerifiedCreditOutside(
          "PZC",
          "CC",
          2024,
          "22/02/2025",
          1000,
          owner.address
        );

      await transferVerifiedCredit.wait();

      expect(transferVerifiedCredit)
        .to.emit(verifiedCreditFactory, "TransferSingle")
        .withArgs(
          verifiedCreditFactory.address,
          verifiedCreditFactory.address,
          owner.address,
          1000
        );
    });
  });

  describe("Swap VPC with VCC For A Vintage", async () => {
    beforeEach(
      "Create Planned And Verified Credits For A Vintage",
      async () => {
        const setPlannedCreditManager = await plannedCreditFactory
          .connect(owner)
          .setPlannedCreditManagerContract(plannedCreditManager.address);

        await setPlannedCreditManager.wait();

        const plannedCredit = await plannedCreditFactory
          .connect(owner)
          .createPlannedCredit(
            "PZC",
            "CC",
            "https://project-1.com/1",
            2028,
            5000,
            2024,
            owner.address
          );

        await plannedCredit.wait();

        const verifiedCredit = await verifiedCreditFactory
          .connect(owner)
          .createVerifiedCredit(
            "PZC",
            "CC",
            2024,
            "22/12/2025",
            "VCC-PZC-CC-2024",
            4000,
            "https://project-1.com/1"
          );

        await verifiedCredit.wait();
      }
    );

    it("Should Swap Planned Credit (VPC) To Verified Credit (VCC)", async () => {
      const plannedCreditList =
        await plannedCreditFactory.getPlannedCreditListForACommodityInAProject(
          "PZC",
          "CC"
        );
      const plannedCreditReference = plannedCreditList[0];

      const approveAdminToTransfer = await verifiedCreditFactory
        .connect(owner)
        .approveAdminToTransfer(owner.address);

      approveAdminToTransfer.wait();

      const MANAGER_ROLE = await plannedCreditManager.MANAGER_ROLE();

      const grantManagerRole = await plannedCreditManager
        .connect(owner)
        .grantRole(MANAGER_ROLE, verifiedCreditFactory.address);

      await grantManagerRole.wait();

      const swappedPlannedCredit = await verifiedCreditFactory
        .connect(owner)
        .swapVerifiedCredits(
          "PZC",
          "CC",
          2024,
          "22/12/2025",
          2000,
          plannedCreditReference,
          owner.address
        );

      await swappedPlannedCredit.wait();

      await expect(swappedPlannedCredit)
        .to.emit(verifiedCreditFactory, "SwappedVerifiedCredit")
        .withArgs(
          "PZC",
          "CC",
          2024,
          "22/12/2025",
          2000,
          plannedCreditReference,
          owner.address
        );
    });
  });

  describe("Retire Verified Credits For A Vinatag", async () => {
    beforeEach("Create New Verified Credit And Transfer To User", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/08/2025",
          "VCC-PZC-CC-2024",
          3000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();

      const approveAdminToTransfer = await verifiedCreditFactory
        .connect(owner)
        .approveAdminToTransfer(owner.address);

      approveAdminToTransfer.wait();

      const transferVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .transferVerifiedCreditOutside(
          "PZC",
          "CC",
          2024,
          "22/08/2025",
          1000,
          owner.address
        );

      await transferVerifiedCredit.wait();
    });

    it("Should Retire Verified Credits", async () => {
      const retireVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .retireVerifiedCredits(
          "PZC",
          "CC",
          2024,
          "22/08/2025",
          500,
          owner.address
        );

      await retireVerifiedCredit.wait();

      await expect(retireVerifiedCredit)
        .to.emit(verifiedCreditFactory, "RetiredVerifiedCredit")
        .withArgs("PZC", "CC", 2024, "22/08/2025", 500, owner.address, 2500);
    });
  });

  describe("Update URI For A Verified Crefit", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "VCC-PZC-CC-2024",
          2000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();
    });

    it("Should Update URI", async () => {
      const updatedURI = await verifiedCreditFactory
        .connect(owner)
        .updateVerifiedCreditURI(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "https://update-URI.com/xyz"
        );

      await updatedURI.wait();

      await expect(updatedURI)
        .to.emit(verifiedCreditFactory, "URIUpdateForVerifiedCredit")
        .withArgs(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "https://update-URI.com/xyz"
        );
    });
  });

  describe("Update Verified Credit Storage", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "VCC-PZC-CC-2024",
          3000,
          "https://project-1.com/1"
        );

      await verifiedCredit.wait();
    });

    it("Should Update Verified Credit Detail Post Creation", async () => {
      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.projectId).to.be.eq("PZC");
      expect(verifiedCreditDetail.commodityId).to.be.eq("CC");
      expect(verifiedCreditDetail.vintage).to.be.eq(2024);
      expect(verifiedCreditDetail.issuanceDate).to.be.eq("22/06/2025");
      expect(verifiedCreditDetail.ticker).to.be.eq("VCC-PZC-CC-2024");
      expect(verifiedCreditDetail.issuedCredits).to.be.eq(3000);
      expect(verifiedCreditDetail.availableCredits).to.be.eq(3000);
      expect(verifiedCreditDetail.tokenURI).to.be.eq("https://project-1.com/1");
      expect(verifiedCreditDetail.tokenId).to.be.eq(0);
    });

    it("Should Update Verified Credit Existance", async () => {
      const verifiedCreditExistance =
        await verifiedCreditFactory.verifiedCreditExistance(
          "PZC",
          "CC",
          "2024",
          "22/06/2025"
        );

      expect(verifiedCreditExistance).to.be.eq(true);
    });

    it("Should Update Verified Credit Detail Post Issuance Of More Credit", async () => {
      const issueVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .issueVerifiedCredit("PZC", "CC", 2024, "22/06/2025", 1000);

      await issueVerifiedCredit.wait();

      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.issuedCredits).to.be.eq(4000);
      expect(verifiedCreditDetail.availableCredits).to.be.eq(4000);
    });

    it("Should Update Verified Credit Detail Post Block", async () => {
      const blockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .blockVerifiedCredits("PZC", "CC", 2024, "22/06/2025", 1000);

      await blockVerifiedCredit.wait();

      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.availableCredits).to.be.eq(2000);
      expect(verifiedCreditDetail.blockedCredits).to.be.eq(1000);
    });

    it("Should Update Verified Credit Detail Post Unblock", async () => {
      const blockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .blockVerifiedCredits("PZC", "CC", 2024, "22/06/2025", 1000);

      await blockVerifiedCredit.wait();

      const unblockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .unBlockVerifiedCredits("PZC", "CC", 2024, "22/06/2025", 1000);

      await unblockVerifiedCredit.wait();

      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.availableCredits).to.be.eq(3000);
      expect(verifiedCreditDetail.blockedCredits).to.be.eq(0);
    });

    it("Should Update Verified Credit Detail Post Retirement", async () => {
      const approveAdminToTransfer = await verifiedCreditFactory
        .connect(owner)
        .approveAdminToTransfer(owner.address);

      approveAdminToTransfer.wait();

      const transferVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .transferVerifiedCreditOutside(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          1000,
          owner.address
        );

      await transferVerifiedCredit.wait();

      const retireVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .retireVerifiedCredits(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          500,
          owner.address
        );

      await retireVerifiedCredit.wait();

      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.availableCredits).to.be.eq(2500);
      expect(verifiedCreditDetail.retiredCredits).to.be.eq(500);
    });
  });

  describe("Fetch Storage For Verified Credit", async () => {
    beforeEach("Create New Verified Credit", async () => {
      const verifiedCreditOne = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          "VCC-PZC-CC-2024",
          2000,
          "https://project-1.com/1"
        );

      await verifiedCreditOne.wait();

      const verifiedCreditTwo = await verifiedCreditFactory
        .connect(owner)
        .createVerifiedCredit(
          "PZC",
          "CC",
          2024,
          "22/08/2025",
          "VCC-PZC-CC-2024",
          1000,
          "https://project-1.com/1"
        );

      await verifiedCreditTwo.wait();

      const approveAdminToTransfer = await verifiedCreditFactory
        .connect(owner)
        .approveAdminToTransfer(owner.address);

      approveAdminToTransfer.wait();

      const transferVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .transferVerifiedCreditOutside(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          1000,
          owner.address
        );

      await transferVerifiedCredit.wait();

      const blockVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .blockVerifiedCredits("PZC", "CC", 2024, "22/06/2025", 500);

      await blockVerifiedCredit.wait();

      const retireVerifiedCredit = await verifiedCreditFactory
        .connect(owner)
        .retireVerifiedCredits(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          100,
          owner.address
        );

      await retireVerifiedCredit.wait();
    });

    it("Should Fetch Verified Credit Detail Post Creation", async () => {
      const verifiedCreditDetail = await verifiedCreditFactory
        .connect(owner)
        .getVerifiedCreditDetail("PZC", "CC", 2024, "22/06/2025");

      expect(verifiedCreditDetail.projectId).to.be.eq("PZC");
      expect(verifiedCreditDetail.commodityId).to.be.eq("CC");
      expect(verifiedCreditDetail.vintage).to.be.eq(2024);
      expect(verifiedCreditDetail.issuanceDate).to.be.eq("22/06/2025");
      expect(verifiedCreditDetail.ticker).to.be.eq("VCC-PZC-CC-2024");
      expect(verifiedCreditDetail.issuedCredits).to.be.eq(2000);
      expect(verifiedCreditDetail.availableCredits).to.be.eq(1400);
      expect(verifiedCreditDetail.tokenURI).to.be.eq("https://project-1.com/1");
      expect(verifiedCreditDetail.tokenId).to.be.eq(0);
    });

    it("Should Fetch User Balance Per Issuance Date", async () => {
      const userBalance =
        await verifiedCreditFactory.getUserBalancePerIssuanceDate(
          "PZC",
          "CC",
          2024,
          "22/06/2025",
          owner.address
        );

      expect(userBalance).to.be.eq(900);
    });

    it("Should Fetch Aggregated Data For A Vintage", async () => {
      const verifiedCreditDetail =
        await verifiedCreditFactory.getVerifiedCreditDetail(
          "PZC",
          "CC",
          2024,
          "22/06/2025"
        );

      const aggregatedDetail =
        await verifiedCreditFactory.getAggregatedDataPerVintage(2024);

      expect(aggregatedDetail.issuedCredits).to.eq(3000);
      expect(aggregatedDetail.availableCredits).to.eq(2400);
      expect(aggregatedDetail.blockedCredits).to.eq(500);
      expect(aggregatedDetail.retiredCredits).to.eq(100);
    });
  });
});
