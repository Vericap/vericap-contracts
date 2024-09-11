// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/**
 * @title Planned Credit Factory Smart Contract
 * @author Team @vericap
 * @notice Planned Credit Factory is a upgradeable contract used for releasing new PlannedCredit
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
            @dev Inheriting StringsUpgradeable library for uint64
        */
    using StringsUpgradeable for uint64;

    /**
     * @dev Global declaration of plannedCreditManager contract
     */
    address public plannedCreditManagerContract;

    /**
            @dev projectIds: Storing project Ids in an array
        */
    string[] internal projectIds;

    /**
     * @notice Define FACTORY_MANAGER_ROLE
     */

    bytes32 public constant FACTORY_MANAGER_ROLE =
        keccak256("FACTORY_MANAGER_ROLE");

    /**
     * @dev Creating ENUM for handling PlannedCredit actions
     * @dev Mint - 0
     * @dev Burn - 1
     */
    enum PlannedCreditTokenActions {
        Mint,
        Burn
    }
    /**
     * @dev PlannedCreditDetail: Stores the properties for a Planned Credit
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param uri IPFS hosted URI link
     * @param plannedDeliveryYear Planned delivery of the credits associated with the vintage
     * @param supply Supply of credits (Amount minted)
     * @param lastUpdated Timestamp for latest changes in the properties of the planned credit
     * @param vintage Associated vintage to the planned credit
     * @param plannedCredit Planned credit smart contract reference
     * @param plannedCreditOwner Planned credit owner
     */
    struct PlannedCreditDetail {
        string projectId;
        string commodityId;
        string uri;
        uint256 plannedDeliveryYear;
        uint256 supply;
        uint256 lastUpdated;
        uint64 vintage;
        address plannedCredit;
        address plannedCreditOwner;
    }

    /**
     * @dev PlannedCreditDetailByAddress: Stores Project-Commodity-Vinatge-Planned Credit Reference
     * @param projectId Associated project Id
     * @param commodityId Associated commodity Id
     * @param vintage Associated vintage to the planned credit
     * @param plannedCredit Planned credit smart contract reference
     */
    struct PlannedCreditDetailByAddress {
        string projectId;
        string commodityId;
        uint256 vintage;
        address plannedCredit;
    }

    /**
     * @dev plannedCreditDetails: Stores PlannedCreditDetail w.r.t Project::Commodity::PlannedCredit refrence
     */
    mapping(string => mapping(string => mapping(address => PlannedCreditDetail[])))
        internal plannedCreditDetails;

    /**
     * @dev plannedCreditDetailsByAddress: Stores PlannedCreditDetailByAddress w.r.t PlannedCredit reference
     */
    mapping(address => PlannedCreditDetailByAddress)
        internal plannedCreditDetailsByAddress;

    /** 
            @dev commodityList: Stores Commodities w.r.t ProjectId
        */
    mapping(string => string[]) internal commodityList;

    /**
            @dev plannedCreditIndexList: Planned Credit Indexer, associating each PlannedCredit with a index value
        */
    mapping(address => uint256) internal plannedCreditIndexList;

    /**
            @dev plannedCreditList: Stores list of PlannedCredits w.r.t Project::Commodity
        */
    mapping(string => mapping(string => address[])) internal plannedCreditList;

    /**
            @dev projectCommodityTotalSupply: Stores total supply of a Project::Commodity
        */
    mapping(string => mapping(string => uint256))
        internal projectCommodityTotalSupply;

    /**
     * @dev commodityIdExists: Checks for duplication of Project::Commodity
     */
    mapping(string => mapping(string => bool)) internal commodityExists;

    /**
     * @dev projectIdExists: Checks for duplication of Project
     */
    mapping(string => bool) internal projectExists;

    /**
     * @dev vintageExists: Check for vintage duplication for a Project::Commodity pair
     */
    mapping(string => mapping(string => mapping(uint64 => bool)))
        public vintageExists;

    /**
            @notice PlannedCreditCreated: Triggers when a new PlannedCredit contract is created
        */
    event PlannedCreditCreated(
        string projectId,
        string commodityId,
        string uri,
        uint256 plannedDeliveryYear,
        uint256 supply,
        uint256 lastUpdated,
        uint64 vintage,
        address plannedCredit,
        address plannedCreditOwner,
        string name
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
            @notice Initialize: Initialize a smart contract
            @dev Works as a constructor for proxy contracts
            @param superAdmin Admin wallet address
        */
    function initialize(address superAdmin) external initializer {
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _setupRole(FACTORY_MANAGER_ROLE, superAdmin);
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
            @param projectId Project
            @param commodityId Commodity
            @return Total supply for a Project::Commodity
        */
    function getProjectCommodityTotalSupply(
        string calldata projectId,
        string calldata commodityId
    ) public view returns (uint256) {
        return projectCommodityTotalSupply[projectId][commodityId];
    }

    /**
            @notice getProjectList: View function to fetch the list of projects
            @return List of Projects 
        */
    function getProjectList() public view returns (string[] memory) {
        return projectIds;
    }

    /**
            @notice getCommodityListForAProject: View function to fetch list of 
                    commodities w.r.t a projectId
            @param projectId Project Id
            @return List of commodities for a project
        */
    function getCommodityListForAProject(
        string calldata projectId
    ) public view returns (string[] memory) {
        string[] memory _commodityList = new string[](
            commodityList[projectId].length
        );
        for (uint256 i = 0; i < commodityList[projectId].length; ) {
            _commodityList[i] = commodityList[projectId][i];

            unchecked {
                ++i;
            }
        }

        return _commodityList;
    }

    /**
            @notice getPlannedCreditListForACommodityInAProject: View function to fetch 
                    list of Planned Credits w.r.t Project::Commodity
            @param projectId Project Id
            @param commodityId Commodity Id
            @return List of Planned Credits
        */
    function getPlannedCreditListForACommodityInAProject(
        string calldata projectId,
        string calldata commodityId
    ) public view returns (address[] memory) {
        address[] memory _plannedCreditList = new address[](
            plannedCreditList[projectId][commodityId].length
        );
        for (
            uint256 i = 0;
            i < plannedCreditList[projectId][commodityId].length;

        ) {
            _plannedCreditList[i] = plannedCreditList[projectId][commodityId][
                i
            ];
            unchecked {
                ++i;
            }
        }

        return _plannedCreditList;
    }

    /**
            @notice getPlannedCreditDetails: View function to fetch properties of a PlannedCredit w.r.t Project::Commodity::PlannedCredit
            @param projectId Associated Project
            @param commodityId Associated Commodity
            @param plannedCredit PlannedCredit (struct)
        */
    function getPlannedCreditDetails(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit
    ) external view returns (PlannedCreditDetail memory) {
        return
            plannedCreditDetails[projectId][commodityId][plannedCredit][
                plannedCreditIndexList[plannedCredit]
            ];
    }

    /**
     * @notice getPlannedCreditDetailsByAddress: View function to fetch properties of a PlannedCredit w.r.t PlannedCredit reference
     */
    function getPlannedCreditDetailsByAddress(
        address plannedCredit
    ) external view returns (PlannedCreditDetailByAddress memory) {
        return plannedCreditDetailsByAddress[plannedCredit];
    }

    /**
            @notice createPlannedCredit: Create a new PlannedCredit w.r.t Project::Commodity::Vintage
            @dev Follows factory-child pattern for creating PlannedCredits using CREATE2 opcode
                    Child contract is going to be ERC20 compatible smart contract
            @param projectId Associated project
            @param commodityId Associated commodity
            @param uri IPFS hosted URI link
            @param plannedDeliveryYear Planned delivery of the credits associated with the vintage
            @param supply Supply of credits (Amount minted)
            @param vintage Associated vintage to the planned credit
            @param plannedCreditOwner Planned credit owner
        */
    function createPlannedCredit(
        string calldata projectId,
        string calldata commodityId,
        string calldata uri,
        uint256 plannedDeliveryYear,
        uint256 supply,
        uint64 vintage,
        address plannedCreditOwner
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeCreatePlannedCredit(
            projectId,
            commodityId,
            uri,
            supply,
            plannedDeliveryYear,
            vintage,
            plannedCreditOwner
        );

        require(
            vintageExists[projectId][commodityId][vintage] == false,
            "VINTAGE_ALREADY_EXIST"
        );

        address _plannedCredit = _createPlannedCredit(
            string(
                abi.encodePacked(
                    "VPC-",
                    projectId,
                    "-",
                    commodityId,
                    "-",
                    vintage.toString()
                )
            ),
            string(
                abi.encodePacked(
                    "VPC",
                    projectId,
                    commodityId,
                    vintage.toString()
                )
            ),
            vintage
        );

        vintageExists[projectId][commodityId][vintage] = true;

        PlannedCredit(_plannedCredit).mintPlannedCredits(
            plannedCreditOwner,
            supply
        );

        plannedCreditDetails[projectId][commodityId][_plannedCredit].push(
            PlannedCreditDetail(
                projectId,
                commodityId,
                uri,
                plannedDeliveryYear,
                supply,
                block.timestamp,
                vintage,
                _plannedCredit,
                plannedCreditOwner
            )
        );

        plannedCreditDetailsByAddress[
            _plannedCredit
        ] = PlannedCreditDetailByAddress(
            projectId,
            commodityId,
            vintage,
            plannedCreditOwner
        );

        plannedCreditIndexList[_plannedCredit] =
            plannedCreditDetails[projectId][commodityId][_plannedCredit]
                .length -
            1;

        _updateProjectCommodityPlanneCreditStorage(
            projectId,
            commodityId,
            _plannedCredit
        );

        projectCommodityTotalSupply[projectId][commodityId] += supply;

        string memory _name = PlannedCredit(_plannedCredit).name();

        emit PlannedCreditCreated(
            projectId,
            commodityId,
            uri,
            plannedDeliveryYear,
            supply,
            block.timestamp,
            vintage,
            _plannedCredit,
            plannedCreditOwner,
            _name
        );
    }

    /**
     * @notice updatePlannedCreditDetailDuringMintOrBurnMore: Updates properties when a PlannedCredit's supply is updated
     * @param projectId Associated Project
     * @param commodityId Associated Commodity
     * @param amountToMintOrBurn Amount w.r.t to mint/burn action
     * @param action Action to mint/burn
     * @param plannedCredit PlannedCredit reference
     */
    function updatePlannedCreditDetailDuringMintOrBurnMore(
        string calldata projectId,
        string calldata commodityId,
        uint256 amountToMintOrBurn,
        uint8 action,
        address plannedCredit
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _plannedCreditIndex = plannedCreditIndexList[plannedCredit];
        PlannedCreditDetail storage _detail = plannedCreditDetails[projectId][
            commodityId
        ][plannedCredit][_plannedCreditIndex];
        if (action == uint(PlannedCreditTokenActions.Mint)) {
            _detail.supply += amountToMintOrBurn;
            _detail.lastUpdated = block.timestamp;
            projectCommodityTotalSupply[projectId][
                commodityId
            ] += amountToMintOrBurn;
        } else if (action == uint(PlannedCreditTokenActions.Burn)) {
            _detail.supply -= amountToMintOrBurn;
            _detail.lastUpdated = block.timestamp;
            projectCommodityTotalSupply[projectId][
                commodityId
            ] -= amountToMintOrBurn;
        }
    }

    /**
     * @notice updatePlannedCreditDetailDuringPlannedDeliveryYearChange: Updates properties when a PlannedCredit's storage is updated
     * @param projectId Associated Project
     * @param commodityId Associated Commodity
     * @param plannedDeliveryYear  Planned delivery of the credits associated with the vintage
     * @param plannedCredit Planned credit reference
     */
    function updatePlannedCreditDetailDuringPlannedDeliveryYearChange(
        string calldata projectId,
        string calldata commodityId,
        uint256 plannedDeliveryYear,
        address plannedCredit
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _plannedCreditIndex = plannedCreditIndexList[plannedCredit];
        PlannedCreditDetail storage _detail = plannedCreditDetails[projectId][
            commodityId
        ][plannedCredit][_plannedCreditIndex];
        _detail.plannedDeliveryYear = plannedDeliveryYear;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice updatePlannedCreditDetailDuringURIChange: Updates PlannedCredit details when a Planned Credit's URI is updated
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param uri IPFS hosted URI link
     * @param plannedCredit PlannedCredit reference
     */
    function updatePlannedCreditDetailDuringURIChange(
        string calldata projectId,
        string calldata commodityId,
        string calldata uri,
        address plannedCredit
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _plannedCreditIndex = plannedCreditIndexList[plannedCredit];
        PlannedCreditDetail storage _detail = plannedCreditDetails[projectId][
            commodityId
        ][plannedCredit][_plannedCreditIndex];
        _detail.uri = uri;
        _detail.lastUpdated = block.timestamp;
    }

    /**
     * @notice setPlannedCreditManagerContract: Set's PlannedCreditManager contract
     * @param _plannedCreditManagerContract PlannedCreditManager reference
     */
    function setPlannedCreditManagerContract(
        address _plannedCreditManagerContract
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            _plannedCreditManagerContract != address(0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
        plannedCreditManagerContract = _plannedCreditManagerContract;
        grantRole(FACTORY_MANAGER_ROLE, _plannedCreditManagerContract);
    }

    /**
     * @notice grantManagerRoleForPlannedCredit: Grant manager Roles For PlannedCredit
     * @param plannedCredit PlannedCredit reference
     * @param manager Manager wallet address
     */
    function grantManagerRoleForPlannedCredit(
        address plannedCredit,
        address manager
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        PlannedCredit(plannedCredit).grantRole(FACTORY_MANAGER_ROLE, manager);
    }

    /**
            @notice _checkBeforeCreatePlannedCredit: Process different checks before minting new PlannedCredit
            @dev Checking credibilty of arguments
        */
    function _checkBeforeCreatePlannedCredit(
        string memory _projectId,
        string memory _commodityId,
        string calldata _uri,
        uint256 _supply,
        uint256 _plannedDeliveryYear,
        uint64 _vintage,
        address _plannedCreditOwner
    ) internal view {
        require(
            (address(plannedCreditManagerContract) != address(0)) &&
                (_plannedCreditOwner != address(0)) &&
                (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (bytes(_uri).length != 0) &&
                (_supply != 0) &&
                (_plannedDeliveryYear != 0) &&
                (_vintage != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
            @notice _createPlannedCredit: Create a new PlannedCredit w.r.t projectId and commodityId
            @dev Follows factory-child pattern for creating PlannedCredit using CREATE2 opcode
                    Child contract is going to be ERC20 compatible smart contract
            @param _tokenName ERC20 based token name
            @param _tokenSymbol ERC20 based token symbol
            @param _vintage PlannedCredit vintage to be served as unique salt
        */
    function _createPlannedCredit(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint64 _vintage
    ) internal onlyRole(FACTORY_MANAGER_ROLE) returns (address) {
        require(
            address(plannedCreditManagerContract) != address(0),
            "ARGUMENT_PASSED_AS_ZERO"
        );

        uint256 _vintage256 = uint256(_vintage);
        bytes32 _salt = bytes32(_vintage256);

        PlannedCredit _newChildPlannedCredit = new PlannedCredit{
            salt: bytes32(_salt)
        }(
            _tokenName,
            _tokenSymbol,
            address(this),
            address(plannedCreditManagerContract)
        );
        return address(_newChildPlannedCredit);
    }

    /**
            @notice _updateProjectCommodityPlanneCreditStorage: Updating PlannedCredit storage for Project::Commodity
        */
    function _updateProjectCommodityPlanneCreditStorage(
        string memory _projectId,
        string memory _commodityId,
        address _plannedCredit
    ) private onlyRole(FACTORY_MANAGER_ROLE) {
        // Checking for project Id duplication
        if (projectExists[_projectId] == false) {
            projectIds.push(_projectId);
            projectExists[_projectId] = true;
        }

        // Checking for commodity Id duplication
        if (commodityExists[_projectId][_commodityId] == false) {
            commodityList[_projectId].push(_commodityId);
            commodityExists[_projectId][_commodityId] = true;
        }

        plannedCreditList[_projectId][_commodityId].push(_plannedCredit);
    }
}

/**
 * @title Planned Credit
 * @author Team @vericap
 * @notice Planned Credits are ERC20 based future credits for multiple commodities
 */

contract PlannedCredit is ERC20, AccessControl {
    /**
     * @notice Define FACTORY_MANAGER_ROLE
     */
    bytes32 public constant FACTORY_MANAGER_ROLE =
        keccak256("FACTORY_MANAGER_ROLE");

    /**
            @notice Building up the constructor
            @param name Token name
            @param symbol Token symbol
            @param factoryContract PlannedCreditFactory contract reference
            @param managerContract PlannedCreditManager contract reference
        */
    constructor(
        string memory name,
        string memory symbol,
        address factoryContract,
        address managerContract
    ) ERC20(name, symbol) {
        _setRoleAdmin(FACTORY_MANAGER_ROLE, FACTORY_MANAGER_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, factoryContract);
        _setupRole(FACTORY_MANAGER_ROLE, factoryContract);
        _setupRole(FACTORY_MANAGER_ROLE, managerContract);
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
            @param account Account for which tokens will get minted
            @param amount Amount of tokens to be minted        
        */
    function mintPlannedCredits(
        address account,
        uint256 amount
    ) public onlyRole(FACTORY_MANAGER_ROLE) {
        _mint(account, amount);
    }

    /**
            @notice burn: Standard ERC20's burn
            @dev Using ERC20's internal _burn function
            @param account Account from where tokens will get burned
            @param amount Amount of tokens to be burned
        */
    function burnPlannedCredits(
        address account,
        uint256 amount
    ) public onlyRole(FACTORY_MANAGER_ROLE) {
        _burn(account, amount);
    }
}
