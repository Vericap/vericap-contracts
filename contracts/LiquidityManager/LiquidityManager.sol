// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @title Vericap: LiquidityManager smart contract
 * @author Vericap Blockchain Engineering Team
 * @notice This Contract Is Used For Managing Liquidity For Pre-PDD
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../interfaces/ILiquidityToken.sol";
import "../helper/BasicMetaTransaction.sol";
import "hardhat/console.sol";

error RELEASE_LIQUIDITY_POOL_ALREADY_EXIST();
error RELEASE_LIQUIDITY_POOL_NOT_EXIST();
error GOAL_AMOUNT_TO_RAISE_REACHED();
error GOAL_AMOUNT_TO_RAISE_NOT_REACHED();
error IVESTMENT_AMOUNT_EXCEED_AMOUNT_TO_RAISE();
error BATCH_SUPPLY_IS_LOWER_THEN_INVESTOR_ALLOCATION();
error PROJECT_NOT_REACHED_POST_PDD_STAGE();
error PCC_NOT_YET_CREDITED_FOR_RELEASE();

contract LiquidityManager is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC1155HolderUpgradeable,
    AccessControlUpgradeable,
    BasicMetaTransaction
{
    using StringsUpgradeable for uint256;
    using SafeERC20 for IERC20;

    IERC1155Upgradeable public PCCTokenContract;

    /**
        @notice Declaring access based roles
     */
    bytes32 public constant EVX_LIQUIDITY_MANAGER_ROLE =
        keccak256("EVX_LIQUIDITY_MANAGER_ROLE");

    /**
     * @notice Investor Detail
     */
    struct InvestorDetail {
        address investorAddress;
        uint256 totalInvestment;
        // ReleaseType => Bool (Claimed or not)
        mapping(string => bool) pccClaimedForRelease;
        // ReleaseType => User's Percentage
        mapping(string => uint256) releaseBasedLPTokenAllocation;
        // ReleaseType => LPToken
        mapping(string => ILiquidityToken) LPTokenBasedOnRelease;
    }

    /**
     * @notice Release Detail
     */
    struct ReleaseDetail {
        uint256 categoryId;
        uint256 commodityId;
        uint256 goalAmountToRaise;
        uint256 totalAmountRaised;
        uint256 amountOfPCCRealised;
        uint256[] batchIdList;
        string releaseType;
        bool goalAmountReached;
        bool existence;
        bool PCCCredited;
        bool PCCRealised;
        ILiquidityToken lpTokenContractAddress;
    }

    /**
     * @notice Investor Address => Investor Detail
     */
    mapping(address => InvestorDetail) public investorDetails;

    /**
     * @notice Project Id => Commodity Id => Release Type => Release Detail
     */
    mapping(uint256 => mapping(uint256 => mapping(string => ReleaseDetail)))
        public releaseDetails;

    /**
     * @notice ReleaseLiquidityPoolCreated: Event
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param amountToRaise Amount To Raise
     */
    event ReleaseLiquidityPoolCreated(
        uint256 categoryId,
        uint256 commodityId,
        uint256 amountToRaise,
        string releaseType
    );

    /**
     * @notice LiquidityAddedToReleasePool: Event
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param investmentAmount Investment Amount
     * @param totalAmountRaised Total Amount Raised
     * @param investorAddress Investor Address
     */
    event LiquidityAddedToReleasePool(
        uint256 categoryId,
        uint256 commodityId,
        uint256 investmentAmount,
        uint256 totalAmountRaised,
        uint256 investorAllocation,
        string releaseType,
        address investorAddress
    );

    /**
     * @notice LiquidityRemovedFromReleasePool: Event
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param amountOfLiquidityRemoved Amount Of Liquidity Removed
     * @param investorAddress Investor Address
     */
    event LiquidityRemovedFromReleasePool(
        uint256 categoryId,
        uint256 commodityId,
        uint256 amountOfLiquidityRemoved,
        string releaseType,
        address investorAddress
    );

    /**
     * @notice NewPCCBatchAddedToRelease
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param batchIds Batch Ids
     * @param batchSupply Batch Supply
     */
    event NewPCCBatchAddedToRelease(
        uint256 categoryId,
        uint256 commodityId,
        string releaseType,
        uint256[] batchIds,
        uint256[] batchSupply
    );

    event PCCRedemptionForReleaseEnabledOrDisabled(
        uint256 categoryId,
        uint256 commodityId,
        string releaseType,
        bool pccRedemptionEnabled
    );

    event GoalAmountUpdatedForRelease(
        uint256 categoryId,
        uint256 commodityId,
        string releaseType,
        uint256 currentGoalAmount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
        @notice Initialize: Initialize a smart contract
        @dev Works as a constructor for proxy contracts
        @param superAdmin Admin wallet address
        @param pccTokenContract PCC token contract address
     */
    function initialize(
        address superAdmin,
        IERC1155Upgradeable pccTokenContract
    ) external initializer {
        __Ownable_init();
        _setRoleAdmin(EVX_LIQUIDITY_MANAGER_ROLE, EVX_LIQUIDITY_MANAGER_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _setupRole(EVX_LIQUIDITY_MANAGER_ROLE, superAdmin);
        PCCTokenContract = pccTokenContract;
    }

    /** 
        @notice UUPS upgrade mandatory function: To authorize the owner to upgrade 
                the contract
    */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @notice getReleaseDetail: Get Release Detail
     * @param categoryId Project Id
     * @param commodityId  Commodity Id
     * @param releaseType Release Type
     */
    function getReleaseDetail(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType
    ) public view returns (ReleaseDetail memory) {
        return releaseDetails[categoryId][commodityId][releaseType];
    }

    /**
     * @notice getUserStakeInRelease: Get User's Stake In Release
     * @param investorAddress Investor Address
     * @param releaseType Release Type
     */
    function getInvestorDetailForRelease(
        address investorAddress,
        string memory releaseType
    ) public view returns (address, uint256) {
        ILiquidityToken lpToken = investorDetails[investorAddress]
            .LPTokenBasedOnRelease[releaseType];
        return (
            address(lpToken),
            investorDetails[investorAddress].releaseBasedLPTokenAllocation[
                releaseType
            ]
        );
    }

    /** @notice createReleasePool: Create Release Pool
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType  Release Type
     * @param goalAmountToRaise Amount To Raise
     */
    function createReleaseLiquidityPool(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        uint256 goalAmountToRaise
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        _checkBeforeForArguments(categoryId, commodityId, releaseType);
        if (releaseDetails[categoryId][commodityId][releaseType].existence) {
            revert RELEASE_LIQUIDITY_POOL_ALREADY_EXIST();
        }

        LiquidityToken lpToken = new LiquidityToken(
            string(
                abi.encodePacked(
                    "EVXLP-",
                    categoryId.toString(),
                    "-",
                    commodityId.toString(),
                    "-",
                    releaseType
                )
            ),
            string(abi.encodePacked("EVXLP-", releaseType)),
            address(this)
        );

        uint256[] memory _batchIdList;
        releaseDetails[categoryId][commodityId][releaseType] = ReleaseDetail(
            categoryId,
            commodityId,
            goalAmountToRaise,
            0,
            0,
            _batchIdList,
            releaseType,
            false,
            true,
            false,
            false,
            lpToken
        );

        emit ReleaseLiquidityPoolCreated(
            categoryId,
            commodityId,
            goalAmountToRaise,
            releaseType
        );
    }

    /**
     * @notice addLiquidityToReleasePool: Add Liquidity To Release Pool
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param investmentAmount Investment Amount
     * @param investorAddress Investor Address
     */
    function addLiquidityToReleasePool(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        uint256 investmentAmount,
        uint256 investmentRate,
        address investorAddress
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        _checkBeforeForArguments(categoryId, commodityId, releaseType);

        if (!releaseDetails[categoryId][commodityId][releaseType].existence) {
            revert RELEASE_LIQUIDITY_POOL_NOT_EXIST();
        }

        ReleaseDetail storage _releaseDetail = releaseDetails[categoryId][
            commodityId
        ][releaseType];

        InvestorDetail storage _investorDetail = investorDetails[
            investorAddress
        ];

        if (_releaseDetail.goalAmountReached) {
            revert GOAL_AMOUNT_TO_RAISE_REACHED();
        } else if (
            _releaseDetail.goalAmountToRaise <
            (_releaseDetail.totalAmountRaised + investmentAmount)
        ) {
            revert IVESTMENT_AMOUNT_EXCEED_AMOUNT_TO_RAISE();
        }

        _releaseDetail.totalAmountRaised += investmentAmount;

        _investorDetail.totalInvestment += investmentAmount;

        if (
            _releaseDetail.totalAmountRaised == _releaseDetail.goalAmountToRaise
        ) {
            _releaseDetail.goalAmountReached = true;
        }

        uint256 _userCurrentAllocation = _updateInvestorAllocation(
            _investorDetail,
            releaseType,
            investmentAmount,
            investmentRate,
            _releaseDetail,
            investorAddress
        );

        emit LiquidityAddedToReleasePool(
            categoryId,
            commodityId,
            investmentAmount,
            _userCurrentAllocation,
            _releaseDetail.totalAmountRaised,
            releaseType,
            investorAddress
        );
    }

    /**
     * @notice removeLiquidityAndClaimPCCToken: Deposit LPs And Claim PCC Token
     * @dev Deposit LP Token And Claim PCC Tokens In Return
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param investorAddress Investor Address
     */
    function removeLiquidityAndClaimPCCToken(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        address investorAddress
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        _checkBeforeForArguments(categoryId, commodityId, releaseType);

        ReleaseDetail memory _releaseDetail = releaseDetails[categoryId][
            commodityId
        ][releaseType];
        InvestorDetail storage _investorDetail = investorDetails[
            investorAddress
        ];
        ILiquidityToken lpToken = _releaseDetail.lpTokenContractAddress;

        if (
            _releaseDetail.goalAmountToRaise > _releaseDetail.totalAmountRaised
        ) {
            revert GOAL_AMOUNT_TO_RAISE_NOT_REACHED();
        }

        if (!releaseDetails[categoryId][commodityId][releaseType].PCCRealised) {
            revert PROJECT_NOT_REACHED_POST_PDD_STAGE();
        }

        uint256 _investorPoolPercentage = _investorDetail
            .releaseBasedLPTokenAllocation[releaseType];

        uint256 _pccRealised = releaseDetails[categoryId][commodityId][
            releaseType
        ].amountOfPCCRealised;

        uint256 lpSupply = lpToken.totalSupply();
        uint256 _claimablePCC = (_pccRealised / lpSupply) *
            _investorPoolPercentage;

        IERC20(address(lpToken)).safeTransferFrom(
            investorAddress,
            address(this),
            _investorPoolPercentage
        );

        emit IERC20.Transfer(
            investorAddress,
            address(this),
            _investorPoolPercentage
        );

        lpToken.burn(address(this), _investorPoolPercentage);

        emit IERC20.Transfer(
            address(this),
            address(0),
            _investorPoolPercentage
        );

        uint256 _batchIdListLength = _releaseDetail.batchIdList.length;
        if (
            _checkForBatchSupply(categoryId, commodityId, releaseType) <
            _investorPoolPercentage
        ) {
            revert BATCH_SUPPLY_IS_LOWER_THEN_INVESTOR_ALLOCATION();
        }

        _transferClaimablePCC(
            categoryId,
            commodityId,
            releaseType,
            _batchIdListLength,
            _claimablePCC,
            investorAddress
        );

        emit LiquidityRemovedFromReleasePool(
            categoryId,
            commodityId,
            _claimablePCC,
            releaseType,
            investorAddress
        );
    }

    /**
     * @notice addPCCBatchToRelease: Add PCC Batch To Release
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     * @param projectDeveloperAddress Project Developer Address
     * @param batchIds Batch Ids
     * @param amountToTransfer Amount To Transfer
     */
    function addPCCBatchToRelease(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        address projectDeveloperAddress,
        uint256[] memory batchIds,
        uint256[] memory amountToTransfer
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        require(
            (batchIds.length != 0) &&
                (batchIds.length == amountToTransfer.length),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        ReleaseDetail storage _releaseDetail = releaseDetails[categoryId][
            commodityId
        ][releaseType];
        for (uint i = 0; i < batchIds.length; ++i) {
            _releaseDetail.batchIdList.push(batchIds[i]);
        }
        _releaseDetail.PCCCredited = true;

        uint256 _pccRealised;
        for (uint256 i = 0; i < batchIds.length; ++i) {
            _pccRealised += amountToTransfer[i];
        }
        releaseDetails[categoryId][commodityId][releaseType]
            .amountOfPCCRealised += _pccRealised;

        PCCTokenContract.safeBatchTransferFrom(
            projectDeveloperAddress,
            address(this),
            batchIds,
            amountToTransfer,
            "0x00"
        );

        emit NewPCCBatchAddedToRelease(
            categoryId,
            commodityId,
            releaseType,
            batchIds,
            amountToTransfer
        );
    }

    /**
     * @notice enablePCCRedemptionForRelease: Enable PCC Redemption For Release
     * @param categoryId Project Id
     * @param commodityId Commodity Id
     * @param releaseType Release Type
     */
    function enableDisablePCCRedemptionForRelease(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        bool redemptionState
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        if (!releaseDetails[categoryId][commodityId][releaseType].PCCCredited) {
            revert PCC_NOT_YET_CREDITED_FOR_RELEASE();
        }
        releaseDetails[categoryId][commodityId][releaseType]
            .PCCRealised = redemptionState;

        emit PCCRedemptionForReleaseEnabledOrDisabled(
            categoryId,
            commodityId,
            releaseType,
            redemptionState
        );
    }

    function updateTotalSupplyOfRelease(
        uint256 categoryId,
        uint256 commodityId,
        string memory releaseType,
        uint256 amountToAdd
    ) external onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        releaseDetails[categoryId][commodityId][releaseType]
            .goalAmountToRaise += amountToAdd;
        emit GoalAmountUpdatedForRelease(
            categoryId,
            commodityId,
            releaseType,
            releaseDetails[categoryId][commodityId][releaseType]
                .goalAmountToRaise
        );
    }

    /**
     * _updateInvestorAllocation: Update Investor Allocation
     * @param _investorDetail Investor Detail
     * @param _releaseType Release Type
     * @param _investmentAmount Investment Amount
     * @param _releaseDetail Release Detail
     * @param _investorAddress Investor Address
     */
    function _updateInvestorAllocation(
        InvestorDetail storage _investorDetail,
        string memory _releaseType,
        uint256 _investmentAmount,
        uint256 _investmentRate,
        ReleaseDetail memory _releaseDetail,
        address _investorAddress
    ) internal onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) returns (uint256) {
        ILiquidityToken lpToken = _releaseDetail.lpTokenContractAddress;
        _investorDetail.totalInvestment += _investmentAmount;

        uint256 _allocation = ((_investmentAmount * 10_000) /
            _releaseDetail.goalAmountToRaise) * _investmentRate;

        uint256 _allocationFloor = ((_allocation * (10 ** 2)) / (10 ** 2));
        uint256 _userCurrentAllocation = (_allocationFloor / 100);

        _investorDetail.releaseBasedLPTokenAllocation[
                _releaseType
            ] += _userCurrentAllocation;

        lpToken.mint(_investorAddress, _userCurrentAllocation);

        emit IERC20.Transfer(
            address(0),
            _investorAddress,
            _userCurrentAllocation
        );

        return _userCurrentAllocation;
    }

    /**
     * @notice _transferClaimablePCC: Internal Fn To Transfer Claimable PCC To Investor
     * @param _categoryId Project Id
     * @param _commodityId Commodity Id
     * @param _releaseType Release Type
     * @param _batchIdListLength Length Of Batch Ids List
     * @param _claimablePCC Amount Of PCCs Available To Claim
     * @param _investorAddress Investor Address
     */
    function _transferClaimablePCC(
        uint256 _categoryId,
        uint256 _commodityId,
        string memory _releaseType,
        uint256 _batchIdListLength,
        uint256 _claimablePCC,
        address _investorAddress
    ) internal onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        require(
            !investorDetails[_investorAddress].pccClaimedForRelease[
                _releaseType
            ],
            "PCC_ALREADY_CLAIMED"
        );
        for (uint i = 0; i < _batchIdListLength; ++i) {
            uint256 _currentBatchId = releaseDetails[_categoryId][_commodityId][
                _releaseType
            ].batchIdList[i];

            uint256 _currentBatchSupply = PCCTokenContract.balanceOf(
                address(this),
                _currentBatchId
            );
            if (_claimablePCC >= _currentBatchSupply) {
                PCCTokenContract.safeTransferFrom(
                    address(this),
                    _investorAddress,
                    _currentBatchId,
                    _currentBatchSupply,
                    "0x00"
                );
                _claimablePCC = _claimablePCC - _currentBatchSupply;
            } else if (_claimablePCC <= _currentBatchSupply) {
                PCCTokenContract.safeTransferFrom(
                    address(this),
                    _investorAddress,
                    _currentBatchId,
                    _claimablePCC,
                    "0x00"
                );

                _claimablePCC = 0;
            }

            if (_claimablePCC == 0) {
                investorDetails[_investorAddress].pccClaimedForRelease[
                    _releaseType
                ] = true;
            }

            emit IERC1155Upgradeable.TransferSingle(
                msg.sender,
                address(this),
                _investorAddress,
                _currentBatchId,
                _claimablePCC
            );
        }
    }

    /**
     * @notice _checkForBatchSupply: Internal Fn To Check Batch's PCC Supply
     * @param _categoryId Project Id
     * @param _commodityId Commodity Id
     * @param _releaseType Release Type
     */
    function _checkForBatchSupply(
        uint256 _categoryId,
        uint256 _commodityId,
        string memory _releaseType
    ) internal view returns (uint256) {
        uint256 _batchIdListLength = releaseDetails[_categoryId][_commodityId][
            _releaseType
        ].batchIdList.length;
        uint256 _sumOfBatchSupply;
        for (uint256 i = 0; i < _batchIdListLength; ++i) {
            _sumOfBatchSupply += PCCTokenContract.balanceOf(
                address(this),
                releaseDetails[_categoryId][_commodityId][_releaseType]
                    .batchIdList[i]
            );
        }

        return _sumOfBatchSupply;
    }

    /**
     * @notice _checkBeforeCreateReleasePool: Checks Before Creating New Release
     * @dev Checking credibilty of arguments
     * @param _categoryId Project Id
     * @param _commodityId Commodity Id
     * @param _releaseType Release Type
     */
    function _checkBeforeForArguments(
        uint256 _categoryId,
        uint256 _commodityId,
        string memory _releaseType
    ) internal pure {
        require(
            _categoryId != 0 &&
                _commodityId != 0 &&
                bytes(_releaseType).length != 0,
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
     * @dev Necessary function inheritance for ERC1155Supply
     * @param interfaceId Interface Id of the contract
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
        @dev function to override _msgsender() for BMT
     */
    function _msgSender() internal view virtual override returns (address) {
        return msgSender();
    }
}

contract LiquidityToken is ILiquidityToken, ERC20, AccessControl {
    bytes32 public constant EVX_LIQUIDITY_MANAGER_ROLE =
        keccak256("EVX_LIQUIDITY_MANAGER_ROLE");

    /**
     * @notice Standard ERC20 Constructor
     * @param _LPTokenName LP Token Name
     * @param _LPTokenSymbol LP Token Symbol
     * @param _superAdmin Super Admin Address
     */
    constructor(
        string memory _LPTokenName,
        string memory _LPTokenSymbol,
        address _superAdmin
    ) ERC20(_LPTokenName, _LPTokenSymbol) {
        _setRoleAdmin(EVX_LIQUIDITY_MANAGER_ROLE, EVX_LIQUIDITY_MANAGER_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(EVX_LIQUIDITY_MANAGER_ROLE, _superAdmin);
    }

    /**
     * @notice decimals: Override Decimals To Default 0
     */
    function decimals() public pure override(ERC20) returns (uint8) {
        return 0;
    }

    /**
        @notice mint: Standard ERC20's mint
        @dev Using ERC20's internal _mint function
        @param account Account where tokens will get minted
        @param amount Amount of tokens to be minted        
     */
    function mint(
        address account,
        uint256 amount
    ) public onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        _mint(account, amount);
    }

    /**
        @notice burn: Standard ERC20's burn
        @dev Using ERC20's internal _mint function
        @param account Account from where tokens will get burned from
        @param amount Amount of tokens to be burned
     */
    function burn(
        address account,
        uint256 amount
    ) public onlyRole(EVX_LIQUIDITY_MANAGER_ROLE) {
        _burn(account, amount);
    }

    function totalSupply()
        public
        view
        override(ERC20, ILiquidityToken)
        returns (uint256)
    {}
}
