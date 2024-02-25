/**
 * @package Imports
 */
const fs = require('fs')
const { expect } = require('chai')
const { ethers, upgrades } = require('hardhat')
const { Web3 } = require('web3')
const LiquidityTokenABIPath =
	'artifacts/contracts/LiquidityManager/LiquidityManager.sol/LiquidityToken.json'
require('dotenv').config()

/**
 * @global Initializing Global Variables
 */
const fsPromises = fs.promises

/**
 * @global Parent Describe Test Block
 */
describe('PCC Manager V2 Smart Contract', () => {
	/**
	 * @public Block Scoped Variable Declaration
	 */
	let PCCManagerV2, pccManagerV2, owner

	let ZERO_ADDRESS = ethers.constants.AddressZero

	/**
	 * @global Triggers before each describe block
	 */
	before(async () => {
		;[
			owner,
			projectDev1,
			projectDev2,
			projectDev3,
			investor1,
			investor2,
			investor3,
			investor4,
		] = await ethers.getSigners()

		PCCManagerV2 = await hre.ethers.getContractFactory('PCCManagerV2')
		pccManagerV2 = await upgrades.deployProxy(
			PCCManagerV2,
			[owner.address],
			{ kind: 'uups' }
		)
		await pccManagerV2.deployed()

		LiquidityManager = await hre.ethers.getContractFactory(
			'LiquidityManager'
		)
		liquidityManager = await upgrades.deployProxy(
			LiquidityManager,
			[owner.address, pccManagerV2.address],
			{ kind: 'uups' }
		)
		await liquidityManager.deployed()
	})

	/**
	 * @description Creat A New PCC Batch
	 */
	describe('Create A New Batch', async () => {
		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should Successfully Create New PCC Batch', async () => {
			const createNewBatchForDev1 = await pccManagerV2
				.connect(owner)
				.createNewBatch(
					345765,
					1,
					projectDev1.address,
					800,
					2025,
					'Q1-Q2',
					'https://project-1.com/1'
				)

			await expect(createNewBatchForDev1).to.emit(
				pccManagerV2,
				'NewBatchCreated'
			)

			const createNewBatchForDev2 = await pccManagerV2
				.connect(owner)
				.createNewBatch(
					987456,
					1,
					projectDev2.address,
					400,
					2045,
					'Q3-Q4',
					'https://project-2.com/2'
				)

			expect(createNewBatchForDev2)
				.to.emit(pccManagerV2, 'mintNewBatch')
				.withArgs(
					987456,
					1,
					projectDev2.address,
					400,
					2045,
					'Q3-Q4',
					'https://project-2.com/2'
				)
		})
	})

	/**
	 * @description Create A New Release Based Liquidity Pool
	 */
	describe('Create Release Liquidity Pool', async () => {
		/**
		 * @description Case: Check For Category Id
		 */
		it('Should Fail If Category Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.createReleaseLiquidityPool(0, 1, 'FIRST', 500)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should Fail If Commodity Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.createReleaseLiquidityPool(8899, 0, 'FIRST', 500)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Release Type
		 */
		it('Should Fail If Release Type Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.createReleaseLiquidityPool(8899, 1, '', 500)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should Successfully Create New Release Liquidity Pool', async () => {
			const createPool = await liquidityManager
				.connect(owner)
				.createReleaseLiquidityPool(8899, 1, 'FIRST', 500)

			await expect(createPool)
				.to.emit(liquidityManager, 'ReleaseLiquidityPoolCreated')
				.withArgs(8899, 1, 500, 'FIRST')
		})

		/**
		 * @description Case: Check For Duplicate Release Type
		 */
		it('Should Fail If Release Liquidity Pool Already Exist', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.createReleaseLiquidityPool(8899, 1, 'FIRST', 500)
			).to.be.revertedWith('RELEASE_LIQUIDITY_POOL_ALREADY_EXIST()')
		})
	})

	/**
	 * @description Add Liquidity To A Release Pool
	 */
	describe('Add Liquidity To Release Pool', async () => {
		/**
		 * @description Case: Check For Category Id
		 */
		it('Should Fail If Category Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						0,
						1,
						'FIRST',
						100,
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should Fail If Commodity Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						8899,
						0,
						'FIRST',
						100,
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Release Type
		 */
		it('Should Fail If Release Type Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						8899,
						1,
						'',
						100,
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Release Liquidity Pool Existance
		 */
		it('Should fail If Release Liquidity Pool Does Not Exist', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						8899,
						1,
						'SECOND',
						100,
						investor1.address
					)
			).to.be.revertedWith('RELEASE_LIQUIDITY_POOL_NOT_EXIST()')
		})

		/**
		 * @description Case: Successful Call To Web3 Function
		 */
		it('Should Successfully Add Liquidity To Release Pool', async () => {
			const addLiquidityForInvestorOne = await liquidityManager
				.connect(owner)
				.addLiquidityToReleasePool(
					8899,
					1,
					'FIRST',
					100,
					investor1.address
				)

			const releaseDetailAfterFirstInvestment =
				await liquidityManager.getReleaseDetail(8899, 1, 'FIRST')

			const investorOneDetail =
				await liquidityManager.getInvestorDetailForRelease(
					investor1.address,
					'FIRST'
				)

			await expect(addLiquidityForInvestorOne)
				.to.emit(liquidityManager, 'LiquidityAddedToReleasePool')
				.withArgs(
					8899,
					1,
					100,
					parseInt(investorOneDetail[1]),
					releaseDetailAfterFirstInvestment['totalAmountRaised'],
					'FIRST',
					investor1.address
				)

			await expect(addLiquidityForInvestorOne)
				.to.emit(liquidityManager, 'Transfer')
				.withArgs(
					ZERO_ADDRESS,
					investor1.address,
					parseInt(investorOneDetail[1])
				)

			const addLiquidityForInvestorTwo = await liquidityManager
				.connect(owner)
				.addLiquidityToReleasePool(
					8899,
					1,
					'FIRST',
					300,
					investor2.address
				)

			const investorTwoDetail =
				await liquidityManager.getInvestorDetailForRelease(
					investor2.address,
					'FIRST'
				)

			const releaseDetailAfterSecondInvestment =
				await liquidityManager.getReleaseDetail(8899, 1, 'FIRST')

			await expect(addLiquidityForInvestorTwo)
				.to.emit(liquidityManager, 'LiquidityAddedToReleasePool')
				.withArgs(
					8899,
					1,
					300,
					parseInt(investorTwoDetail[1]),
					releaseDetailAfterSecondInvestment['totalAmountRaised'],
					'FIRST',
					investor2.address
				)

			await expect(addLiquidityForInvestorTwo)
				.to.emit(liquidityManager, 'Transfer')
				.withArgs(
					ZERO_ADDRESS,
					investor2.address,
					parseInt(investorTwoDetail[1])
				)
		})

		/**
		 * @description Case: Check If Investment Exceed Amount To Raise
		 */
		it('Should Fail If Investment Amount Exceeds Amount To Raise', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						8899,
						1,
						'FIRST',
						2500,
						investor3.address
					)
			).to.be.revertedWith('IVESTMENT_AMOUNT_EXCEED_AMOUNT_TO_RAISE()')
		})

		/**
		 * @description Case: Successful Investment For reaching Goal Amount
		 */
		it('Should Successfully Invest The Remaining Goal Amount', async () => {
			const addLiquidityForInvestorThree = await liquidityManager
				.connect(owner)
				.addLiquidityToReleasePool(
					8899,
					1,
					'FIRST',
					100,
					investor3.address
				)

			const releaseDetail = await liquidityManager.getReleaseDetail(
				8899,
				1,
				'FIRST'
			)

			const investorThreeDetail =
				await liquidityManager.getInvestorDetailForRelease(
					investor3.address,
					'FIRST'
				)

			await expect(addLiquidityForInvestorThree)
				.to.emit(liquidityManager, 'LiquidityAddedToReleasePool')
				.withArgs(
					8899,
					1,
					100,
					parseInt(investorThreeDetail[1]),
					releaseDetail['totalAmountRaised'],
					'FIRST',
					investor3.address
				)
		})

		/**
		 * @description Case: Check If Goal Amount Reached
		 */
		it('Should Fail If Goal Amount Reached', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addLiquidityToReleasePool(
						8899,
						1,
						'FIRST',
						100,
						investor3.address
					)
			).to.be.revertedWith('GOAL_AMOUNT_TO_RAISE_REACHED()')
		})
	})

	/**
	 * @description Add PCC Batches To LP Manager
	 */
	describe('Add PCC Batches To LP Manager', async () => {
		/**
		 * @description Case: Approve LP Manager To Access Developer's PCC
		 */
		it('Should Successfully Approve LP Manager And EVX Owner To Access Developers PCC', async () => {
			const approveLPManagerForDev1 = await pccManagerV2
				.connect(projectDev1)
				.setApprovalForAll(liquidityManager.address, true)

			const approveLPManagerForDev2 = await pccManagerV2
				.connect(projectDev2)
				.setApprovalForAll(liquidityManager.address, true)

			const approveEVXOwnerForDev1 = await pccManagerV2
				.connect(projectDev1)
				.setApprovalForAll(owner.address, true)

			const approveEVXOwnerForDev2 = await pccManagerV2
				.connect(projectDev2)
				.setApprovalForAll(owner.address, true)

			expect(approveLPManagerForDev1)
				.to.emit(liquidityManager, 'ApprovalForAll')
				.withArgs(projectDev1, liquidityManager.address, true)

			expect(approveLPManagerForDev2)
				.to.emit(liquidityManager, 'ApprovalForAll')
				.withArgs(projectDev2, liquidityManager.address, true)

			expect(approveEVXOwnerForDev1)
				.to.emit(liquidityManager, 'ApprovalForAll')
				.withArgs(projectDev1, owner.address, true)

			expect(approveEVXOwnerForDev2)
				.to.emit(liquidityManager, 'ApprovalForAll')
				.withArgs(projectDev2, owner.address, true)
		})

		it('Should Fail If Batch Ids And Amount To Transfer Is Uneven', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.addPCCBatchToRelease(
						8899,
						1,
						'FIRST',
						projectDev1.address,
						[1, 2],
						[320]
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		it('Should Successfully Add PCC To LP Manager For This Category', async () => {
			const addBatchForDev1 = await liquidityManager
				.connect(owner)
				.addPCCBatchToRelease(
					8899,
					1,
					'FIRST',
					projectDev1.address,
					[1],
					[320]
				)

			const addBatchForDev2 = await liquidityManager
				.connect(owner)
				.addPCCBatchToRelease(
					8899,
					1,
					'FIRST',
					projectDev2.address,
					[2],
					[120]
				)

			await expect(addBatchForDev1)
				.to.emit(liquidityManager, 'NewPCCBatchAddedToRelease')
				.withArgs(8899, 1, 'FIRST', [1], [320])

			await expect(addBatchForDev2)
				.to.emit(liquidityManager, 'NewPCCBatchAddedToRelease')
				.withArgs(8899, 1, 'FIRST', [2], [120])
		})
	})

	/**
	 * @description Enable PCC Redemption For A Category
	 */
	describe('Enable Redemption Of PCC Token From LP Manager', async () => {
		/**
		 * @description Case: If PCCs Not Yet Added To LP Manager
		 */
		it('Should Fail If PCC Not Yet Added To LP Manager', async () => {
			await liquidityManager
				.connect(owner)
				.createReleaseLiquidityPool(4455, 1, 'SECOND', 500)

			expect(
				liquidityManager
					.connect(owner)
					.enableDisablePCCRedemptionForRelease(
						4455,
						1,
						'SECOND',
						true
					)
			).to.be.revertedWith('PCC_NOT_YET_CREDITED_FOR_RELEASE()')
		})

		/**
		 * @description Case: Successfully Enable Rdemption Of PCC
		 */
		it('Should Successfully Enable Redemption Of PCC Of Category', async () => {
			const enableResult = await liquidityManager
				.connect(owner)
				.enableDisablePCCRedemptionForRelease(8899, 1, 'FIRST', true)

			await expect(enableResult)
				.to.emit(
					liquidityManager,
					'PCCRedemptionForReleaseEnabledOrDisabled'
				)
				.withArgs(8899, 1, 'FIRST', true)
		})
	})

	/**
	 * @description Remove Liquidity And Claim PCC From A Category
	 */
	describe('Remove Liquidity And Claim PCC From A Category', async () => {
		/**
		 * @description Case: Check For Category Id
		 */
		it('Should Fail If Category Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.removeLiquidityAndClaimPCCToken(
						0,
						1,
						'FIRST',
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Commodity Id
		 */
		it('Should Fail If Commodity Id Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.removeLiquidityAndClaimPCCToken(
						8899,
						0,
						'FIRST',
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check For Release Type
		 */
		it('Should Fail If Release Type Is Zero', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.removeLiquidityAndClaimPCCToken(
						8899,
						1,
						'',
						investor1.address
					)
			).to.be.revertedWith('ARGUMENT_PASSED_AS_ZERO')
		})

		/**
		 * @description Case: Check If Goal Amount Not Reached
		 */
		it('Should Fail If Category Goal Amount Not Reached', async () => {
			expect(
				liquidityManager
					.connect(owner)
					.removeLiquidityAndClaimPCCToken(
						4455,
						1,
						'SECOND',
						investor1.address
					)
			).to.be.revertedWith('GOAL_AMOUNT_TO_RAISE_NOT_REACHED()')
		})

		/**
		 * @description Case: Check If Category Reached Post PDD Stage
		 */
		it('Should Fail If Category Not Reached Post PDD', async () => {
			await liquidityManager
				.connect(owner)
				.addLiquidityToReleasePool(
					4455,
					1,
					'SECOND',
					500,
					investor4.address
				)

			expect(
				liquidityManager
					.connect(owner)
					.removeLiquidityAndClaimPCCToken(
						4455,
						1,
						'SECOND',
						investor4.address
					)
			).to.be.revertedWith('PROJECT_NOT_REACHED_POST_PDD_STAGE()')
		})

		/**
		 * @notice This will never occur
		 * 			As If a investor holds 100% of a release
		 * 			Then he'll be getting 100% of the batch supply
		 * 			Just added this condition to check for any overflows
		 */
		// it('Should Fail If Batch Supply Is Lower Than Investor Allcation', async () => {

		// })

		/**
		 * @description Case: Approve LP Token Of Investor To LP Manager Contract
		 */
		it('Should Successfully Approve LP Token Of Investor One To LP Manager Contract', async () => {
			const releaseDetail = await liquidityManager.getReleaseDetail(
				8899,
				1,
				'FIRST'
			)
			const lpTokenAddress = releaseDetail['lpTokenContractAddress']
			/**
			 * @description Fetching LP Token Contract ABI
			 */
			let getLPTokenABI = async () => {
				const data = await fsPromises.readFile(
					LiquidityTokenABIPath,
					'utf-8'
				)
				const abi = JSON.parse(data)['abi']
				return abi
			}

			let lpTokenABI = await getLPTokenABI()

			let lpTokenContract = new ethers.Contract(
				lpTokenAddress,
				lpTokenABI,
				owner
			)

			const approveLPManagerStatus = await lpTokenContract
				.connect(investor1)
				.approve(liquidityManager.address, 10000000)

			const approveAdminStatus = await lpTokenContract
				.connect(investor1)
				.approve(owner.address, 10000000)

			await expect(approveLPManagerStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor1.address, liquidityManager.address, 10000000)

			await expect(approveAdminStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor1.address, owner.address, 10000000)
		})

		/**
		 * @description Case: Successful Redemption Of PCC
		 */
		it('Should Successfully Burn LP Tokens And Transfer PCC To Investor One', async () => {
			const pccClaimResult = await liquidityManager
				.connect(owner)
				.removeLiquidityAndClaimPCCToken(
					8899,
					1,
					'FIRST',
					investor1.address
				)

			const investorOneDetail =
				await liquidityManager.getInvestorDetailForRelease(
					investor1.address,
					'FIRST'
				)

			await expect(pccClaimResult)
				.to.emit(liquidityManager, 'LiquidityRemovedFromReleasePool')
				.withArgs(8899, 1, 88, 'FIRST', investor1.address)

			await expect(pccClaimResult).to.emit(
				liquidityManager,
				'TransferSingle'
			)
		})

		/**
		 * @description Case: Approve LP Token Of Investor To LP Manager Contract
		 */
		it('Should Successfully Approve LP Token Of Investor Two To LP Manager Contract', async () => {
			const releaseDetail = await liquidityManager.getReleaseDetail(
				8899,
				1,
				'FIRST'
			)
			const lpTokenAddress = releaseDetail['lpTokenContractAddress']
			/**
			 * @description Fetching LP Token Contract ABI
			 */
			let getLPTokenABI = async () => {
				const data = await fsPromises.readFile(
					LiquidityTokenABIPath,
					'utf-8'
				)
				const abi = JSON.parse(data)['abi']
				return abi
			}

			let lpTokenABI = await getLPTokenABI()

			let lpTokenContract = new ethers.Contract(
				lpTokenAddress,
				lpTokenABI,
				owner
			)

			const approveLPManagerStatus = await lpTokenContract
				.connect(investor2)
				.approve(liquidityManager.address, 10000000)

			const approveAdminStatus = await lpTokenContract
				.connect(investor2)
				.approve(owner.address, 10000000)

			await expect(approveLPManagerStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor2.address, liquidityManager.address, 10000000)

			await expect(approveAdminStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor2.address, owner.address, 10000000)
		})

		/**
		 * @description Case: Successful Redemption Of PCC
		 */
		it('Should Successfully Burn LP Tokens And Transfer PCC To Investor Two', async () => {
			const pccClaimResult = await liquidityManager
				.connect(owner)
				.removeLiquidityAndClaimPCCToken(
					8899,
					1,
					'FIRST',
					investor2.address
				)

			await expect(pccClaimResult)
				.to.emit(liquidityManager, 'LiquidityRemovedFromReleasePool')
				.withArgs(8899, 1, 264, 'FIRST', investor2.address)

			await expect(pccClaimResult).to.emit(
				liquidityManager,
				'TransferSingle'
			)
		})

		/**
		 * @description Case: Approve LP Token Of Investor To LP Manager Contract
		 */
		it('Should Successfully Approve LP Token Of Investor Three To LP Manager Contract', async () => {
			const releaseDetail = await liquidityManager.getReleaseDetail(
				8899,
				1,
				'FIRST'
			)
			const lpTokenAddress = releaseDetail['lpTokenContractAddress']
			/**
			 * @description Fetching LP Token Contract ABI
			 */
			let getLPTokenABI = async () => {
				const data = await fsPromises.readFile(
					LiquidityTokenABIPath,
					'utf-8'
				)
				const abi = JSON.parse(data)['abi']
				return abi
			}

			let lpTokenABI = await getLPTokenABI()

			let lpTokenContract = new ethers.Contract(
				lpTokenAddress,
				lpTokenABI,
				owner
			)

			const approveLPManagerStatus = await lpTokenContract
				.connect(investor3)
				.approve(liquidityManager.address, 10000000)

			const approveAdminStatus = await lpTokenContract
				.connect(investor3)
				.approve(owner.address, 10000000)

			await expect(approveLPManagerStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor3.address, liquidityManager.address, 10000000)

			await expect(approveAdminStatus)
				.to.emit(lpTokenContract, 'Approval')
				.withArgs(investor3.address, owner.address, 10000000)
		})

		/**
		 * @description Case: Successful Redemption Of PCC
		 */
		it('Should Successfully Burn LP Tokens And Transfer PCC To Investor Three', async () => {
			const pccClaimResult = await liquidityManager
				.connect(owner)
				.removeLiquidityAndClaimPCCToken(
					8899,
					1,
					'FIRST',
					investor3.address
				)

			await expect(pccClaimResult)
				.to.emit(liquidityManager, 'LiquidityRemovedFromReleasePool')
				.withArgs(8899, 1, 88, 'FIRST', investor3.address)

			await expect(pccClaimResult).to.emit(
				liquidityManager,
				'TransferSingle'
			)
		})
	})
})
