// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/**
 * @title Planned Credit Manager Contract
 * @author Team @vericap
 * @notice Planned Credit Manager is a upgradeable contract used for mananing Planned Credit Batch related actions
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
import "../interfaces/IPlannedCredit.sol";
import "./PlannedCreditFactory.sol";

contract PlannedCreditManager is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
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
        @notice Defining MANAGER_ROLE
     */
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /**
     * @notice Global declaration of PlannedCreditFactory contract
     */
    PlannedCreditFactory public plannedCreditFactoryContract;

    /**
        @notice MintedMoreInABatch: Triggers when a more tokens are minted in a 
                batch
     */
    event MintedMoreInABatch(
        string projectId,
        string commodityId,
        address batchId,
        address batchOwnerAddress,
        uint256 amountToMint,
        uint256 batchSupply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice BurnedFromABatch: Triggers when a some tokens are burned 
                from a batch
     */
    event BurnedFromABatch(
        string projectId,
        string commodityId,
        address batchId,
        address batchOwnerAddress,
        uint256 amountToBurn,
        uint256 batchSupply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice ManyToManyBatchTransfer: Triggers on many-many transfer 
     */
    event ManyToManyBatchTransfer(
        IERC20[] batchIds,
        address[] _projectDeveloperAddresses,
        bytes[] batchTransferData
    );

    /**
        @notice BatchPlannedDeliveryYearUpdated: Triggers when a batch's delivery 
                year is updated
     */
    event PlannedDeliveryYearUpdatedForBatch(
        string projectId,
        string commodityId,
        address batchId,
        uint256 updatedPlannedDeliveryYear
    );

    /**
        @notice BatchPlannedDeliveryYearUpdated: Triggers when a batch's URI is 
                updated
     */
    event URIUpdatedForBatch(
        string projectId,
        string commodityId,
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
        @param _plannedCreditFactoryContract PlannedCreditFactory contract address
     */
    function initialize(
        address _superAdmin,
        address _plannedCreditFactoryContract
    ) external initializer {
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(MANAGER_ROLE, _superAdmin);
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        plannedCreditFactoryContract = PlannedCreditFactory(
            _plannedCreditFactoryContract
        );
    }

    /** 
        @notice UUPS upgrade mandatory function: To authorize the owner to upgrade 
                the contract
    */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
        @notice mintMoreInABatch: Increase supply of a PlannedCredit batch by minting
        @dev Calls child batch for minting more in a batch
                This will basically increase the supply of ERC20 contract
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
        @param _batchOwner Receiver address where tokens will get mint
        @param _amountToMint Amount to minting more
     */
    function mintMoreInABatch(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToMint
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint
        );
        plannedCreditFactoryContract.updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _amountToMint,
            0,
            _batchId
        );
        IPlannedCredit(_batchId).mintPlannedCredits(_batchOwner, _amountToMint);

        uint256 _currentBatchSupply = plannedCreditFactoryContract
            .getBatchDetails(_projectId, _commodityId, _batchId)
            .batchSupply;

        uint256 _currentTotalSupply = plannedCreditFactoryContract
            .getProjectCommodityTotalSupply(_projectId, _commodityId);

        emit MintedMoreInABatch(
            _projectId,
            _commodityId,
            _batchId,
            _batchOwner,
            _amountToMint,
            _currentBatchSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice burnFromABatch: Decreasing supply of a PlannedCredit batch by burning more
        @dev Calls child batch for burning from a batch
                This will basically increase the supply of ERC20 contract
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
        @param _batchOwner Owner address where tokens will get burned from
        @param _amountToBurn Amount to burn
     */
    function burnFromABatch(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToBurn
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn
        );
        plannedCreditFactoryContract.updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _amountToBurn,
            1,
            _batchId
        );
        IPlannedCredit(_batchId).burnPlannedCredits(_batchOwner, _amountToBurn);

        uint256 _currentBatchSupply = plannedCreditFactoryContract
            .getBatchDetails(_projectId, _commodityId, _batchId)
            .batchSupply;

        uint256 _currentTotalSupply = plannedCreditFactoryContract
            .getProjectCommodityTotalSupply(_projectId, _commodityId);

        emit BurnedFromABatch(
            _projectId,
            _commodityId,
            _batchId,
            _batchOwner,
            _amountToBurn,
            _currentBatchSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice manyToManyBatchTransfer: Perform M2M PlannedCredit transfer from diferent batches 
                to different user from different project developers.
                Note: Approval mechanism should be performed prior to this functionality
        @param _batchTokenIds List of batch Ids
        @param _batchTransferData receiver addresses and amounts to be converted into bytes
        @dev Project developers needs to approve the PlannedCreditManager. 
             As, PlannedCreditManager will trigger the transfer function in PlannedCreditBatch contract
     */
    function manyToManyBatchTransfer(
        IERC20[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external onlyRole(MANAGER_ROLE) {
        require(
            (_batchTokenIds.length == _projectDeveloperAddresses.length),
            "UNEVEN_ARGUMENTS_PASSED"
        );
        for (uint256 i = 0; i < _batchTokenIds.length; i++) {
            (
                address[] memory _receiverAddresses,
                uint256[] memory _amountToTransfer
            ) = abi.decode(_batchTransferData[i], (address[], uint256[]));
            require(
                _receiverAddresses.length == _amountToTransfer.length,
                "UNEVEN_ARGUMENTS_PASSED"
            );

            for (uint256 j = 0; j < _receiverAddresses.length; j++) {
                IERC20 batch = _batchTokenIds[i];
                batch.safeTransferFrom(
                    _projectDeveloperAddresses[i],
                    _receiverAddresses[j],
                    _amountToTransfer[j]
                );
            }
        }

        emit ManyToManyBatchTransfer(
            _batchTokenIds,
            _projectDeveloperAddresses,
            _batchTransferData
        );
    }

    /**
        @notice updateBatchPlannedDeliveryYear: Update delivery year of PlannedCredit batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedPlannedDeliveryYear Updated delivery year value
     */
    function updateBatchPlannedDeliveryYear(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        uint256 _updatedPlannedDeliveryYear
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        plannedCreditFactoryContract
            .updateBatchDetailDuringPlannedDeliveryYearChange(
                _projectId,
                _commodityId,
                _updatedPlannedDeliveryYear,
                _batchId
            );

        emit PlannedDeliveryYearUpdatedForBatch(
            _projectId,
            _commodityId,
            _batchId,
            _updatedPlannedDeliveryYear
        );
    }

    /**
        @notice updateBatchURI: Update Batch URI for a PlannedCredit batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedURI Updated URI value
     */
    function updateBatchURI(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        plannedCreditFactoryContract.updateBatchDetailDuringURIChange(
            _projectId,
            _commodityId,
            _updatedURI,
            _batchId
        );

        emit URIUpdatedForBatch(
            _projectId,
            _commodityId,
            _batchId,
            _updatedURI
        );
    }

    /**
     * @notice setFactoryManagerContract: Set's PlannedCreditFactory contract
     * @param _plannedCreditFactoryContract PlannedCreditFactory contract address
     */
    function setFactoryManagerContract(
        address _plannedCreditFactoryContract
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _plannedCreditFactoryContract != address(0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        plannedCreditFactoryContract = PlannedCreditFactory(
            _plannedCreditFactoryContract
        );
    }

    /**
     * @notice _checkBeforeMintMoreAndBurnMore: Process different checks before mint/burn more
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _amountToMintOrBurn Amount to mint/burn
     */
    function _checkBeforeMintMoreAndBurnMore(
        string memory _projectId,
        string memory _commodityId,
        address _batchId,
        uint256 _amountToMintOrBurn
    ) internal pure {
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_amountToMintOrBurn != 0) &&
                (_batchId != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
     * @notice _checkBeforeUpdatingBatchDetails: Process different checks before updating batch details
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     */
    function _checkBeforeUpdatingBatchDetails(
        string memory _projectId,
        string memory _commodityId,
        address _batchId
    ) internal pure {
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_batchId != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }
}
