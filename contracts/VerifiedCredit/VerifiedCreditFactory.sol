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

    bytes32 public constant FACTORY_MANAGER_ROLE = "FACTORY_MANAGER_ROLE";

    // Define the counter for token IDs
    Counters.Counter private _currentIndex;

    struct VerifiedCreditDetail {
        string projectId;
        string commodityId;
        string URI;
        uint256 vintage;
        uint256 tokenId;
        uint256 deliveryYear;
        uint256 issuedCredits; // Credits issued so far for this vintage
        uint256 cancelledCredits; // Amount of credits burned (during validation stage DONE by VVB)
        uint256 blockedCredits; // Blocked for some external reason
        uint256 availableCredits; // Verified - (Cancelled + blocked)
        uint256 retiredCredits; // Credit marked to offset
    }

    // projectId -> commodityId -> Vintage -> Verified Credit Detail
    mapping(string => mapping(string => mapping(uint256 => mapping(uint256 => VerifiedCreditDetail))))
        public verifiedCreditDetails;

    // projectId -> commodityId -> Vintage -> boolean (existance)
    mapping(string => mapping(string => mapping(uint256 => mapping(uint256 => bool))))
        public verifiedCreditExistance;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Create Verified Credit Event
    event VerifiedCreditCreated(
        string projectId,
        string commodityId,
        string URI,
        uint256 vintage,
        uint256 tokenId,
        uint256 deliveryYear,
        uint256 issuedCredits
    );

    // Issued Verified Credit Event
    event IssuedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 issuedSupply,
        uint256 availableCredits
    );

    // Block Verified Credit Event
    event BlockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 blockedAmount,
        uint256 availableCredits
    );

    // Unblock Verified Credit Event
    event UnblockedVerifiedCredit(
        string projectId,
        string commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 unBlockedAmount,
        uint256 availableCredits
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
        string memory _projectId,
        string memory _commodityId,
        uint256 _vintage,
        uint256 _tokenId,
        address _userAccount
    ) public view returns (uint256) {
        VerifiedCreditDetail memory _credit = verifiedCreditDetails[_projectId][
            _commodityId
        ][_vintage][_tokenId];

        return balanceOf(_userAccount, _credit.tokenId);
    }

    /** Create Verified Credit */
    function createVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        string calldata URI,
        uint256 vintage,
        uint256 deliveryYear,
        uint256 issuanceSupply
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        uint256 _tokenId = _getCurrentTokenIdIndex();
        _checkBeforeVerifiedCreditCreation(
            projectId,
            commodityId,
            URI,
            vintage,
            _tokenId,
            deliveryYear,
            issuanceSupply
        );

        verifiedCreditDetails[projectId][commodityId][vintage][
            _tokenId
        ] = VerifiedCreditDetail(
            projectId,
            commodityId,
            URI,
            vintage,
            _tokenId,
            deliveryYear,
            issuanceSupply,
            0,
            0,
            0,
            0
        );

        verifiedCreditExistance[projectId][commodityId][vintage][
            _tokenId
        ] = true;

        _tokenURIs[_tokenId] = URI;

        _mint(address(this), _tokenId, issuanceSupply, "0x00");

        emit VerifiedCreditCreated(
            projectId,
            commodityId,
            URI,
            vintage,
            _tokenId,
            deliveryYear,
            issuanceSupply
        );
    }

    /** Issue Verified Credits */
    function issueVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 issuanceSupply
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            issuanceSupply
        );
        VerifiedCreditDetail storage _creditDetail = verifiedCreditDetails[
            projectId
        ][commodityId][vintage][tokenId];
        _creditDetail.issuedCredits += issuanceSupply;
        _creditDetail.availableCredits += issuanceSupply;

        _mint(address(this), _creditDetail.tokenId, issuanceSupply, "0x00");

        emit IssuedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            _creditDetail.tokenId,
            issuanceSupply,
            _creditDetail.availableCredits
        );
    }

    /** Block Verified Credits */
    function blockVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 amountToBlock
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            amountToBlock
        );
        VerifiedCreditDetail storage _creditDetail = verifiedCreditDetails[
            projectId
        ][commodityId][vintage][tokenId];
        require(
            amountToBlock <= _creditDetail.availableCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );
        _creditDetail.blockedCredits += amountToBlock;
        _creditDetail.availableCredits -= amountToBlock;

        emit BlockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            tokenId,
            amountToBlock,
            _creditDetail.availableCredits
        );
    }

    /** Unblock Verfied Creditts */
    /** Block Verified Credits */
    function unBlockVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 tokenId,
        uint256 amountToUnblock
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeStorageUpdate(
            projectId,
            commodityId,
            vintage,
            amountToUnblock
        );
        VerifiedCreditDetail storage _creditDetail = verifiedCreditDetails[
            projectId
        ][commodityId][vintage][tokenId];
        require(
            amountToUnblock <= _creditDetail.blockedCredits,
            "INSUFFICIENT_CREDIT_SUPPLY"
        );
        _creditDetail.blockedCredits -= amountToUnblock;
        _creditDetail.availableCredits += amountToUnblock;

        emit UnblockedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            tokenId,
            amountToUnblock,
            _creditDetail.availableCredits
        );
    }

    /** Cancel Verified Credits */
    function cancelVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 amountToCancel
    ) external onlyRole(FACTORY_MANAGER_ROLE) {}

    /** Swap And Retire Verified Credits */
    function swapAndRetireVerifiedCredits(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 amountToSwap,
        address investorAddress
    ) external onlyRole(FACTORY_MANAGER_ROLE) {}

    function _checkBeforeVerifiedCreditCreation(
        string calldata projectId,
        string calldata commodityId,
        string calldata URI,
        uint256 vintage,
        uint256 tokenId,
        uint256 deliveryYear,
        uint256 issuanceSupply
    ) internal view onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            !verifiedCreditExistance[projectId][commodityId][vintage][tokenId],
            "CREDIT_ENTRY_ALREADY_EXIST"
        );
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (bytes(URI).length != 0) &&
                (vintage != 0) &&
                (deliveryYear != 0) &&
                (issuanceSupply != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    function _checkBeforeStorageUpdate(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 issuanceSupply
    ) internal pure {
        require(
            (bytes(projectId).length != 0) &&
                (bytes(commodityId).length != 0) &&
                (vintage != 0) &&
                (issuanceSupply != 0),
            "ARGUMENT_PASSED_AS_ZERO"
        );
    }

    function _getCurrentTokenIdIndex() internal view returns (uint256) {
        return _currentIndex.current();
    }

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

    function _beforeTokenTransfer() external {}
}
