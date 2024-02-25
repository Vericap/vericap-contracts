// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Vericap: PCC Manager smart contract
 * @author Vericap Blockchain Engineering Team
 * @notice This Contract Is Used For Creating PCCBatch
 */

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../helper/BasicMetaTransaction.sol";

contract VericapPCCManager is
    Initializable,
    UUPSUpgradeable,
    ERC1155SupplyUpgradeable,
    AccessControlUpgradeable,
    BasicMetaTransaction
{
    /**
        @dev Inheriting StringsUpgradeable library for uint256
     */
    using StringsUpgradeable for uint256;

    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _batchIds;

    /**
        @notice Declaring access based roles
     */
    bytes32 public constant VERICAP_SUPER_ADMIN_ROLE =
        keccak256("VERICAP_SUPER_ADMIN_ROLE");
    bytes32 public constant VERICAP_MINTER_ROLE =
        keccak256("VERICAP_MINTER_ROLE");
    bytes32 public constant VERICAP_MANAGER_ROLE =
        keccak256("VERICAP_MANAGER_ROLE");

    /**
        @dev projectIds: Storing project Ids in an array
     */
    uint256[] internal projectIds;

    /**
     * @dev Creating ENUM for handling PCC batch actions
     * @dev Mint - 0
     * @dev Burn - 1
     */
    enum PCCTokenActions {
        Mint,
        Burn
    }
    /**
        @dev BatchDetail: holds the properties for a batch
     */
    struct BatchDetail {
        uint256 batchId;
        address batchOwner;
        string deliveryEstimates;
        string batchURI;
        uint256 projectId;
        uint256 commodityId;
        uint256 deliveryYear;
        uint256 batchSupply;
        uint256 lastUpdated;
    }

    /**
        @dev batchDetails: Stores BatchDetail w.r.t projectId and commodityId
     */
    mapping(uint256 => mapping(uint256 => mapping(uint256 => BatchDetail[])))
        internal batchDetails;

    /** 
        @dev commodityList: Stores commodities w.r.t projectIds
    */
    mapping(uint256 => uint256[]) internal commodityList;

    /**
        @dev batchIndexList: Batch Indexer, associating each batch with a index value
     */
    mapping(uint256 => uint256) internal batchIndexList;

    /**
        @dev batchList: Stores list of batched w.r.t projectId and commodityId
     */
    mapping(uint256 => mapping(uint256 => uint256[])) internal batchList;

    /**
        @dev projectCommodityTotalSupply: Stores total supply of a project::commodity
     */
    mapping(uint256 => mapping(uint256 => uint256))
        internal projectCommodityTotalSupply;

    /**
     * @dev commodityIdExists: Checking for duplication of commodityId w.r.t a projectId
     */
    mapping(uint256 => mapping(uint256 => bool)) internal commodityIdExists;

    /**
     * @dev projectIdExists: Checking for duplication of projectId
     */
    mapping(uint256 => bool) internal projectIdExists;

    /** @dev _transferDisabled: Checking for Transfer enabled/disabled */
    mapping(address => bool) private _transferDisabled;

    /**
        @notice NewBatchCreated triggers when a new batch is created
     */
    event NewBatchCreated(
        uint256 projectId,
        uint256 commodityId,
        uint256 batchId,
        address batchOwner,
        uint256 batchSupply,
        uint256 deliveryYear,
        string deliveryEstimate,
        string batchURI,
        uint256 lastUpdated
    );

    /**
        @notice MintedMoreInABatch triggers when a more tokens are minted in a 
                batch
     */
    event MintedMoreInABatch(
        uint256 projectId,
        uint256 commodityId,
        uint256 batchId,
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
        uint256 batchId,
        uint256 amountToBurn,
        address batchOwnerAddress,
        uint256 batchSupply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice ManyToManyBatchTransfer triggers on many-many transfer 
     */
    event ManyToManyBatchTransfer(
        uint256[] batchIds,
        address[] _projectDeveloperAddresses,
        bytes[] batchTransferData
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's delivery 
                year is updated
     */
    event BatchDeliveryYearUpdated(
        uint256 projectId,
        uint256 commodityId,
        uint256 batchId,
        uint256 updatedDeliveryYear
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's delivery 
                estimate is updated
     */
    event BatchDeliveryEstimateUpdated(
        uint256 projectId,
        uint256 commodityId,
        uint256 batchId,
        string updatedDeliveryEstimate
    );

    /**
        @notice BatchDeliveryYearUpdated triggers when a batch's URI is 
                updated
     */
    event BatchURIUpdated(
        uint256 projectId,
        uint256 commodityId,
        uint256 batchId,
        string updatedBatchURI
    );

    /**
     *
     */
    event TransferEnabledForUser(address accountAddress, uint256 timestamp);

    /**
     *
     */
    event TransferDisabledForUser(address accountAddress, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
        @notice Initialize: Initialize a smart contract
        @dev Works as a constructor for proxy contracts
        @param _superAdmin Admin wallet address
     */
    function initialize(address _superAdmin) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _setRoleAdmin(VERICAP_SUPER_ADMIN_ROLE, VERICAP_SUPER_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(VERICAP_MINTER_ROLE, _superAdmin);
        _setupRole(VERICAP_MANAGER_ROLE, _superAdmin);
    }

    /** 
        @notice UUPS upgrade mandatory function: To authorize the owner to upgrade 
                the contract
    */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(VERICAP_SUPER_ADMIN_ROLE) {}

    /**
        @notice getProjectCommodityTotalSupply: View function to fetch the 
                total supply of a projectId-commodityId pair
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @return uint256 Total supply 
     */
    function getProjectCommodityTotalSupply(
        uint256 _projectId,
        uint256 _commodityId
    ) public view returns (uint256) {
        return projectCommodityTotalSupply[_projectId][_commodityId];
    }

    /**
        @notice getProjectList: View function to fetch the list of projects
        @return uint256[] List of projects 
     */
    function getProjectList() public view returns (uint256[] memory) {
        return projectIds;
    }

    /**
        @notice getCommodityListForAProject: View function to fetch list of 
                commodities w.r.t a projectId
        @param _projectId Project Id
        @return uint256[] List of commodities for a project
     */
    function getCommodityListForAProject(
        uint256 _projectId
    ) public view returns (uint256[] memory) {
        uint256[] memory _commodityList = new uint256[](
            commodityList[_projectId].length
        );
        for (uint256 i = 0; i < commodityList[_projectId].length; ) {
            _commodityList[i] = commodityList[_projectId][i];

            unchecked {
                ++i;
            }
        }

        return _commodityList;
    }

    /**
        @notice getBatchListForACommodityInABatch: View function to fetch 
                list of batches w.r.t projectId & commodityId
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @return address[] List of batches
     */
    function getBatchListForACommodityInAProject(
        uint256 _projectId,
        uint256 _commodityId
    ) public view returns (uint256[] memory) {
        uint256[] memory _batchList = new uint256[](
            batchList[_projectId][_commodityId].length
        );
        for (uint256 i = 0; i < batchList[_projectId][_commodityId].length; ) {
            _batchList[i] = batchList[_projectId][_commodityId][i];
            unchecked {
                ++i;
            }
        }

        return _batchList;
    }

    function isTransferDisabled(address account) external view returns (bool) {
        return _transferDisabled[account];
    }

    /**
        @notice getBatchDetails: View function to fetch properties of a batch
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t project
     */
    function getBatchDetails(
        uint256 _projectId,
        uint256 _commodityId,
        uint256 _batchId
    ) external view returns (BatchDetail memory) {
        return
            batchDetails[_projectId][_commodityId][_batchId][
                batchIndexList[_batchId]
            ];
    }

    /**
        @notice mintNewBatch: Create a new batch w.r.t projectId and commodityId
        @dev Follows factory-child pattern for creating batches using CREATE2 opcode
                Child contract is going to be ERC20 compatible smart contract
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchOwner Batch owner address
        @param _batchSupply Batch token supply
        @param _deliveryYear Delivery year
        @param _deliveryEstimate Delivery estimates
        @param _batchURI Batch URI
     */
    function createNewBatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchOwner,
        uint256 _batchSupply,
        uint256 _deliveryYear,
        string calldata _deliveryEstimate,
        string calldata _batchURI
    ) external onlyRole(VERICAP_MINTER_ROLE) {
        _checkBeforeMintNewBatch(
            _projectId,
            _commodityId,
            _batchOwner,
            _batchSupply,
            _deliveryYear,
            _batchURI
        );

        _batchIds.increment();
        uint256 _batchId = _batchIds.current();

        _mint(_batchOwner, _batchId, _batchSupply, "0x00");

        batchDetails[_projectId][_commodityId][_batchId].push(
            BatchDetail(
                _batchId,
                _batchOwner,
                _deliveryEstimate,
                _batchURI,
                _projectId,
                _commodityId,
                _deliveryYear,
                _batchSupply,
                block.timestamp
            )
        );

        batchIndexList[_batchId] =
            batchDetails[_projectId][_commodityId][_batchId].length -
            1;

        _updateProjectCommodityBatchStorage(_projectId, _commodityId, _batchId);

        projectCommodityTotalSupply[_projectId][_commodityId] += _batchSupply;

        emit NewBatchCreated(
            _projectId,
            _commodityId,
            _batchId,
            _batchOwner,
            _batchSupply,
            _deliveryYear,
            _deliveryEstimate,
            _batchURI,
            block.timestamp
        );
    }

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
        uint256 _batchId,
        uint256 _amountToMint,
        address _batchOwner
    ) external onlyRole(VERICAP_MINTER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint
        );
        updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint,
            0
        );
        _mint(_batchOwner, _batchId, _amountToMint, "0x00");

        uint256 _currentCommoditySupply = getProjectCommodityTotalSupply(
            _projectId,
            _commodityId
        );

        uint _currentBatchSupply = totalSupply(_batchId);

        emit MintedMoreInABatch(
            _projectId,
            _commodityId,
            _batchId,
            _amountToMint,
            _batchOwner,
            _currentBatchSupply,
            _currentCommoditySupply
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
        uint256 _batchId,
        uint256 _amountToBurn,
        address _batchOwner
    ) external onlyRole(VERICAP_MINTER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn
        );
        updateBatchDetailDuringMintOrBurnMore(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn,
            1
        );
        _burn(_batchOwner, _batchId, _amountToBurn);

        uint256 _currentCommoditySupply = getProjectCommodityTotalSupply(
            _projectId,
            _commodityId
        );

        uint _currentBatchSupply = totalSupply(_batchId);

        emit BurnedFromABatch(
            _projectId,
            _commodityId,
            _batchId,
            _amountToBurn,
            _batchOwner,
            _currentBatchSupply,
            _currentCommoditySupply
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
        uint256[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external onlyRole(VERICAP_MINTER_ROLE) {
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
                safeTransferFrom(
                    _projectDeveloperAddresses[i],
                    _receiverAddresses[j],
                    _batchTokenIds[i],
                    _amountToTransfer[j],
                    "0x00"
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
        @notice updateBatchDeliveryYear: Update delivery year of batch
        @param _projectId Project Id 
        @param _commodityId Commodity Id
        @param _batchId Batch Id w.r.t to project Id and commidity Id
        @param _updatedDeliveryYear Updated delivery year value
     */
    function updateBatchDeliveryYear(
        uint256 _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        uint256 _updatedDeliveryYear
    ) external onlyRole(VERICAP_MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        updateBatchDetailDuringDeliveryYearChange(
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
        uint256 _batchId,
        string calldata _updatedDeliveryEstimate
    ) external onlyRole(VERICAP_MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        updateBatchDetailDuringDeliveryEstimateChange(
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
        uint256 _batchId,
        string calldata _updatedURI
    ) external onlyRole(VERICAP_MANAGER_ROLE) {
        _checkBeforeUpdatingBatchDetails(_projectId, _commodityId, _batchId);
        updateBatchDetailDuringURIChange(
            _projectId,
            _commodityId,
            _batchId,
            _updatedURI
        );

        emit BatchURIUpdated(_projectId, _commodityId, _batchId, _updatedURI);
    }

    function enableTransferFor(
        address account
    ) external onlyRole(VERICAP_MANAGER_ROLE) {
        _transferDisabled[account] = false;
        emit TransferEnabledForUser(account, block.timestamp);
    }

    function disableTransferFor(
        address account
    ) external onlyRole(VERICAP_MANAGER_ROLE) {
        _transferDisabled[account] = true;
        emit TransferDisabledForUser(account, block.timestamp);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        require(!_transferDisabled[msgSender()], "TRANSFER_NOT_ENABLED");
        // Call the parent class's _beforeTokenTransfer function
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @notice updateBatchDetailDuringMintOrBurnMore Updates batch details when ever PCCs are minted/burned
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _amountToMintOrBurn Amount of tokens to mint/burn
     * @param _pccBatchAction PCC batch actions
     */
    function updateBatchDetailDuringMintOrBurnMore(
        uint _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        uint256 _amountToMintOrBurn,
        uint8 _pccBatchAction
    ) internal onlyRole(VERICAP_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        if (_pccBatchAction == uint(PCCTokenActions.Mint)) {
            _detail.batchSupply = _detail.batchSupply + _amountToMintOrBurn;
            _detail.lastUpdated = block.timestamp;
            projectCommodityTotalSupply[_projectId][
                _commodityId
            ] += _amountToMintOrBurn;
        } else if (_pccBatchAction == uint(PCCTokenActions.Burn)) {
            _detail.batchSupply = _detail.batchSupply - _amountToMintOrBurn;
            _detail.lastUpdated = block.timestamp;
            projectCommodityTotalSupply[_projectId][
                _commodityId
            ] -= _amountToMintOrBurn;
        }
    }

    /**
     * @notice updateBatchDetailDuringURIChange: Update the factory storage
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _deliveryYear Updated batch D.Y
     */
    function updateBatchDetailDuringDeliveryYearChange(
        uint _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        uint256 _deliveryYear
    ) internal onlyRole(VERICAP_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        _detail.deliveryYear = _deliveryYear;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice updateBatchDetailDuringURIChange: Update the factory storage
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _deliveryEstimate Updated batch D.E
     */
    function updateBatchDetailDuringDeliveryEstimateChange(
        uint _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        string calldata _deliveryEstimate
    ) internal onlyRole(VERICAP_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        _detail.deliveryEstimates = _deliveryEstimate;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice updateBatchDetailDuringURIChange: Update the factory storage
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchId Batch Id
     * @param _batchURI Updated batch URI
     */
    function updateBatchDetailDuringURIChange(
        uint _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        string calldata _batchURI
    ) internal onlyRole(VERICAP_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        _detail.batchURI = _batchURI;
        _detail.lastUpdated = block.timestamp;
    }

    /**
        @notice _checkBeforeMintNewBatch: Process different checks before minting new batch
        @dev Checking credibilty of arguments
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchOwner Batch owner address
        @param _batchSupply Batch token supply
        @param _deliveryYear Delivery year
        @param _batchURI Batch URI
     */
    function _checkBeforeMintNewBatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchOwner,
        uint256 _batchSupply,
        uint256 _deliveryYear,
        string calldata _batchURI
    ) internal pure {
        require(
            (_projectId != 0) && (_commodityId != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(
            (_batchSupply != 0) &&
                (_deliveryYear != 0) &&
                (_batchOwner != address(0)) &&
                bytes(_batchURI).length != 0,
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
        @notice burnFromABatch: Create a new batch w.r.t projectId and commodityId
        @dev Checking credibilty of arguments
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
        @param _amountToMintOrBurn Amount to mint/burn
     */
    function _checkBeforeMintMoreAndBurnMore(
        uint256 _projectId,
        uint256 _commodityId,
        uint256 _batchId,
        uint256 _amountToMintOrBurn
    ) internal pure {
        require(
            (_projectId != 0) && (_commodityId != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(_amountToMintOrBurn != 0, "ARGUMENT_PASSED_AS_ZERO");
        require(_batchId != 0, "ARGUMENT_PASSED_AS_ZERO");
    }

    /**
        @notice _checkBeforeUpdatingBatchDetails: Check before updating batch details
        @dev Checking credibilty of arguments
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchId Batch owner address
     */
    function _checkBeforeUpdatingBatchDetails(
        uint256 _projectId,
        uint256 _commodityId,
        uint256 _batchId
    ) internal pure {
        require(
            (_projectId != 0) && (_commodityId != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(_batchId != 0, "ARGUMENT_PASSED_AS_ZERO");
    }

    /**
        @notice updateProjectCommodityBatchStorage: Updating batch storage for a 
                project and commodity
        @param _projectId Project Id
        @param _commodityId Commodity Id
        @param _batchAddress Batch Id
     */
    function _updateProjectCommodityBatchStorage(
        uint256 _projectId,
        uint256 _commodityId,
        uint256 _batchAddress
    ) internal onlyRole(VERICAP_MANAGER_ROLE) {
        // Checking for project Id duplication
        if (projectIdExists[_projectId] == false) {
            projectIds.push(_projectId);
            projectIdExists[_projectId] = true;
        }

        // Checking for commodity Id duplication
        if (commodityIdExists[_projectId][_commodityId] == false) {
            commodityList[_projectId].push(_commodityId);
            commodityIdExists[_projectId][_commodityId] = true;
        }

        batchList[_projectId][_commodityId].push(_batchAddress);
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
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
        @dev function to override _msgsender()  for BMT
     */
    function _msgSender() internal view virtual override returns (address) {
        return msgSender();
    }
}
