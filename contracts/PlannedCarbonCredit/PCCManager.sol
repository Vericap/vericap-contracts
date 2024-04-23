// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EnverX: PCCManager smart contract
 * @author EnverX Blockchain Engineering Team
 * @notice This Contract Is Used For Managing PCCFactory And PCCBatch
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../helper/BasicMetaTransaction.sol";
import "../interfaces/IPlannedCarbonCredit.sol";
import "./PCCFactory.sol";

contract PCCManager is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    BasicMetaTransaction
{
    /**
        @dev Inheriting SafeERC20 for IERC20
     */
    using SafeERC20 for IERC20;

    /**
        @dev Inheriting StringsUpgradeable library for uint256
     */
    using StringsUpgradeable for uint256;

    /**
        @notice Declaring access based roles
     */
    bytes32 public constant EVX_SUPER_ADMIN_ROLE =
        keccak256("EVX_SUPER_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    /**
     * @notice Global declaration of PCCFactory contract
     */
    PCCFactory public pccFactoryContract;

    /**
        @notice MintedMoreInABatch triggers when a more tokens are minted in a 
                batch
     */
    event MintedMoreInABatch(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        uint256 amountToMint,
        address batchOwnerAddress,
        uint256 batchSupply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice MintedMoreInABatch triggers when a some tokens are burned 
                from a batch
     */
    event BurnedFromABatch(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        uint256 amountToBurn,
        address batchOwnerAddress,
        uint256 batchSupply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice ManyToManyBatchTransfer triggers on many-many transfer 
     */
    event ManyToManyBatchTransfer(
        address[] batchIds,
        address[] userAddresses,
        uint256[] amountToTransfer
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's delivery 
                year is updated
     */
    event BatchDeliveryYearUpdated(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        uint256 updatedDeliveryYear
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's delivery 
                estimate is updated
     */
    event BatchDeliveryEstimateUpdated(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        string updatedDeliveryEstimate
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's URI is 
                updated
     */
    event BatchURIUpdated(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        string updatedBatchURI
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
        @notice Initialize: Initialize a smart contract
        @dev Works as a constructor for proxy contracts
        @param _superAdmin Admin wallet address
        @param _pccFactoryContract PCCFactory contract address
     */
    function initialize(
        address _superAdmin,
        address _pccFactoryContract
    ) external initializer {
        __Ownable_init();
        _setRoleAdmin(EVX_SUPER_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UPDATER_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(EVX_SUPER_ADMIN_ROLE, _superAdmin);
        _setupRole(MINTER_ROLE, _superAdmin);
        _setupRole(BURNER_ROLE, _superAdmin);
        _setupRole(UPDATER_ROLE, _superAdmin);

        pccFactoryContract = PCCFactory(_pccFactoryContract);
    }

    /** 
        @notice UUPS upgrade mandatory function: To authorize the owner to upgrade 
                the contract
    */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
        @notice mintMoreInABatch: Create a new batch w.r.t projectId and commodityId
        @dev Calls child batch for minting more in a batch
                This will basically increase the supply of ERC20 contract
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
        @param _amountToMint Amount to minting more
        @param _batchOwner Receiver address where tokens will get mint
     */
    function mintMoreInABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToMint,
        address _batchOwner
    ) external onlyRole(MINTER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint
        );
        pccFactoryContract.updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint,
            0
        );
        IPlannedCarbonCredit(_batchId).mint(_batchOwner, _amountToMint);

        uint256 _currentBatchSupply = pccFactoryContract
            .getBatchDetails(_projectId, _commodityId, _batchId)
            .batchSupply;

        uint256 _currentTotalSupply = pccFactoryContract
            .getProjectCommodityTotalSupply(_projectId, _commodityId);

        emit MintedMoreInABatch(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint,
            _batchOwner,
            _currentBatchSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice burnFromABatch: Create a new batch w.r.t projectId and commodityId
        @dev Calls child batch for burning from a batch
                This will basically increase the supply of ERC20 contract
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
        @param _amountToBurn Amount to burn
        @param _batchOwner Owner address where tokens will get burned from
     */
    function burnFromABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToBurn,
        address _batchOwner
    ) external onlyRole(BURNER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn
        );
        pccFactoryContract.updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn,
            1
        );
        IPlannedCarbonCredit(_batchId).burn(_batchOwner, _amountToBurn);

        uint256 _currentBatchSupply = pccFactoryContract
            .getBatchDetails(_projectId, _commodityId, _batchId)
            .batchSupply;

        uint256 _currentTotalSupply = pccFactoryContract
            .getProjectCommodityTotalSupply(_projectId, _commodityId);

        emit BurnedFromABatch(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn,
            _batchOwner,
            _currentBatchSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice manyToManyBatchTransfer: Perform PCC transfer from diferent batches 
                to different user
        @param _batchIds List of batch Ids
        @param _userAddresses List of batch Ids
        @param _amountToTransfer List of amount to be transferred
     */
    function manyToManyBatchTransfer(
        address[] calldata _batchIds,
        address[] calldata _userAddresses,
        uint256[] calldata _amountToTransfer
    ) external onlyRole(EVX_SUPER_ADMIN_ROLE) {
        require(
            _batchIds.length == _userAddresses.length &&
                _userAddresses.length == _amountToTransfer.length,
            "UNEVEN_ARGUMENTS_PASSED"
        );

        for (uint256 i = 0; i < _batchIds.length; ) {
            IERC20(_batchIds[i]).safeTransferFrom(
                _msgSender(),
                _userAddresses[i],
                _amountToTransfer[i]
            );
            unchecked {
                ++i;
            }
        }

        emit ManyToManyBatchTransfer(
            _batchIds,
            _userAddresses,
            _amountToTransfer
        );
    }

    /**
        @notice updateBatchDeliveryYear: Update delivery year of batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedDeliveryYear Updated delivery year value
     */
    function updateBatchDeliveryYear(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _updatedDeliveryYear
    ) external onlyRole(UPDATER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        pccFactoryContract.updateBatchDetailDuringDeliveryYearChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedDeliveryYear
        );

        emit BatchDeliveryYearUpdated(
            _projectId,
            _commodityId,
            _batchId,
            _updatedDeliveryYear
        );
    }

    /**
        @notice updateBatchDeliveryEstimate: Update delivery estimates of batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedDeliveryEstimate Updated delivery estimates value
     */
    function updateBatchDeliveryEstimate(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        string calldata _updatedDeliveryEstimate
    ) external onlyRole(UPDATER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        pccFactoryContract.updateBatchDetailDuringDeliveryEstimateChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedDeliveryEstimate
        );

        emit BatchDeliveryEstimateUpdated(
            _projectId,
            _commodityId,
            _batchId,
            _updatedDeliveryEstimate
        );
    }

    /**
        @notice updateBatchURI: Update Batch URI for a batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedURI Updated URI value
     */
    function updateBatchURI(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external onlyRole(UPDATER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        pccFactoryContract.updateBatchDetailDuringURIChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedURI
        );

        emit BatchURIUpdated(_projectId, _commodityId, _batchId, _updatedURI);
    }

    /**
     * @notice _checkBeforeMintMoreAndBurnMore: Process different checks before mint/burn more
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _amountToMintOrBurn Amount to mint/burn
     */
    function _checkBeforeMintMoreAndBurnMore(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToMintOrBurn
    ) internal pure {
        require(
            (_projectId != 0) && (_commodityId != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(_amountToMintOrBurn != 0, "ARGUMENT_PASSED_AS_ZERO");
        require(_batchId != address(0), "ARGUMENT_PASSED_AS_ZERO");
    }

    /**
     * @notice _checkBeforeUpdatingBatchDetails: Process different checks before updating batch details
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     */
    function _checkBeforeUpdatingBatchDetails(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId
    ) internal pure {
        require(
            (_projectId != 0) && (_commodityId != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(_batchId != address(0), "ARGUMENT_PASSED_AS_ZERO");
    }

    /**
        @dev function to override _msgsender()  for BMT
     */
    function _msgSender() internal view virtual override returns (address) {
        return msgSender();
    }
}
