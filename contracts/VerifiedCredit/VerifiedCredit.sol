// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract VerifiedCreditFactory is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721AUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant VCC_MANAGER_ROLE = "VCC_MANAGER_ROLE";

    struct VerifiedCreditDetail {
        string projectId;
        string commodityId;
        string URI;
        uint256 vintage;
        uint256 deliveryYear;
        uint256[] uniqueIds;
        uint256 currentSupply;
        uint256 markedToOffset;
        uint256 markedToBlocked;
    }

    // projectId -> commodityId -> Vintage -> Verified Credit Detail
    mapping(string => mapping(string => mapping(uint256 => VerifiedCreditDetail)))
        public verifiedCreditDetails;

    // projectId -> commodityId -> Vintage -> User Address -> UniqueIds
    mapping(string => mapping(string => mapping(uint256 => mapping(address => uint256[]))))
        public userBalancePerVintage;

    mapping(uint256 => bool) public verifiedCreditOffsetStatus;

    mapping(uint256 => bool) public verifiedCreditBlockStatus;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _adminAddress
    ) public initializerERC721A initializer {
        __ERC721A_init("Verified Carbon Credit", "VVC");
        __Ownable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(VCC_MANAGER_ROLE, _adminAddress);
    }

    /// @notice UUPS upgrade mandatory function: To authorize the owner to upgrade the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function getVerifiedCreditDetail(
        string memory _projectId,
        string memory _commodityId,
        uint256 _vintage
    ) public view returns (VerifiedCreditDetail memory) {
        return verifiedCreditDetails[_projectId][_commodityId][_vintage];
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721AUpgradeable) returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length != 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return _tokenURIs[tokenId];
    }

    function createVerfiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        string calldata _uri,
        uint256 _vintage,
        uint256 _deliveryYear,
        uint256 _initialSupply
    ) external onlyRole(VCC_MANAGER_ROLE) {
        /**
         * Required checks
         * 1. Args
         */
        uint256 _startIndex = ERC721AStorage.layout()._currentIndex;
        uint256 _endIndex = _startIndex + _initialSupply - 1; // Adjusted to be inclusive
        uint256[] memory _uniqueIds = _getIndexRange(_startIndex, _endIndex);

        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];

        // Add the new token IDs to the uniqueIds array
        for (uint256 i = 0; i < _uniqueIds.length; i++) {
            _vccDetail.uniqueIds.push(_uniqueIds[i]);

            // Update the user balance for the initial owner (the contract)
            userBalancePerVintage[_projectId][_commodityId][_vintage][
                address(this)
            ].push(_uniqueIds[i]);
        }

        _vccDetail.projectId = _projectId;
        _vccDetail.commodityId = _commodityId;
        _vccDetail.URI = _uri;
        _vccDetail.vintage = _vintage;
        _vccDetail.deliveryYear = _deliveryYear;
        _vccDetail.currentSupply += _initialSupply;
        _vccDetail.markedToOffset = 0;
        _vccDetail.markedToBlocked = 0;

        _safeMint(address(this), _initialSupply);

        /**
         * Emit Event
         */
    }

    function mintVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        uint256 _amountToMint
    ) external onlyRole(VCC_MANAGER_ROLE) {
        /**
         * Required checks
         * 1. Args
         */
        uint256 _startIndex = ERC721AStorage.layout()._currentIndex;
        uint256 _endIndex = _startIndex + _amountToMint - 1; // Adjusted to be inclusive
        uint256[] memory _uniqueIds = _getIndexRange(_startIndex, _endIndex);

        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];

        // Add the new token IDs to the uniqueIds array
        for (uint256 i = 0; i < _uniqueIds.length; i++) {
            _vccDetail.uniqueIds.push(_uniqueIds[i]);

            // Update the user balance for the initial owner (the contract)
            userBalancePerVintage[_projectId][_commodityId][_vintage][
                address(this)
            ].push(_uniqueIds[i]);
        }

        _vccDetail.currentSupply += _amountToMint;

        _safeMint(address(this), _amountToMint);

        /**
         * Emit Event
         */
    }

    function burnVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        uint256 _amountToBurn,
        address _user
    ) public onlyRole(VCC_MANAGER_ROLE) {
        /**
         * Required checks
         * 1. Args
         */
        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];
        uint256[] storage userTokens = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_user];
        uint256 userSupply = userTokens.length;
        require(
            _amountToBurn <= userSupply,
            "BURN_AMOUNT_EXCEEDS_USER_BALANCE"
        );

        _vccDetail.currentSupply -= _amountToBurn;

        // Burn the specified number of tokens starting from the beginning of the user's list
        for (uint256 i = 0; i < _amountToBurn; i++) {
            uint256 tokenId = userTokens[i];
            _burn(tokenId);
        }

        // Rearrange the user's token list by removing the burned tokens
        for (uint256 i = _amountToBurn; i < userSupply; i++) {
            userTokens[i - _amountToBurn] = userTokens[i];
        }

        // Reduce the length of the array to remove the trailing elements
        for (uint256 i = 0; i < _amountToBurn; i++) {
            userTokens.pop();
        }

        // Reduce the length of the array to remove the trailing elements
        for (uint256 i = 0; i < _amountToBurn; i++) {
            _vccDetail.uniqueIds.pop();
        }

        /**
         * Emit Event
         */
    }

    // Transfer VCC
    function transferVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyRole(VCC_MANAGER_ROLE) {
        // Fetch the user's balance of uniqueIds
        uint256[] storage fromBalance = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_from];
        require(fromBalance.length >= _amount, "INSUFFICIENT_BALANCE");

        // Fetch the recipient's balance of uniqueIds
        uint256[] storage toBalance = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_to];

        // Transfer the specified amount of tokens
        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = fromBalance[i];

            // Perform the transfer using the internal ERC721A transfer function
            safeTransferFrom(_from, _to, tokenId, "");

            // Update the toBalance with the tokenId
            toBalance.push(tokenId);
        }

        // Remove the transferred tokens from the fromBalance
        for (uint256 i = 0; i < _amount; i++) {
            fromBalance[i] = fromBalance[fromBalance.length - 1];
            fromBalance.pop();
        }

        /**
         * Emit Event
         */
        // You can emit an event here to log the transfer if needed
    }

    // SWAP
    function swapVPCWithVCC(
        string calldata _projectId,
        string calldata _commodityId,
        address _vpcAddress,
        uint256 _vintage,
        uint256 _amountToSwap
    ) external onlyRole(VCC_MANAGER_ROLE) {
        /**
         * require checks
         * 1. Args
         * 2. amount > 0
         */
        IERC20 _vpc = IERC20(_vpcAddress);
        require(
            _vpc.allowance(msg.sender, address(this)) > _amountToSwap,
            "LOW_ALLOWANCE"
        );
        // Check if the contract has enough ERC721 tokens to transfer
        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];
        require(
            _vccDetail.uniqueIds.length >= _amountToSwap,
            "INSUFFICIENT_VERIFIED_CREDITS"
        );
        _vpc.transferFrom(msg.sender, address(this), _amountToSwap);

        for (uint256 i = 0; i < _amountToSwap; i++) {
            uint256 tokenId = _vccDetail.uniqueIds[i];
            safeTransferFrom(address(this), msg.sender, tokenId, "");
        }

        /** Burn VPC token */
    }

    // Mark Offset (can not be accessed post offset)
    function markVerifiedCreditOffset(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        uint256 _amountToOffset,
        address _user
    ) external onlyRole(VCC_MANAGER_ROLE) {
        // Retrieve the VerifiedCreditDetail struct for the given project, commodity, and vintage
        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];

        uint256[] storage userTokens = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_user];

        // Ensure the amount to offset does not exceed the current supply
        require(
            userTokens.length >= _amountToOffset,
            "OFFSET_AMOUNT_EXCEEDS_SUPPLY"
        );

        for (uint256 i = 0; i < _amountToOffset; i++) {
            uint256 tokenId = userTokens[i];
            require(!verifiedCreditOffsetStatus[tokenId], "MARKED_OFFSET");

            // Mark the token as offset
            verifiedCreditOffsetStatus[tokenId] = true;
        }

        // Update the markedToOffset field
        _vccDetail.markedToOffset += _amountToOffset;

        // Emit an event for the offset
    }

    // Block Verified Credit (Can be unblocked)
    function blockVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        uint256 _amountToBlock,
        address _userAddress
    ) external onlyRole(VCC_MANAGER_ROLE) {
        // Retrieve the VerifiedCreditDetail struct for the given project, commodity, and vintage
        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];
        uint256[] storage userTokens = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_userAddress];

        require(userTokens.length > 0, "INSUFFICIENT_VERIFIED_CREDIT");
        require(
            _amountToBlock <= userTokens.length,
            "AMOUNT_EXCEED_USER_BALANCE"
        );

        for (uint256 i = 0; i < _amountToBlock; i++) {
            uint256 tokenId = userTokens[i];
            require(_exists(tokenId), "VERIFIED_CREDIT_NOT_EXIST");
            require(!verifiedCreditBlockStatus[tokenId], "ALREADY_BLOCKED");

            verifiedCreditBlockStatus[tokenId] = true;
        }

        _vccDetail.markedToBlocked += _amountToBlock;

        // emit event
    }

    // Unblock VCC
    function unblockVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        address _userAddress,
        uint256 _amountToUnblock
    ) external onlyRole(VCC_MANAGER_ROLE) {
        // Retrieve the VerifiedCreditDetail struct for the given project, commodity, and vintage
        VerifiedCreditDetail storage _vccDetail = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];

        uint256[] storage userTokens = userBalancePerVintage[_projectId][
            _commodityId
        ][_vintage][_userAddress];

        require(
            userTokens.length > 0,
            "User has no tokens for specified criteria"
        );
        require(
            _amountToUnblock <= userTokens.length,
            "Amount exceeds user's token balance"
        );

        uint256 unblockedCount = 0;

        for (
            uint256 i = 0;
            i < userTokens.length && unblockedCount < _amountToUnblock;
            i++
        ) {
            uint256 tokenId = userTokens[i];

            if (verifiedCreditBlockStatus[tokenId]) {
                verifiedCreditBlockStatus[tokenId] = false;
                unblockedCount += 1;
            }
        }

        require(unblockedCount == _amountToUnblock, "NOT_ENOUGH_TO_UNBLOCK");

        // Update the markedToOffset field
        _vccDetail.markedToBlocked += _amountToUnblock;
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.VCC_MANAGER_ROLE
     */
    function _setTokenURI(
        uint256 tokenId,
        string memory _tokenURI
    ) internal virtual {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function _getIndexRange(
        uint256 _startIndex,
        uint256 _endIndex
    ) private pure returns (uint256[] memory) {
        require(_endIndex >= _startIndex, "END_INDEX_SHOULD_BE_GREATER");

        uint256 length;

        if (_startIndex == 1) {
            length = _endIndex - _startIndex + 1;
        } else {
            length = _endIndex - _startIndex;
            _startIndex += 1; // Make startIndex exclusive
        }
        uint256[] memory result = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = _startIndex + i;
        }
        return result;
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        // Call the super function to maintain standard behavior
        super._beforeTokenTransfers(from, to, tokenId, 1);

        require(!verifiedCreditBlockStatus[tokenId], "MARKED_BLOCK");

        // Check if the token is marked as offset
        require(!verifiedCreditOffsetStatus[tokenId], "MARKED_OFFSET");
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721AUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
