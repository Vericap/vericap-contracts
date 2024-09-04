// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    /** @notice Factory Manager Role: Handles All Major Functionalities */
    bytes32 public constant FACTORY_MANAGER_ROLE = "FACTORY_MANAGER_ROLE";

    IPlannedCreditFactory public plannedCreditFactory;

    IPlannedCreditManager public plannedCreditManager;

    /** @notice Verifies Credit Detail
     * @dev Holds The Verfied Credit Properties */
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

    // Verified Credit Detail By Token Id
    struct VerifiedCreditDetailByTokenId {
        string projectId;
        string commodityId;
        uint256 vintage;
        string issuanceDate;
        uint256 tokenId;
    }

    // projectId -> commodityId -> Vintage -> Issuance Date -> Token Id -> Verified Credit Detail
    mapping(string => mapping(string => mapping(uint256 => mapping(string => VerifiedCreditDetail))))
        internal verifiedCreditDetails;

    // Vintage -> TokenId -> Verified Credit Detail []
    mapping(uint256 => VerifiedCreditDetail[])
        internal verifiedCreditDetailsByVintage;

    mapping(uint256 => VerifiedCreditDetailByTokenId)
        internal verifiedCreditDetailsByTokenId;

    // User projectId -> commodityId -> vintage -> total credit retired
    mapping(string => mapping(string => mapping(uint256 => uint256)))
        public creditsRetiredByUserPerVintage;

    // projectId -> commodityId -> Vintage -> Issuance Date -> boolean (existance)
    mapping(string => mapping(string => mapping(uint256 => mapping(string => bool))))
        public verifiedCreditExistance;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Create Verified Credit Event
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

    // Issued Verified Credit Event
    event IssuedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 issuedSupply,
        uint256 availableCredits
    );

    // Block Verified Credit Event
    event BlockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 blockedAmount,
        uint256 availableCredits
    );

    // Unblock Verified Credit Event
    event UnblockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 tokenId,
        uint256 unBlockedAmount,
        uint256 availableCredits
    );

    // Swapped Verfied Credit Event
    event SwappedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 amountSwapped,
        address plannedCredit,
        address investorAddress
    );

    // Retired Verfied Credit Event
    event RetiredVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        uint256 amountRetired,
        address investorAddress,
        uint256 availableCredits
    );

    // URI Updated For Verified Credit
    event URIUpdateForVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        string issuanceDate,
        string updatedURI
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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

    /** Get Verified Credit Detail */
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

    /** User Balance */
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

    /** Aggregated Verfied Credit Detail Per Vintage */
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

    /** Create Verified Credit */
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

    /** Issue Verified Credits */
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

    /** Block Verified Credits */
    function blockVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToBlock
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

        emit BlockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToBlock,
            _verifiedCreditDetail.availableCredits
        );
    }

    /** Unblock Verfied Credits */
    function unBlockVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToUnblock
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

        emit UnblockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            _verifiedCreditDetail.tokenId,
            amountToUnblock,
            _verifiedCreditDetail.availableCredits
        );
    }

    /** Transfer Verified Credit Outside */
    function transferVerifiedCreditOutside(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToTransfer,
        address userAddress
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
            userAddress,
            _verifiedCreditDetail.tokenId,
            amountToTransfer,
            "0x00"
        );
    }

    /** Approve Admin To Transfer Verified Credits */
    function approveAdminToTransfer(
        address admin
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        require(admin != address(0), "ARGUMENT_TYPE_INVALID");
        _setApprovalForAll(address(this), admin, true);
    }

    /** Swap Verified Credits */
    function swapVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToSwap,
        address plannedCredit,
        address investorAddress
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeSwap(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToSwap,
            plannedCredit,
            investorAddress
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

        plannedCreditManager.burnFromABatch(
            projectId,
            commodityId,
            plannedCredit,
            investorAddress,
            amountToSwap
        );

        _safeTransferFrom(
            address(this),
            investorAddress,
            _verifiedCreditDetail.tokenId,
            amountToSwap,
            "0x00"
        );

        emit SwappedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToSwap,
            plannedCredit,
            investorAddress
        );
    }

    /** Retire Verified Credits */
    function retireVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToRetire,
        address investorAddress
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeRetire(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToRetire,
            investorAddress
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
        _burn(investorAddress, _verifiedCreditDetail.tokenId, amountToRetire);

        emit RetiredVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToRetire,
            investorAddress,
            _verifiedCreditDetail.availableCredits
        );
    }

    /* Update Verified Credit URI */
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
            updatedURI
        );
    }

    function _checkBeforeVerifiedCreditCreation(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        string calldata ticker,
        uint256 issuanceSupply,
        string calldata tokenURI
    ) internal view onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            !verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_ALREADY_EXIST"
        );
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (bytes(ticker).length != 0) &&
                (issuanceSupply != 0) &&
                (bytes(tokenURI).length != 0),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    function _checkBeforeStorageUpdate(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 issuanceSupply
    ) internal view {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (issuanceSupply != 0),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    function _checkBeforeSwap(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToSwap,
        address plannedCredit,
        address investorAddress
    ) internal view {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (amountToSwap != 0) &&
                (plannedCredit != address(0)) &&
                (investorAddress != address(0)),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    function _checkBeforeRetire(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToRetire,
        address investorAddress
    ) internal view {
        require(
            verifiedCreditExistance[projectId][commodityId][vintage][
                issuanceDate
            ],
            "CREDIT_ENTRY_DOES_NOT_EXIST"
        );
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (amountToRetire != 0) &&
                (investorAddress != address(0)),
            "ARGUMENT_TYPE_INVALID"
        );
    }

    function _getCurrentTokenIdIndex() internal view returns (uint256) {
        return _currentIndex.current();
    }

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

            VerifiedCreditDetail
                memory _verifiedCreditDetail = verifiedCreditDetails[
                    _verifiedCreditDetailById.projectId
                ][_verifiedCreditDetailById.commodityId][
                    _verifiedCreditDetailById.vintage
                ][_verifiedCreditDetailById.issuanceDate];

            // Ensure that the transferable supply is not exceeded
            require(
                amounts[i] <= _verifiedCreditDetail.availableCredits,
                "AMOUNT_EXCEED_AVAILABLE_CREDITS"
            );
        }

        // Call the parent hook for transfers
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _fetchVerifiedCreditDetailById(
        uint256 tokenId
    ) internal view returns (uint256) {}

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

    function compareCreditDetail(
        string memory dataX,
        string memory dataY
    ) internal pure returns (bool) {
        return
            keccak256(abi.encodePacked(dataX)) ==
            keccak256(abi.encodePacked(dataY));
    }

    function _beforeTokenTransfer() external {}
}
