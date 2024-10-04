// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Verified Credit Factory Contract
 * @author Team @vericap
 * @notice Verified Credit Factory is a upgradeable contract used for releasing new VerifiedCredits
 */

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IPlannedCreditManager.sol";
import "../interfaces/IPlannedCreditFactory.sol";
import "hardhat/console.sol";

contract VerifiedCreditFactory is
    Initializable,
    ERC1155Upgradeable,
    ERC1155HolderUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    using Counters for Counters.Counter;

    /** @notice ERC1155 Token Indexer  */
    Counters.Counter private _currentIndex;

    /**
            @dev Inheriting StringsUpgradeable library for uint64
        */
    using StringsUpgradeable for uint64;

    /** @notice Factory Manager Role */
    bytes32 public constant FACTORY_MANAGER_ROLE = "FACTORY_MANAGER_ROLE";

    /**
     * @notice PlannedCredit's Factory and Manager Instances
     */
    IPlannedCreditFactory public plannedCreditFactory;
    IPlannedCreditManager public plannedCreditManager;

    /** @dev VerifiedPlannedCredits: Stores the properties for a Planned Credit
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Date of issuance
     * @param tokenId ERC1155 standarad based token Id
     * @param ticker Associated ticker based on Project::Commodity::Vintage
     * @param issuedCredits Supply of credits issued
     * @param availableCredits Available credits w.r.t Project::Commodity::Vintage
     * @param blockedCredits Blocked credits w.r.t Project::Commodity::Vintage
     * @param retiredCredits Retired credits w.r.t Project::Commodity::Vintage
     * @param tokenURI IPFS hosted URI link
     */
    struct VerifiedCreditDetail {
        string projectId;
        string commodityId;
        uint256 vintage;
        string issuanceDate;
        uint256 tokenId;
        string ticker;
        uint256 issuedCredits;
        uint256 availableCredits;
        uint256 blockedCredits;
        uint256 retiredCredits;
        string tokenURI;
    }

    /**
     * @dev VerifiedCreditDetailByTokenId: Stores tokenId for a VerifiedCredit along with issuance date
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param tokenId ERC1155 standarad based token Id
     */
    struct VerifiedCreditDetailByTokenId {
        string projectId;
        string commodityId;
        uint256 vintage;
        string issuanceDate;
        uint256 tokenId;
    }

    /**
     * @dev verifiedCreditDetails: Stores VerifiedCreditDetail w.r.t Project::Commodity::Vintage::IssuanceDate::TokenId
     */
    mapping(string => mapping(string => mapping(uint256 => mapping(string => VerifiedCreditDetail))))
        internal verifiedCreditDetails;

    /**
     * @dev verifiedCreditDetailsByVintage: Stores list of VerifiedCreditDetail w.r.t tokenId
     */
    mapping(uint256 => VerifiedCreditDetail[])
        internal verifiedCreditDetailsByVintage;

    /**
     * @dev verifiedCreditDetailsByTokenId: Stores VerifiedCreditDetailByTokenId w.r.t TokenId
     */
    mapping(uint256 => VerifiedCreditDetailByTokenId)
        internal verifiedCreditDetailsByTokenId;

    /**
     * @dev User's Verified Credit Balance
     * address => project => commodity => vintage => Issuance Date => tokenId => user Holding
     */
    mapping(address => mapping(string => mapping(string => mapping(uint256 => mapping(string => mapping(uint256 => uint256))))))
        internal usersBlockedHolding;

    /**
     * @dev creditsRetiredByUserPerVintage: Stores the total credits retired by a user w.r.t Project::Commodity::Vintage
     */
    mapping(string => mapping(string => mapping(uint256 => uint256)))
        public creditsRetiredByUserPerVintage;

    /**
     * @dev verifiedCreditExistance: Stores existance of a IssuanceDate w.r.t Project::Commodity::Vintage::IssuanceDate
     */
    mapping(string => mapping(string => mapping(uint256 => mapping(string => bool))))
        public verifiedCreditExistance;

    /**
     * @dev _tokenURIs: Stores tokenURI for all Verified Credits
     */
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev VerifiedCreditCreated: Triggers when a new VerifiedCredit is created
     */
    event VerifiedCreditCreated(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        string ticker,
        uint256 creditsIssued,
        string tokenURI
    );

    /**
     * @dev IssuedVerifiedCredit: Triggers when new credits are a issued for a particular pair of VerifiedCredits
     */
    event IssuedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 issuedSupply,
        uint256 availableCredits
    );

    /**
     * @dev BlockedVerifiedCredit: Triggers when credits are blocked for a pair of IssuanceDate::VerifiedCredits
     */
    event BlockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 blockedAmount,
        uint256 availableCredits,
        address account
    );

    /**
     * @dev UnblockedVerifiedCredit: Triggers when credits are unblocked for a pair of IssuanceDate::VerifiedCredits
     */
    event UnblockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 unBlockedAmount,
        uint256 availableCredits,
        address account
    );

    /**
     * @dev
     */
    event BurnedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 burnedSupply,
        uint256 availableCredits
    );

    /**
     * @dev SwappedVerifiedCredit: Triggers when credits are swapped for a pair of IssuanceDate::VerifiedCredits
     */
    event SwappedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 amountSwapped,
        address plannedCredit,
        address investorAddress
    );

    /**
     * @dev RetiredVerifiedCredit: Triggers when credits are Retired for a pair of IssuanceDate::VerifiedCredits
     */
    event RetiredVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 amountRetired,
        address investorAddress,
        uint256 availableCredits
    );

    /**
     * @dev URIUpdateForVerifiedCredit: Triggers when URI is updated for a pair of IssuanceDate::VerifiedCredits
     */
    event URIUpdateForVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        string updatedURI,
        uint256 lastUpdatedAt
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
    function initialize(
        address superAdmin,
        IPlannedCreditFactory _plannedCreditFactory,
        IPlannedCreditManager _plannedCreditManager
    ) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(FACTORY_MANAGER_ROLE, superAdmin);
        plannedCreditFactory = _plannedCreditFactory;
        plannedCreditManager = _plannedCreditManager;
    }

    /// @notice UUPS upgrade mandatory function: To authorize the owner to upgrade the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @notice getVerifiedCreditDetail: View function to fetch properties of a VerifiedCredit w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated Vintage
     * @param issuanceDate Associated IssuanceDate
     */
    function getVerifiedCreditDetail(
        string memory projectId,
        string memory commodityId,
        uint256 vintage,
        string memory issuanceDate
    ) public view returns (VerifiedCreditDetail memory) {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        return
            verifiedCreditDetails[projectId][commodityId][vintage][
                issuanceDate
            ];
    }

    /**
     * @notice getUserBalancePerIssuanceDate: View function to fetch user balance w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated Vintage
     * @param issuanceDate Associated IssuanceDate
     * @param userAccount User Wallet
     */
    function getUserBalancePerIssuanceDate(
        string memory projectId,
        string memory commodityId,
        uint256 vintage,
        string memory issuanceDate,
        address userAccount
    ) public view returns (uint256) {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];

        return balanceOf(userAccount, _verifiedCreditDetail.tokenId);
    }

    /**
     * @notice getAggregatedDataPerVintage: View function to fetch VerifiedCredit's data w.r.t Vintage
     */
    function getAggregatedDataPerVintage(
        uint256 vintage
    )
        public
        view
        returns (
            uint256 issuedCredits,
            uint256 availableCredits,
            uint256 blockedCredits,
            uint256 retiredCredits
        )
    {
        require(vintage != 0, "VINTAGE_PASSED_AS_ZERO");
        uint256 _verifiedCreditList = verifiedCreditDetailsByVintage[vintage]
            .length;
        for (uint256 i = 0; i < _verifiedCreditList; i++) {
            issuedCredits += verifiedCreditDetailsByVintage[vintage][i]
                .issuedCredits;
            availableCredits += verifiedCreditDetailsByVintage[vintage][i]
                .availableCredits;
            blockedCredits += verifiedCreditDetailsByVintage[vintage][i]
                .blockedCredits;
            retiredCredits += verifiedCreditDetailsByVintage[vintage][i]
                .retiredCredits;
        }

        return (
            issuedCredits,
            availableCredits,
            blockedCredits,
            retiredCredits
        );
    }

    /**
     * @notice createVerifiedCredit: Create a new PlannedCredit w.r.t Project::Commodity::Vintage::IssuanceDate
     * @dev Follows ERC1155 token standard fundamental to create VerifiedCredits
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param ticker Associated ticker based on Project::Commodity::Vintage
     * @param issuanceSupply Issuance supply
     * @param tokenURI IPFS hosted URI link
     */
    function createVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        string calldata ticker,
        uint256 issuanceSupply,
        string calldata tokenURI
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _tokenId = _getCurrentTokenIdIndex();
        _checkBeforeVerifiedCreditCreation(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            ticker,
            issuanceSupply,
            tokenURI
        );

        verifiedCreditDetails[projectId][commodityId][vintage][
            issuanceDate
        ] = VerifiedCreditDetail(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _tokenId,
            ticker,
            issuanceSupply,
            issuanceSupply,
            0,
            0,
            tokenURI
        );

        verifiedCreditDetailsByTokenId[
            _tokenId
        ] = VerifiedCreditDetailByTokenId(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _tokenId
        );

        verifiedCreditDetailsByVintage[vintage].push(
            VerifiedCreditDetail(
                projectId,
                commodityId,
                vintage,
                issuanceDate,
                _tokenId,
                ticker,
                issuanceSupply,
                issuanceSupply,
                0,
                0,
                tokenURI
            )
        );

        verifiedCreditExistance[projectId][commodityId][vintage][
            issuanceDate
        ] = true;

        _tokenURIs[_tokenId] = tokenURI;

        _mint(address(this), _tokenId, issuanceSupply, "0x00");

        emit VerifiedCreditCreated(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _tokenId,
            ticker,
            issuanceSupply,
            tokenURI
        );
    }

    /**
     * @notice issueVerifiedCredit: Issue verified credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param issuanceSupply Issuance supply
     */
    function issueVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 issuanceSupply
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            issuanceSupply
        );

        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        _verifiedCreditDetail.issuedCredits += issuanceSupply;
        _verifiedCreditDetail.availableCredits += issuanceSupply;

        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .issuedCredits += issuanceSupply;
        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .availableCredits += issuanceSupply;

        _mint(
            address(this),
            _verifiedCreditDetail.tokenId,
            issuanceSupply,
            "0x00"
        );

        emit IssuedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            issuanceSupply,
            _verifiedCreditDetail.availableCredits
        );
    }

    /**
     * @notice blockVerifiedCredits: Block verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param amountToBlock Amount of credits to block
     */
    function blockVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToBlock,
        address account
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToBlock
        );
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        require(
            amountToBlock <= _verifiedCreditDetail.availableCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );
        _verifiedCreditDetail.blockedCredits += amountToBlock;
        _verifiedCreditDetail.availableCredits -= amountToBlock;

        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .blockedCredits += amountToBlock;
        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .availableCredits -= amountToBlock;

        usersBlockedHolding[account][projectId][commodityId][vintage][
            issuanceDate
        ][_verifiedCreditDetail.tokenId] += amountToBlock;

        emit BlockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToBlock,
            _verifiedCreditDetail.availableCredits,
            account
        );
    }

    /**
     * @notice unblockVerifiedCredits: Unblock verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param amountToUnblock Amount of credits to unblock
     */
    function unblockVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToUnblock,
        address account
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToUnblock
        );
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        require(
            amountToUnblock <= _verifiedCreditDetail.blockedCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );
        _verifiedCreditDetail.blockedCredits -= amountToUnblock;
        _verifiedCreditDetail.availableCredits += amountToUnblock;

        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .blockedCredits -= amountToUnblock;
        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .availableCredits += amountToUnblock;

        usersBlockedHolding[account][projectId][commodityId][vintage][
            issuanceDate
        ][_verifiedCreditDetail.tokenId] -= amountToUnblock;

        emit UnblockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToUnblock,
            _verifiedCreditDetail.availableCredits,
            account
        );
    }

    // burn Verified credit
    function burnVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 issuanceSupply
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            issuanceSupply
        );

        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        _verifiedCreditDetail.issuedCredits -= issuanceSupply;
        _verifiedCreditDetail.availableCredits -= issuanceSupply;

        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .issuedCredits -= issuanceSupply;
        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .availableCredits -= issuanceSupply;

        _burn(address(this), _verifiedCreditDetail.tokenId, issuanceSupply);

        emit BurnedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            issuanceSupply,
            _verifiedCreditDetail.availableCredits
        );
    }

    /**
     * @notice transferVerifiedCreditOutside: Transfer verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param amountToTransfer Amount of credits to transfer
     * @param receiver Receiver wallet
     */
    function transferVerifiedCreditOutside(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToTransfer,
        address receiver
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        require(
            amountToTransfer <= _verifiedCreditDetail.availableCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );
        safeTransferFrom(
            address(this),
            receiver,
            _verifiedCreditDetail.tokenId,
            amountToTransfer,
            "0x00"
        );
    }

    /**
     * @notice approveAdminToTransfer: Approve admin to access Verified Credit available in contract
     * @param admin Admin wallet
     */
    function approveAdminToTransfer(
        address admin
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        require(admin != address(0), "ARGUMENT_TYPE_INVALID");
        _setApprovalForAll(address(this), admin, true);
    }

    /**
     * @notice swapVerifiedCredits: Swap verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param amountToSwap Amount of credits to swap
     * @param investor Investor wallet
     */
    function swapVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToSwap,
        address plannedCredit,
        address investor
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeSwap(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToSwap,
            plannedCredit,
            investor
        );

        IPlannedCreditFactory.PlannedCreditDetailByAddress
            memory _plannedCreditDetail = plannedCreditFactory
                .getPlannedCreditDetailsByAddress(plannedCredit);

        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];

        require(
            amountToSwap <= _verifiedCreditDetail.availableCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );

        require(
            compareCreditDetail(
                _plannedCreditDetail.projectId,
                _verifiedCreditDetail.projectId
            ) &&
                compareCreditDetail(
                    _plannedCreditDetail.commodityId,
                    _verifiedCreditDetail.commodityId
                ) &&
                (_plannedCreditDetail.vintage == _verifiedCreditDetail.vintage),
            "PLANNED_CREDIT_NOT_MATCH_VERIFIED_CREDIT"
        );

        require(
            amountToSwap <= _verifiedCreditDetail.availableCredits,
            "AMOUNT_EXCEED_AVAILABLE_CREDIT"
        );

        plannedCreditManager.burnPlannedCredits(
            projectId,
            commodityId,
            plannedCredit,
            investor,
            amountToSwap
        );

        _safeTransferFrom(
            address(this),
            investor,
            _verifiedCreditDetail.tokenId,
            amountToSwap,
            "0x00"
        );

        emit SwappedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToSwap,
            plannedCredit,
            investor
        );
    }

    /**
     * @notice retireVerifiedCredits: Retire verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param amountToRetire Amount of credits to swap
     * @param investor Investor wallet
     */
    function retireVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToRetire,
        address investor
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeRetire(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToRetire,
            investor
        );
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];

        _verifiedCreditDetail.retiredCredits += amountToRetire;
        _verifiedCreditDetail.availableCredits -= amountToRetire;

        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .retiredCredits += amountToRetire;
        verifiedCreditDetailsByVintage[vintage][_verifiedCreditDetail.tokenId]
            .availableCredits -= amountToRetire;

        creditsRetiredByUserPerVintage[projectId][commodityId][
            vintage
        ] += amountToRetire;
        _burn(investor, _verifiedCreditDetail.tokenId, amountToRetire);

        emit RetiredVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToRetire,
            investor,
            _verifiedCreditDetail.availableCredits
        );
    }

    /**
     * @notice updateVerifiedCreditURI: Update URI for a verified Credits w.r.t Project::Commodity::Vintage::IssuanceDate
     * @param projectId Associated project
     * @param commodityId Associated commodity
     * @param vintage Associated vintage to the planned credit
     * @param issuanceDate Associated IssuanceDate
     * @param updatedURI IPFS hostes URI link
     */
    function updateVerifiedCreditURI(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        string calldata updatedURI
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(bytes(updatedURI).length != 0, "EMPTY_URI_PASSED");
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        _verifiedCreditDetail.tokenURI = updatedURI;

        emit URIUpdateForVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            updatedURI,
            block.timestamp
        );
    }

    /**
            @notice _checkBeforeVerifiedCreditCreation: Process different checks before creating new VerifiedCredits
            @dev Checking credibilty of arguments
        */
    function _checkBeforeVerifiedCreditCreation(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        string calldata _issuanceDate,
        string calldata _ticker,
        uint256 _issuanceSupply,
        string calldata _tokenURI
    ) internal view onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            !verifiedCreditExistance[_projectId][_commodityId][_vintage][
                _issuanceDate
            ],
            "CREDIT_ENTRY_ALREADY_EXIST"
        );
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_vintage != 0) &&
                (bytes(_issuanceDate).length != 0) &&
                (bytes(_ticker).length != 0) &&
                (_issuanceSupply != 0) &&
                (bytes(_tokenURI).length != 0),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    /**
            @notice _checkBeforeStorageUpdate: Process different checks before updating storage of VerifiedCredits
            @dev Checking credibilty of arguments
        */
    function _checkBeforeStorageUpdate(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        string calldata _issuanceDate,
        uint256 _issuanceSupply
    ) internal view {
        require(
            verifiedCreditExistance[_projectId][_commodityId][_vintage][
                _issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_vintage != 0) &&
                (bytes(_issuanceDate).length != 0) &&
                (_issuanceSupply != 0),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    /**
            @notice _checkBeforeSwap: Process different checks before swapping VerifiedCredits
            @dev Checking credibilty of arguments
        */
    function _checkBeforeSwap(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        string calldata _issuanceDate,
        uint256 _amountToSwap,
        address _plannedCredit,
        address _investorAddress
    ) internal view {
        require(
            verifiedCreditExistance[_projectId][_commodityId][_vintage][
                _issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_vintage != 0) &&
                (bytes(_issuanceDate).length != 0) &&
                (_amountToSwap != 0) &&
                (_plannedCredit != address(0)) &&
                (_investorAddress != address(0)),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    /**
            @notice _checkBeforeRetire: Process different checks before retiring VerifiedCredits
            @dev Checking credibilty of arguments
        */
    function _checkBeforeRetire(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        string calldata _issuanceDate,
        uint256 _amountToRetire,
        address _investorAddress
    ) internal view {
        require(
            verifiedCreditExistance[_projectId][_commodityId][_vintage][
                _issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(_projectId).length != 0) &&
                (bytes(_commodityId).length != 0) &&
                (_vintage != 0) &&
                (bytes(_issuanceDate).length != 0) &&
                (_amountToRetire != 0) &&
                (_investorAddress != address(0)),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    /**
     * @notice _getCurrentTokenIdIndex: Get current indexer for tokenIds
     */
    function _getCurrentTokenIdIndex() internal view returns (uint256) {
        return _currentIndex.current();
    }

    /**
     * @notice _beforeTokenTransfer: Overriding inherited function from ERC1155 token standard
     *          Added internal checks for handing VerifiedCredits storage
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        // If minting (from == address(0)), allow without any restrictions
        if (from == address(0)) {
            // Minting logic, no restrictions for blocked or retired tokens
            super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
            return;
        }

        // If not minting, apply checks for blocking, retiring, etc.
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 tokenId = ids[i];
            VerifiedCreditDetailByTokenId
                memory _verifiedCreditDetailById = verifiedCreditDetailsByTokenId[
                    tokenId
                ];

            uint256 _blockedHolding = usersBlockedHolding[from][
                _verifiedCreditDetailById.projectId
            ][_verifiedCreditDetailById.commodityId][
                _verifiedCreditDetailById.vintage
            ][_verifiedCreditDetailById.issuanceDate][tokenId];

            // Ensure that the transferable supply is not exceeded
            require(
                _blockedHolding < amounts[i],
                "AMOUNT_EXCEED_AVAILABLE_CREDITS"
            );
        }

        // Call the parent hook for transfers
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @notice supportsInterface: Override riding base, to make it compatible with inherited contracts
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC1155Upgradeable,
            ERC1155ReceiverUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice compareCreditDetail: Internal tool to compare PlannedCredits details with VerifiedCredits
     */
    function compareCreditDetail(
        string memory dataX,
        string memory dataY
    ) internal pure returns (bool) {
        return
            keccak256(abi.encodePacked(dataX)) ==
            keccak256(abi.encodePacked(dataY));
    }
}
