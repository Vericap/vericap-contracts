/**
 * @package Imports
 */
const { expect } = require('chai')
const { ethers, upgrades, network } = require('hardhat')
const { Web3 } = require('web3')
require('dotenv').config()

/**
 * @global Initializing Global Variables
 */
const ZERO_ADDRESS = ethers.constants.AddressZero
const web3Provider = new Web3.providers.HttpProvider(
	process.env.POLYGON_TESTNET_RPC_URL
)
const web3Instance = new Web3(web3Provider)

/**
 * @global Parent Describe Test Block
 */
describe('PCC Manager V2 Smart Contract', () => {
	/**
	 * @public Block Scoped Variable Declaration
	 */
	let PCCManagerV2, pccManagerV2, owner

	/**
	 * @global Triggers before each describe block
	 */
	beforeEach(async () => {
		;[owner, projectDev1, projectDev2, projectDev3, add1, add2] =
			await ethers.getSigners()

		PCCManagerV2 = await hre.ethers.getContractFactory('PCCManagerV2')
		pccManagerV2 = await upgrades.deployProxy(
			PCCManagerV2,
			[owner.address],
			{ kind: 'uups' }
		)
		await pccManagerV2.deployed()
	})

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
	describe('Create A New Batch', async () => {
		/**
		 * @description Case: Check For Project Id
		 */
		it('Should fail if project Id is zero', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						0,
						1,
						owner.address,
						1000,
						2024,
						'Quarter-3',
						'https://project-1.com/1'
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should fail if commodity Id is zero', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						1,
						0,
						owner.address,
						1000,
						2024,
						'Quarter-3',
						'https://project-1.com/1'
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Batch Owner Address
		 */
		it('Should fail if batch owner address is a zero address', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						1,
						1,
						ZERO_ADDRESS,
						1000,
						2024,
						'Quarter-3',
						'https://project-1.com/1'
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Batch Supply
		 */
		it('Should fail If batch supply is zero', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						1,
						1,
						owner.address,
						0,
						2024,
						'Quarter-3',
						'https://project-1.com/1'
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Delivery Year
		 */
		it('Should fail if delivery year is empty', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						1,
						1,
						owner.address,
						1000,
						0,
						'Quarter-3',
						'https://project-1.com/1'
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Batch URI
		 */
		it('Should fail if batch URI is empty', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.createNewBatch(
						1,
						1,
						owner.address,
						1000,
						2024,
						'Quarter-3',
						''
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should create new batch successfully', async () => {
			const createNewBatch = await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)

			await expect(createNewBatch).to.emit(
				pccManagerV2,
				'NewBatchCreated'
			)
		})
	})

	/**
	 * @description Mint More In A Batch
	 */
	describe('Minting more In a batch', () => {
		let batchList
		let batchId
		let batchDetailAfterMint
		let batchSupplyAfterMint

		/**
		 * @description Call Web3 Function In Before Block
		 * @function mintMoreInABatch
		 * @param projectId
		 * @param commodityId
		 * @param batchId
		 * @param amountToMint
		 * @param batchOwnerAddress
		 */
		before('web3 call to mintMoreInABatch', async () => {
			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInAProject
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)
			batchId = batchList[0]

			/**
			 * @description mintMoreInABatch Function Call
			 */
			await pccManagerV2.mintMoreInABatch(
				1,
				1,
				batchId,
				50,
				owner.address
			)

			/**
			 * @description Fetch Batch Detail After Minting More
			 * @function getBatchDetails
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 */
			batchDetailAfterMint = await pccManagerV2.getBatchDetails(
				1,
				1,
				batchId
			)
			batchSupplyAfterMint = batchDetailAfterMint[7]
		})

		/**
		 * @description Case: Check For Project Id
		 */
		it('Should fail If project Id is zero', async () => {
			await expect(
				pccManagerV2.mintMoreInABatch(0, 1, batchId, 50, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should fail If commodity Id is zero', async () => {
			await expect(
				pccManagerV2.mintMoreInABatch(1, 0, batchId, 50, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Amount To Mint
		 */
		it('Should fail If amount is zero', async () => {
			await expect(
				pccManagerV2.mintMoreInABatch(1, 1, batchId, 0, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Batch Id
		 */
		it('Should fail If batch Id is zero', async () => {
			await expect(
				pccManagerV2.mintMoreInABatch(1, 1, 0, 50, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should mint more in a batch successfully', async () => {
			expect(parseInt(batchSupplyAfterMint)).to.be.equal(1050)
		})
	})

	/**
	 * @description Burn From A Batch
	 */
	describe('Burning From A Batch', async () => {
		let batchList
		let batchId
		let batchDetailAfterBurn
		let batchSupplyAfterBurn

		/**
		 * @description Call Web3 Function In Before Block
		 * @function burnFromABatch
		 * @param projectId
		 * @param commodityId
		 * @param batchId
		 * @param amountToBurn
		 * @param batchOwnerAddress
		 */
		before('web3 call to burnFromABatch', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)

			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInABatch
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)
			batchId = batchList[0]

			await pccManagerV2.burnFromABatch(1, 1, batchId, 50, owner.address)

			/**
			 * @description Fetch Batch Detail After Burning
			 * @function getBatchDetails
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 */
			batchDetailAfterBurn = await pccManagerV2.getBatchDetails(
				1,
				1,
				batchId
			)
			batchSupplyAfterBurn = batchDetailAfterBurn[7]
		})

		/**
		 * @description Case: Check For Project Id
		 */
		it('Should fail If project Id is zero', async () => {
			await expect(
				pccManagerV2.burnFromABatch(0, 1, batchId, 50, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should fail If commodity Id is zero', async () => {
			await expect(
				pccManagerV2.burnFromABatch(1, 0, batchId, 50, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Amount To Burn
		 */
		it('Should fail If amount is zero', async () => {
			await expect(
				pccManagerV2.burnFromABatch(1, 1, batchId, 0, owner.address)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Batch Id
		 */
		it('Should fail If batch Id is zero', async () => {
			await expect(
				pccManagerV2.burnFromABatch(
					1,
					1,
					ZERO_ADDRESS,
					50,
					owner.address
				)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should burn from a batch successfully', async () => {
			expect(parseInt(batchSupplyAfterBurn)).to.be.equal(950)
		})
	})

	/**
	 * @description Many To Many PCC Transfer
	 */
	describe('Many To Many PCC Transfer', async () => {
		let batchList
		const encodedFunctionArguments = []
		const balanceOfAdd1AfterTransfer = []
		const balanceOfAdd2AfterTransfer = []

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
		before('web3 call to manyToManyTransfer', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					projectDev1.address,
					1000,
					2021,
					'Quarter-1',
					'https://project-1.com/1'
				)

			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					projectDev2.address,
					1000,
					2022,
					'Quarter-2',
					'https://project-1.com/2'
				)
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					projectDev3.address,
					1000,
					2023,
					'Quarter-3',
					'https://project-1.com/3'
				)
			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInABatch
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)

			/**
			 * @description Approving PCC Smart Contract To Perform Transfer
			 * @param pccToken.address
			 * @param amountToApprove
             * @dev Project developers needs to approve the PCCManager. 
                    As, PCCManager will trigger the transfer function in PCCBatch contract
			 */
			await pccManagerV2
				.connect(projectDev1)
				.setApprovalForAll(owner.address, 1000)
			await pccManagerV2
				.connect(projectDev2)
				.setApprovalForAll(owner.address, 1000)
			await pccManagerV2
				.connect(projectDev3)
				.setApprovalForAll(owner.address, 1000)

			/**
			 * @description Converting args to bytes
			 */
			const batchTransferDataForBatchContractOne = [
				[add1.address, add2.address],
				[10, 10],
			]
			const batchTransferDataForBatchContractTwo = [
				[add1.address, add2.address],
				[20, 20],
			]
			const batchTransferDataForBatchContractThree = [
				[add1.address, add2.address],
				[30, 30],
			]
			encodedFunctionArguments.push(
				String(
					web3Instance.eth.abi.encodeParameters(
						['address[]', 'uint256[]'],
						batchTransferDataForBatchContractOne
					)
				)
			)
			encodedFunctionArguments.push(
				String(
					web3Instance.eth.abi.encodeParameters(
						['address[]', 'uint256[]'],
						batchTransferDataForBatchContractTwo
					)
				)
			)
			encodedFunctionArguments.push(
				String(
					web3Instance.eth.abi.encodeParameters(
						['address[]', 'uint256[]'],
						batchTransferDataForBatchContractThree
					)
				)
			)
			/**
			 * @description Web3 Function Call
			 * @function manyToManyBatchTransfer
			 * @param batchList[]
			 * @param addressList[]
			 * @param amount[]
			 */

			await pccManagerV2
				.connect(owner)
				.manyToManyBatchTransfer(
					batchList,
					[
						projectDev1.address,
						projectDev2.address,
						projectDev3.address,
					],
					encodedFunctionArguments
				)

			/**
			 * @description Fetching Balance Of User Address Before Transfer
			 * @function balanceOf
			 * @param add1
			 */
			const balanceOfAdd1ForBatch1 = await pccManagerV2.balanceOf(
				add1.address,
				1
			)
			const balanceOfAdd1ForBatch2 = await pccManagerV2.balanceOf(
				add1.address,
				2
			)
			const balanceOfAdd1ForBatch3 = await pccManagerV2.balanceOf(
				add1.address,
				3
			)
			balanceOfAdd1AfterTransfer.push(
				String(balanceOfAdd1ForBatch1),
				String(balanceOfAdd1ForBatch2),
				String(balanceOfAdd1ForBatch3)
			)

			const balanceOfAdd2ForBatch1 = await pccManagerV2.balanceOf(
				add2.address,
				1
			)
			const balanceOfAdd2ForBatch2 = await pccManagerV2.balanceOf(
				add2.address,
				2
			)
			const balanceOfAdd2ForBatch3 = await pccManagerV2.balanceOf(
				add2.address,
				3
			)
			balanceOfAdd2AfterTransfer.push(
				String(balanceOfAdd2ForBatch1),
				String(balanceOfAdd2ForBatch2),
				String(balanceOfAdd2ForBatch3)
			)
		})

		/**
		 * @description Case: Check For Uneven Function Argument Length
		 */
		it('Should fail If uneven args length', async () => {
			await expect(
				pccManagerV2
					.connect(owner)
					.manyToManyBatchTransfer(
						[batchList[0], batchList[1], batchList[2]],
						[projectDev1.address],
						encodedFunctionArguments
					)
			).to.be.revertedWith('UNEVEN_ARGUMENTS_PASSED')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should perform many-to-many transfer of PCC successfully', async () => {
			expect(balanceOfAdd1AfterTransfer).to.eql(['10', '20', '30'])
			expect(balanceOfAdd2AfterTransfer).to.eql(['10', '20', '30'])
		})
	})

	/**
	 * @description Update Batch Delivery Year
	 */
	describe('Updating Batch Delivery Year', async () => {
		let batchList
		let batchDetailAfterUpdate
		let deliveryYearAfterUpdate

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
		before('web3 call to updateBatchDeliveryYear', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)

			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInABatch
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)

			/**
			 * @description Updating Batch's Delivery Year
			 * @function updateBatchDeliveryYear
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 * @param updatedDeliveryYear
			 */
			await pccManagerV2.updateBatchDeliveryYear(1, 1, batchList[0], 2025)

			/**
			 * @description Getting Batch Details After Update
			 * @function getBatchDetails
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 */
			batchDetailAfterUpdate = await pccManagerV2.getBatchDetails(
				1,
				1,
				batchList[0]
			)
			deliveryYearAfterUpdate = batchDetailAfterUpdate[6]
		})

		/**
		 * @description Case: Check For ProjectId
		 */
		it('Should fail If projectId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(0, 1, batchList[0], 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For CommodityId
		 */
		it('Should fail If commodityId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(1, 0, batchList[0], 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For BatchId
		 */
		it('Should fail If batchId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(1, 1, ZERO_ADDRESS, 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should update delivery year successfully', async () => {
			expect(deliveryYearAfterUpdate).to.equal(2025)
		})
	})

	/**
	 * @description Update Batch Delivery Estimate
	 */
	describe('Updating Batch Delivery Estimate', async () => {
		let batchList
		let batchDetailAfterUpdate
		let deliveryEstimateAfterUpdate

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
		before('web3 call to updateBatchDeliveryYear', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)

			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInABatch
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)

			/**
			 * @description Updating Batch's Delivery Year
			 * @function updateBatchDeliveryYear
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 * @param updatedDeliveryYear
			 */
			await pccManagerV2.updateBatchDeliveryEstimate(
				1,
				1,
				batchList[0],
				'Q1-Q3'
			)

			/**
			 * @description Getting Batch Details After Update
			 * @function getBatchDetails
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 */
			batchDetailAfterUpdate = await pccManagerV2.getBatchDetails(
				1,
				1,
				batchList[0]
			)
			deliveryEstimateAfterUpdate = batchDetailAfterUpdate[2]
		})

		/**
		 * @description Case: Check For ProjectId
		 */
		it('Should fail If projectId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(0, 1, batchList[0], 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For CommodityId
		 */
		it('Should fail If commodityId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(1, 0, batchList[0], 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For BatchId
		 */
		it('Should fail If batchId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryYear(1, 1, ZERO_ADDRESS, 2025)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should update delivery estimate successfully', async () => {
			expect(deliveryEstimateAfterUpdate).to.equal('Q1-Q3')
		})
	})

	/**
	 * @description Update Batch URI
	 */
	describe('Updating Batch URI', async () => {
		let batchList
		let batchDetailAfterUpdate
		let batchURIAfterUpdate

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
		before('web3 call to updateBatchURI', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)

			/**
			 * @description Geting List Of Batches w.r.t ProjectId & CommodityId
			 * @function getBatchListForACommodityInABatch
			 * @param projectId
			 * @param commodityId
			 */
			batchList = await pccManagerV2.getBatchListForACommodityInAProject(
				1,
				1
			)

			/**
			 * @description Updating Batch's Delivery Estimate
			 * @function updateBatchURI
			 * @param projectId
			 * @param commodityId
			 * @param batchId
			 * @param updatedBatchURI
			 */
			await pccManagerV2.updateBatchURI(
				1,
				1,
				batchList[0],
				'https://project-1.com/updatedSlug'
			)
			batchDetailAfterUpdate = await pccManagerV2.getBatchDetails(
				1,
				1,
				batchList[0]
			)
			batchURIAfterUpdate = batchDetailAfterUpdate[3]
		})

		/**
		 * @description Case: Check For ProjectId
		 */
		it('Should fail If projectId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryEstimate(
					0,
					1,
					batchList[0],
					'https://project-1.com/updatedSlug'
				)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For CommodityId
		 */
		it('Should fail If commodityId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryEstimate(
					1,
					0,
					batchList[0],
					'https://project-1.com/updatedSlug'
				)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For BatchId
		 */
		it('Should fail If batchId is zero', async () => {
			await expect(
				pccManagerV2.updateBatchDeliveryEstimate(
					1,
					1,
					ZERO_ADDRESS,
					'https://project-1.com/updatedSlug'
				)
			).to.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should update batch URI successfully', async () => {
			expect(String(batchURIAfterUpdate)).to.equal(
				'https://project-1.com/updatedSlug'
			)
		})
	})

	/**
	 * @description Fetch List Of Projects
	 */
	describe('Fetch Project List', async () => {
		let projectListLength = 0
		let projectList

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
		before('web3 call to getProjectList', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)
			projectListLength += 1
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					15,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/2'
				)
			projectListLength += 1

			/**
			 * @description Fetch Project List
			 * @function getProjectList
			 */
			projectList = await pccManagerV2.getProjectList()
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should fetch project list successfully', async () => {
			expect(projectList.length).to.be.equal(projectListLength)
		})
	})

	/**
	 * @description Fetch List Of Commodities w.r.t ProjectId
	 */
	describe('Fetch Commodity List', async () => {
		let commodityList

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
		before('web3 call to getCommodityListForAProject', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					13,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/2'
				)

			/**
			 * @description Fetch List Of Commodities
			 * @function getCommodityListForAProject
			 * @param projectId
			 */
			commodityList = await pccManagerV2.getCommodityListForAProject(1)
		})

		/**
		 * @description Case: Successful Call To Web2 Function
		 */
		it('Should fetch commodity list successfully', async () => {
			expect(commodityList.length).to.be.equal(2)
		})
	})

	/**
	 * @description Fetch Total Supply For Project-Commodity Pair
	 */
	describe('Fetch Project-Commodity Total Supply', async () => {
		let currentSupply

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
		before('web3 call to getCommodityListForAProject', async () => {
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					1,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/1'
				)
			await pccManagerV2
				.connect(owner)
				.createNewBatch(
					1,
					2,
					owner.address,
					1000,
					2024,
					'Quarter-3',
					'https://project-1.com/2'
				)

			/**
			 * @description Fetch Total Supply For Project-Commodity Pair
			 * @function getProjectCommodityTotalSupply
			 * @param projectId
			 */
			currentSupply = await pccManagerV2.getProjectCommodityTotalSupply(
				1,
				1
			)
		})

		/**
		 * @description Case: Successful Call To Web2 Function
		 */
		it('Should total supply successfully', async () => {
			expect(String(currentSupply)).to.equal('1000')
		})
	})
})
