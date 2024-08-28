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
    mapping(string => mapping(string => mapping(uint256 => VerifiedCreditDetail)))
        public verifiedCreditDetails;

    // projectId -> commodityId -> Vintage -> boolean (existance)
    mapping(string => mapping(string => mapping(uint256 => bool)))
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
        uint256 issuedCredits
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
        address _userAccount
    ) public view returns (uint256) {
        VerifiedCreditDetail memory _credit = verifiedCreditDetails[_projectId][
            _commodityId
        ][_vintage];

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
        _checkBeforeVerifiedCreditCreation(
            projectId,
            commodityId,
            URI,
            vintage,
            deliveryYear,
            issuanceSupply
        );

        uint256 _tokenId = _getCurrentTokenIdIndex();
        verifiedCreditDetails[projectId][commodityId][
            vintage
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

        verifiedCreditExistance[projectId][commodityId][vintage] = true;

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

    function issueVerifiedCredit(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 issuanceSupply
    ) external onlyRole(FACTORY_MANAGER_ROLE) {
        _checkBeforeIssueAndCancel(
            projectId,
            commodityId,
            vintage,
            issuanceSupply
        );
        VerifiedCreditDetail storage _creditDetail = verifiedCreditDetails[
            projectId
        ][commodityId][vintage];
        _creditDetail.issuedCredits += issuanceSupply;

        _mint(address(this), _creditDetail.tokenId, issuanceSupply, "0x00");

        emit IssuedVerifiedCredit(
            projectId,
            commodityId,
            vintage,
            _creditDetail.tokenId,
            issuanceSupply,
            _creditDetail.issuedCredits
        );
    }

    function _checkBeforeVerifiedCreditCreation(
        string calldata projectId,
        string calldata commodityId,
        string calldata URI,
        uint256 vintage,
        uint256 deliveryYear,
        uint256 issuanceSupply
    ) internal view onlyRole(FACTORY_MANAGER_ROLE) {
        require(
            !verifiedCreditExistance[projectId][commodityId][vintage],
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

    function _checkBeforeIssueAndCancel(
        string calldata projectId,
        string calldata commodityId,
        uint256 vintage,
        uint256 issuanceSupply
    ) internal {
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
