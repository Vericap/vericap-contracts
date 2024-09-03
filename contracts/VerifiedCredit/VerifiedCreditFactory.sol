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
        uint256 blockedCredits;
        uint256 availableCredits;
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

    // Vintage -> Verified Credit Detail []
    mapping(uint256 => VerifiedCreditDetail[])
        internal verifiedCreditDetailsByVintage;

    mapping(uint256 => VerifiedCreditDetailByTokenId)
        internal verifiedCreditDetailsByTokenId;

    // User address -> token Id -> Amount
    mapping(address => mapping(uint256 => uint256))
        internal creditRetiredByUser;

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
        address investorAddress
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

    function initialize(address _superAdmin) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _superAdmin);
        _grantRole(FACTORY_MANAGER_ROLE, _superAdmin);
    }

    /// @notice UUPS upgrade mandatory function: To authorize the owner to upgrade the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /** User Balance */
    function getUserBalancePerVintage(
        string memory projectId,
        string memory commodityId,
        uint256 vintage,
        string memory issuanceDate,
        address userAccount
    ) public view returns (uint256) {
        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];

        return balanceOf(userAccount, _verifiedCreditDetail.tokenId);
    }

    // Get aggregated detail of a verified credit based on same vintage;

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
            0,
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
                0,
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
        VerifiedCreditDetail
            storage _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        _verifiedCreditDetail.issuedCredits += issuanceSupply;
        _verifiedCreditDetail.availableCredits += issuanceSupply;

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
        _checkBeforeSwapAndRetire(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToSwap,
            plannedCredit,
            investorAddress
        );

        IPlannedCreditFactory.PlannedCreditDetailByAddress
            memory _plannedCreditDetail = IPlannedCreditFactory(plannedCredit)
                .getPlannedCreditDetailsByAddress(plannedCredit);

        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];

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

        IPlannedCreditManager(plannedCredit).burnFromABatch(
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
        VerifiedCreditDetail
            memory _verifiedCreditDetail = verifiedCreditDetails[projectId][
                commodityId
            ][vintage][issuanceDate];
        _verifiedCreditDetail.retiredCredits += amountToRetire;
        _verifiedCreditDetail.availableCredits -= amountToRetire;
        creditRetiredByUser[investorAddress][
            _verifiedCreditDetail.tokenId
        ] += amountToRetire;
        _burn(investorAddress, _verifiedCreditDetail.tokenId, amountToRetire);

        emit RetiredVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            issuanceDate,
            amountToRetire,
            investorAddress
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
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    function _checkBeforeStorageUpdate(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 issuanceSupply
    ) internal pure {
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (issuanceSupply != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    function _checkBeforeSwapAndRetire(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        string calldata issuanceDate,
        uint256 amountToSwap,
        address plannedCredit,
        address investorAddress
    ) internal pure {
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (bytes(issuanceDate).length != 0) &&
                (amountToSwap != 0) &&
                (plannedCredit != address(0)) &&
                (investorAddress != address(0)),
            "ARGUMENT_PASSED_AS_ZERO"
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
