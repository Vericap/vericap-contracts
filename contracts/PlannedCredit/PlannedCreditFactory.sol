// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/**
 * @title Planned Credit Factory Smart Contract
 * @author Team @vericap
 * @notice Factory is a upgradeable contract used for deploying new PlannedCredit contracts
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

error ARGUMENT_PASSED_AS_ZERO();

contract PlannedCreditFactory is
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
     * @dev Global declaration of plannedCreditManager contract
     */
    address public plannedCreditManagerContract;

    /**
            @dev projectIds: Storing project Ids in an array
        */
    string[] internal projectIds;

    bytes32 public constant FACTORY_MANAGER_ROLE =
        keccak256("FACTORY_MANAGER_ROLE");

    /**
     * @dev Creating ENUM for handling PlannedCredit batch actions
     * @dev Mint - 0
     * @dev Burn - 1
     */
    enum PlannedCreditTokenActions {
        Mint,
        Burn
    }

    /**
            @dev BatchDetail: holds the properties for a batch
        */
    struct BatchDetail {
        string projectId;
        string commodityId;
        string vintage;
        string batchURI;
        string uniqueIdentifier;
        uint256 plannedDeliveryYear;
        uint256 batchSupply;
        uint256 lastUpdated;
        address batchId;
        address batchOwner;
    }

    /**
            @dev batchDetails: Stores BatchDetail w.r.t projectId::commodityId
        */
    mapping(string => mapping(string => mapping(address => BatchDetail[])))
        internal batchDetails;

    /** 
            @dev commodityList: Stores commodities w.r.t projectId
        */
    mapping(string => string[]) internal commodityList;

    /**
            @dev batchIndexList: Batch Indexer, associating each batch with a index value
        */
    mapping(address => uint256) internal batchIndexList;

    /**
            @dev batchList: Stores list of batches w.r.t projectId::commodityId
        */
    mapping(string => mapping(string => address[])) internal batchList;

    /**
            @dev projectCommodityTotalSupply: Stores total supply of a project::commodity
        */
    mapping(string => mapping(string => uint256))
        internal projectCommodityTotalSupply;

    /**
     * @dev commodityIdExists: Checking for duplication of commodityId::projectId
     */
    mapping(string => mapping(string => bool)) internal commodityIdExists;

    /**
     * @dev projectIdExists: Checking for duplication of projectId
     */
    mapping(string => bool) internal projectIdExists;

    /**
            @notice NewBatchCreated triggers when a new batch is created
        */
    event NewBatchCreated(
        string projectId,
        string commodityId,
        string vintage,
        string batchURI,
        string uniqueIdentifier,
        uint256 plannedDeliveryYear,
        uint256 batchSupply,
        uint256 lastUpdated,
        address batchId,
        address batchOwner
    );

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
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _setupRole(FACTORY_MANAGER_ROLE, _superAdmin);
        _setRoleAdmin(FACTORY_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /** 
            @notice UUPS upgrade mandatory function: To authorize the owner to upgrade 
                    the contract
        */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
            @notice getProjectCommodityTotalSupply: View function to fetch the 
                    total supply of a projectId-commodityId pair
            @param _projectId Project Id
            @param _commodityId Commodity Id
            @return string Total supply 
        */
    function getProjectCommodityTotalSupply(
        string calldata _projectId,
        string calldata _commodityId
    ) public view returns (uint256) {
        return projectCommodityTotalSupply[_projectId][_commodityId];
    }

    /**
            @notice getProjectList: View function to fetch the list of projects
            @return string[] List of projects 
        */
    function getProjectList() public view returns (string[] memory) {
        return projectIds;
    }

    /**
            @notice getCommodityListForAProject: View function to fetch list of 
                    commodities w.r.t a projectId
            @param _projectId Project Id
            @return uint256[] List of commodities for a project
        */
    function getCommodityListForAProject(
        string calldata _projectId
    ) public view returns (string[] memory) {
        string[] memory _commodityList = new string[](
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
        string calldata _projectId,
        string calldata _commodityId
    ) public view returns (address[] memory) {
        address[] memory _batchList = new address[](
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

    /**
            @notice getBatchDetails: View function to fetch properties of a batch
            @param _projectId Project Id
            @param _commodityId Commodity Id
            @param _batchId Batch Id w.r.t project
        */
    function getBatchDetails(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId
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
            @param _vintage Project vintage
            @param _batchURI Batch URI
            @param _uniqueIdentifier Unique identifer for salt
            @param _plannedDeliveryYear Planned delivery year of the batch
            @param _batchSupply Batch intial supply
            @param _batchOwner Batch owner address
        */
    function createNewBatch(
        string calldata _projectId,
        string calldata _commodityId,
        string calldata _vintage,
        string calldata _batchURI,
        string calldata _uniqueIdentifier,
        uint256 _plannedDeliveryYear,
        uint256 _batchSupply,
        address _batchOwner
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeMintNewBatch(
            _projectId,
            _commodityId,
            _batchURI,
            _uniqueIdentifier,
            _batchSupply,
            _plannedDeliveryYear,
            _batchOwner
        );

        address _batchAddress = _createNewBatch(
            _uniqueIdentifier,
            string(
                abi.encodePacked(
                    "VPC-",
                    _projectId,
                    "-",
                    _commodityId,
                    "-",
                    _vintage,
                    "-",
                    _uniqueIdentifier
                )
            ),
            string(
                abi.encodePacked(
                    "VPC",
                    _projectId,
                    _commodityId,
                    _vintage,
                    _uniqueIdentifier
                )
            )
        );

        PlannedCredit(_batchAddress).mintPlannedCredits(
            _batchOwner,
            _batchSupply
        );

        batchDetails[_projectId][_commodityId][_batchAddress].push(
            BatchDetail(
                _projectId,
                _commodityId,
                _vintage,
                _batchURI,
                _uniqueIdentifier,
                _plannedDeliveryYear,
                _batchSupply,
                block.timestamp,
                _batchAddress,
                _batchOwner
            )
        );

        batchIndexList[_batchAddress] =
            batchDetails[_projectId][_commodityId][_batchAddress].length -
            1;

        _updateProjectCommodityBatchStorage(
            _projectId,
            _commodityId,
            _batchAddress
        );

        projectCommodityTotalSupply[_projectId][_commodityId] += _batchSupply;

        emit NewBatchCreated(
            _projectId,
            _commodityId,
            _vintage,
            _batchURI,
            _uniqueIdentifier,
            _plannedDeliveryYear,
            _batchSupply,
            block.timestamp,
            _batchAddress,
            _batchOwner
        );
    }

    /**
     * @notice updateBatchDetailDuringMintOrBurnMore Updates batch details when ever Planned Credits are minted/burned
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _amountToMintOrBurn Amount of tokens to mint/burn
     * @param _plannedCreditBatchAction Planned Credit batch actions
     * @param _batchId Batch Id
     */
    function updateBatchDetailDuringMintOrBurnMore(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _amountToMintOrBurn,
        uint8 _plannedCreditBatchAction,
        address _batchId
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        if (_plannedCreditBatchAction == uint(PlannedCreditTokenActions.Mint)) {
            _detail.batchSupply = _detail.batchSupply + _amountToMintOrBurn;
            _detail.lastUpdated = block.timestamp;
            projectCommodityTotalSupply[_projectId][
                _commodityId
            ] += _amountToMintOrBurn;
        } else if (
            _plannedCreditBatchAction == uint(PlannedCreditTokenActions.Burn)
        ) {
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
     * @param _plannedDeliveryYear Updated batch delivery year
     * @param _batchId Batch Id
     */
    function updateBatchDetailDuringPlannedDeliveryYearChange(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _plannedDeliveryYear,
        address _batchId
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        _detail.plannedDeliveryYear = _plannedDeliveryYear;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice updateBatchDetailDuringURIChange: Update the factory storage
     * @param _projectId Project Id
     * @param _commodityId Commodity Id
     * @param _batchURI Updated batch URI
     * @param _batchId Batch Id
     */
    function updateBatchDetailDuringURIChange(
        string calldata _projectId,
        string calldata _commodityId,
        string calldata _batchURI,
        address _batchId
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _batchIndex = batchIndexList[_batchId];
        BatchDetail storage _detail = batchDetails[_projectId][_commodityId][
            _batchId
        ][_batchIndex];
        _detail.batchURI = _batchURI;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice setPlannedCreditManagerContract Set's PlannedCreditManager contract
     * @param _plannedCreditManagerContract PlannedCredit contract address
     */
    function setPlannedCreditManagerContract(
        address _plannedCreditManagerContract
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        plannedCreditManagerContract = _plannedCreditManagerContract;
        grantRole(FACTORY_MANAGER_ROLE, _plannedCreditManagerContract);
    }

    /**
     * @notice grantRoleForBatch manager Roles For PlannedCredit Batch
     * @param _batchId Batch contract address
     * @param _address Address to grant role to
     */
    function grantManagerRoleForBatch(
        address _batchId,
        address _address
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        PlannedCredit(_batchId).grantRole(FACTORY_MANAGER_ROLE, _address);
    }

    /**
            @notice _checkBeforeMintNewBatch: Process different checks before minting new batch
            @dev Checking credibilty of arguments
            @param _projectId Project Id
            @param _commodityId Commodity Id
                        @param _batchURI Batch URI
                        @param _uniqueIdentifier Unique Identifier, will be used as salt
                                    @param _batchSupply Batch token supply
            @param _plannedDeliveryYear Delivery year
            @param _batchOwner Batch owner address
        */
    function _checkBeforeMintNewBatch(
        string memory _projectId,
        string memory _commodityId,
        string calldata _batchURI,
        string calldata _uniqueIdentifier,
        uint256 _batchSupply,
        uint256 _plannedDeliveryYear,
        address _batchOwner
    ) internal view {
        require(
            (address(plannedCreditManagerContract) != address(0)) &&
                (_batchOwner != address(0)) &&
                (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_batchSupply != 0) &&
                (_plannedDeliveryYear != 0) &&
                (bytes(_uniqueIdentifier).length != 0) &&
                bytes(_batchURI).length != 0,
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
            @notice createNewBatch: Create a new batch w.r.t projectId and commodityId
            @dev Follows factory-child pattern for creating batches using CREATE2 opcode
                    Child contract is going to be ERC20 compatible smart contract
            @param _salt Salt for CREATE2 opcode at assembly level
            @param _tokenName ERC20 based token name
            @param _tokenSymbol ERC20 based token symbol
        */
    function _createNewBatch(
        string calldata _salt,
        string memory _tokenName,
        string memory _tokenSymbol
    ) internal onlyRole(FACTORY_MANAGER_ROLE) returns (address) {
        require(
            address(plannedCreditManagerContract) != address(0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        require(bytes(_salt).length <= 32, "SALT_TOO_LONG");
        bytes32 _convertedSalt;
        bytes memory tempBytes = bytes(_salt);
        bytes32 tempResult;

        assembly {
            tempResult := mload(add(tempBytes, 32))
        }

        _convertedSalt = tempResult;

        PlannedCredit _newChildBatch = new PlannedCredit{
            salt: bytes32(_convertedSalt)
        }(
            _tokenName,
            _tokenSymbol,
            address(this),
            address(plannedCreditManagerContract)
        );
        return address(_newChildBatch);
    }

    /**
            @notice updateProjectCommodityBatchStorage: Updating batch storage for a 
                    project and commodity
            @param _projectId Project Id
            @param _commodityId Commodity Id
            @param _batchAddress Batch Id
        */
    function _updateProjectCommodityBatchStorage(
        string memory _projectId,
        string memory _commodityId,
        address _batchAddress
    ) private onlyRole(FACTORY_MANAGER_ROLE) {
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
}

/**
 * @title Planned Credit
 * @author Team @vericap
 * @notice Planned Credits are ERC20 based future credits for multiple commodities
 */

contract PlannedCredit is ERC20, AccessControl {
    bytes32 public constant FACTORY_MANAGER_ROLE =
        keccak256("FACTORY_MANAGER_ROLE");

    /**
            @notice BatchTransfer triggers when tokens are transferred in 
                    a batch
        */
    event BatchTransfer(
        address[] receiverAddresses,
        uint256[] amountToTransfer
    );

    /**
            @notice Building up the constructor
            @param _name Token name
            @param _symbol Token symbol
            @param _factoryContract Factory contract address
            @param _managerContract Manager contract address
            
        */
    constructor(
        string memory _name,
        string memory _symbol,
        address _factoryContract,
        address _managerContract
    ) ERC20(_name, _symbol) {
        _setRoleAdmin(FACTORY_MANAGER_ROLE, FACTORY_MANAGER_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, _factoryContract);
        _setupRole(FACTORY_MANAGER_ROLE, _factoryContract);
        _setupRole(FACTORY_MANAGER_ROLE, _managerContract);
    }

    /**
            @notice decimals: Standard ERC20 decimals
            @return uint8 returns ERC20 decimals
        */
    function decimals() public pure override returns (uint8) {
        return 5;
    }

    /**
            @notice mint: Standard ERC20's mint
            @dev Using ERC20's internal _mint function
            @param _account Account where tokens will get minted
            @param _amount Amount of tokens to be minted        
        */
    function mintPlannedCredits(
        address _account,
        uint256 _amount
    ) public onlyRole(FACTORY_MANAGER_ROLE) {
        _mint(_account, _amount);
    }

    /**
            @notice burn: Standard ERC20's burn
            @dev Using ERC20's internal _mint function
            @param _account Account from where tokens will get burned from
            @param _amount Amount of tokens to be burned
        */
    function burnPlannedCredits(
        address _account,
        uint256 _amount
    ) public onlyRole(FACTORY_MANAGER_ROLE) {
        _burn(_account, _amount);
    }
}
