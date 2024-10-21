// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

/**
 * @title Planned Credit Manager Contract
 * @author Team @vericap
 * @notice Planned Credit Manager is a upgradeable contract used for mananing PlannedCredits related actions
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
        @notice MintedMoreForAPlannedCredit: Triggers when credits are minted to a PlannedCredit
     */
    event MintedMoreForAPlannedCredit(
        string projectId,
        string commodityId,
        address planneCredit,
        address plannedCreditOwner,
        uint256 amountMinted,
        uint256 supply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice BurnedFromAPlannedCredit: Triggers when a some tokens are burned 
                from a PlannedCredit
     */
    event BurnedFromAPlannedCredit(
        string projectId,
        string commodityId,
        address plannedCredit,
        address plannedCreditOwner,
        uint256 amountToBurn,
        uint256 supply,
        uint256 projectCommodityTokenSupply
    );

    /**
        @notice ManyToManyPlannedCreditTransferred: Triggers on many-many PlannedCredit transfer 
     */
    event ManyToManyPlannedCreditTransferred(
        IERC20[] plannedCredits,
        address[] projectDeveloperAddresses,
        bytes[] transferredData
    );

    /**
        @notice PlannedDeliveryYearUpdated: Triggers when a PlannedCredit's delivery 
                year is updated
     */
    event PlannedDeliveryYearUpdated(
        string projectId,
        string commodityId,
        address plannedCredit,
        uint256 updatedPlannedDeliveryYear
    );

    /**
        @notice URIUpdated: Triggers when a PlannedCredit's URI is 
                updated
     */
    event URIUpdated(
        string projectId,
        string commodityId,
        address plannedCredit,
        string updatedURI
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
        @notice Initialize: Initializes a smart contract
        @dev Works as a constructor for proxy contracts
        @param superAdmin Admin wallet address
        @param plannedCreditFactory PlannedCreditFactory contract address
     */
    function initialize(
        address superAdmin,
        address plannedCreditFactory
    ) external initializer {
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _setupRole(MANAGER_ROLE, superAdmin);
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        plannedCreditFactoryContract = PlannedCreditFactory(
            plannedCreditFactory
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
        @notice mintPlannedCredits: Increase supply of a PlannedCredit by minting
        @dev Calls child PlannedCredit for mint more
                This will basically increase the supply of ERC20 contract
        @param projectId Associated Project
        @param commodityId Associated Commodity
        @param plannedCredit PlannedCredit reference
        @param plannedCreditOwner Planned credit owner
        @param amountToMint Amount of credis to mint
     */
    function mintPlannedCredits(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        address plannedCreditOwner,
        uint256 amountToMint
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            projectId,
            commodityId,
            plannedCreditOwner,
            amountToMint
        );
        plannedCreditFactoryContract
            .updatePlannedCreditDetailDuringMintOrBurnMore(
                projectId,
                commodityId,
                amountToMint,
                0,
                plannedCredit
            );
        IPlannedCredit(plannedCredit).mintPlannedCredits(
            plannedCreditOwner,
            amountToMint
        );

        uint256 _currentPlannedCreditSupply = plannedCreditFactoryContract
            .getPlannedCreditDetails(projectId, commodityId, plannedCredit)
            .supply;

        uint256 _currentTotalSupply = plannedCreditFactoryContract
            .getProjectCommodityTotalSupply(projectId, commodityId);

        emit MintedMoreForAPlannedCredit(
            projectId,
            commodityId,
            plannedCredit,
            plannedCreditOwner,
            amountToMint,
            _currentPlannedCreditSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice burnPlannedCredits: Decreasing supply of a PlannedCredit by burning
        @dev Calls child PlannedCredit for burn more
                This will basically increase the supply of ERC20 contract
        @param projectId Associated Project
        @param commodityId Associated Commodity
        @param plannedCredit PlannedCredit reference
        @param plannedCreditOwner Planned credit owner
        @param amountToBurn Amount of credits to burn
     */
    function burnPlannedCredits(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        address plannedCreditOwner,
        uint256 amountToBurn
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeMintMoreAndBurnMore(
            projectId,
            commodityId,
            plannedCreditOwner,
            amountToBurn
        );
        plannedCreditFactoryContract
            .updatePlannedCreditDetailDuringMintOrBurnMore(
                projectId,
                commodityId,
                amountToBurn,
                1,
                plannedCredit
            );
        IPlannedCredit(plannedCredit).burnPlannedCredits(
            plannedCreditOwner,
            amountToBurn
        );

        uint256 _currentPlannedCreditSupply = plannedCreditFactoryContract
            .getPlannedCreditDetails(projectId, commodityId, plannedCredit)
            .supply;

        uint256 _currentTotalSupply = plannedCreditFactoryContract
            .getProjectCommodityTotalSupply(projectId, commodityId);

        emit BurnedFromAPlannedCredit(
            projectId,
            commodityId,
            plannedCredit,
            plannedCreditOwner,
            amountToBurn,
            _currentPlannedCreditSupply,
            _currentTotalSupply
        );
    }

    /**
        @notice manyToManyPlannedCreditTransfer: Perform M2M PlannedCredit transfer from diferent Planned Credits 
                to different user from different project developers.
                Note: Approval mechanism should be performed prior to this functionality
        @param plannedCredits List of PlannedCredit references
        @param dataToTransfer receiver addresses and amounts to be encoded into bytes
        @dev Project developers needs to approve the PlannedCreditManager. 
             As, PlannedCreditManager will trigger the transfer function in PlannedCredit reference
     */
    function manyToManyPlannedCreditTransfer(
        IERC20[] calldata plannedCredits,
        address[] calldata projectDeveloperAddresses,
        bytes[] calldata dataToTransfer
    ) external onlyRole(MANAGER_ROLE) {
        require(
            (plannedCredits.length == projectDeveloperAddresses.length),
            "UNEVEN_ARGUMENTS_PASSED"
        );
        for (uint256 i = 0; i < plannedCredits.length; i++) {
            (
                address[] memory _receiverAddresses,
                uint256[] memory _amountToTransfer
            ) = abi.decode(dataToTransfer[i], (address[], uint256[]));
            require(
                _receiverAddresses.length == _amountToTransfer.length,
                "UNEVEN_ARGUMENTS_PASSED"
            );

            for (uint256 j = 0; j < _receiverAddresses.length; j++) {
                IERC20 plannedCredit = plannedCredits[i];
                plannedCredit.safeTransferFrom(
                    projectDeveloperAddresses[i],
                    _receiverAddresses[j],
                    _amountToTransfer[j]
                );
            }
        }

        emit ManyToManyPlannedCreditTransferred(
            plannedCredits,
            projectDeveloperAddresses,
            dataToTransfer
        );
    }

    /**
        @notice updatePlannedDeliveryYear: Update delivery year of PlannedCredit
        @param projectId Associated Project
        @param commodityId Associated Commodity
        @param plannedCredit PlannedCredit w.r.t to Project::Commodity
        @param updatedPlannedDeliveryYear Updated delivery year
     */
    function updatePlannedDeliveryYear(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        uint256 updatedPlannedDeliveryYear
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingPlannedCreditDetails(
            projectId,
            commodityId,
            plannedCredit
        );
        plannedCreditFactoryContract
            .updatePlannedCreditDetailDuringPlannedDeliveryYearChange(
                projectId,
                commodityId,
                updatedPlannedDeliveryYear,
                plannedCredit
            );

        emit PlannedDeliveryYearUpdated(
            projectId,
            commodityId,
            plannedCredit,
            updatedPlannedDeliveryYear
        );
    }

    /**
        @notice updateURI: Update URI for a PlannedCredit
        @param projectId Associated Project
        @param commodityId Associated Commodity
        @param plannedCredit PlannedCredit Id w.r.t to Project::Commodity
        @param updatedURI Updated URI
     */
    function updateURI(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        string calldata updatedURI
    ) external onlyRole(MANAGER_ROLE) {
        _checkBeforeUpdatingPlannedCreditDetails(
            projectId,
            commodityId,
            plannedCredit
        );
        plannedCreditFactoryContract.updatePlannedCreditDetailDuringURIChange(
            projectId,
            commodityId,
            updatedURI,
            plannedCredit
        );

        emit URIUpdated(projectId, commodityId, plannedCredit, updatedURI);
    }

    /**
     * @notice setFactoryManagerContract: Set's PlannedCreditFactory contract
     * @param plannedCreditFactory PlannedCreditFactory reference
     */
    function setFactoryManagerContract(
        address plannedCreditFactory
    ) external onlyRole(MANAGER_ROLE) {
        require(plannedCreditFactory != address(0), "ARGUMENT_PASSED_AS_ZERO");
        plannedCreditFactoryContract = PlannedCreditFactory(
            plannedCreditFactory
        );
    }

    /**
     * @notice _checkBeforeMintMoreAndBurnMore: Process different checks before mint/burn more
     * @param _projectId Associated Project
     * @param _commodityId Associated Commodity
     * @param _plannedCredit Planned Credit
     * @param _amountToMintOrBurn Amount to mint/burn
     */
    function _checkBeforeMintMoreAndBurnMore(
        string memory _projectId,
        string memory _commodityId,
        address _plannedCredit,
        uint256 _amountToMintOrBurn
    ) internal pure {
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_amountToMintOrBurn != 0) &&
                (_plannedCredit != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    /**
     * @notice _checkBeforeUpdatingPlannedCreditDetails: Process different checks before updating PlannedCredit detail
     * @param _projectId Associated Project
     * @param _commodityId Associated Commodity
     * @param _plannedCredit PlannedCredit reference
     */
    function _checkBeforeUpdatingPlannedCreditDetails(
        string memory _projectId,
        string memory _commodityId,
        address _plannedCredit
    ) internal pure {
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_plannedCredit != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }
}
