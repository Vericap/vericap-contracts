// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/**
 * @title Planned Carbon Credit Manager Contract
 * @author Team @vericap
 * @notice Manager is a upgradeable contract used for mananing PCC Batch related actions
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
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

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
        IERC20[] batchIds,
        address[] _projectDeveloperAddresses,
        bytes[] batchTransferData
    );

    /**
        @notice BatchPlannedDeliveryYearUpdated triggers when a batch's delivery 
                year is updated
     */
    event PlannedDeliveryYearUpdatedForBatch(
        uint256 projectId,
        uint256 commodityId,
        address batchId,
        uint256 updatedPlannedDeliveryYear
    );

    /**
        @notice BatchPlannedDeliveryYearUpdated triggers when a batch's URI is 
                updated
     */
    event URIUpdatedForBatch(
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
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(MANAGER_ROLE, _superAdmin);
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

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
    ) external onlyRole(MANAGER_ROLE) {
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
    ) external onlyRole(MANAGER_ROLE) {
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
        @param _batchTokenIds List of batch Ids
        @param _batchTransferData receiver addresses and amounts to be converted into bytes
        @dev Project developers needs to approve the PCCManager. 
             As, PCCManager will trigger the transfer function in PCCBatch contract
     */
    function manyToManyBatchTransfer(
        IERC20[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _batchTokenIds.length == _projectDeveloperAddresses.length,
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
        @notice updateBatchPlannedDeliveryYear: Update delivery year of batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedPlannedDeliveryYear Updated delivery year value
     */
    function updateBatchPlannedDeliveryYear(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _updatedPlannedDeliveryYear
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        pccFactoryContract.updateBatchDetailDuringPlannedDeliveryYearChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedPlannedDeliveryYear
        );

        emit PlannedDeliveryYearUpdatedForBatch(
            _projectId,
            _commodityId,
            _batchId,
            _updatedPlannedDeliveryYear
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
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        pccFactoryContract.updateBatchDetailDuringURIChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedURI
        );

        emit URIUpdatedForBatch(
            _projectId,
            _commodityId,
            _batchId,
            _updatedURI
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
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToMintOrBurn
    ) internal pure {
        require(
            (_projectId != 0) &&
                (_commodityId != 0) &&
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
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId
    ) internal pure {
        require(
            (_projectId != 0) &&
                (_commodityId != 0) &&
                (_batchId != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
        @dev function to override _msgsender()  for BMT
     */
    function _msgSender() internal view virtual override returns (address) {
        return msgSender();
    }
}
