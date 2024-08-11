// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
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
    }

    mapping(string => mapping(string => mapping(uint256 => VerifiedCreditDetail)))
        public verifiedCreditDetails;

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

    function mintVerfiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        string calldata _uri,
        uint256 _vintage,
        uint256 _deliveryYear,
        uint256 _mintSupply
    ) external onlyRole(VCC_MANAGER_ROLE) {
        /**
         * Required checks
         */
        uint256 _startIndex = ERC721AStorage.layout()._currentIndex;
        uint256 _endIndex = _startIndex + _mintSupply;
        uint256[] memory _uniqueIds = _getIndexRange(_startIndex, _endIndex);
        uint256 _currentSupply = verifiedCreditDetails[_projectId][
            _commodityId
        ][_vintage].currentSupply;
        uint256 _updateSupply = _currentSupply + _mintSupply;
        verifiedCreditDetails[_projectId][_commodityId][
            _vintage
        ] = VerifiedCreditDetail(
            _projectId,
            _commodityId,
            _uri,
            _vintage,
            _deliveryYear,
            _uniqueIds,
            _updateSupply
        );
        _safeMint(address(this), _mintSupply);

        /**
         * Emit Event
         */
    }

    function burnVerifiedCredit(
        string calldata _projectId,
        string calldata _commodityId,
        uint256 _vintage,
        uint256 _amountToBurn
    ) external onlyRole(VCC_MANAGER_ROLE) {
        /**
         * Required checks
         */
        VerifiedCreditDetail storage _details = verifiedCreditDetails[
            _projectId
        ][_commodityId][_vintage];
        uint256 _supply = _details.uniqueIds.length;
        require(_amountToBurn <= _supply, "BURN_AMOUNT_EXCEEDS_SUPPLY");

        // Burn the specified number of tokens starting from the beginning of the list
        for (uint256 i = 0; i < _amountToBurn; i++) {
            uint256 tokenId = _details.uniqueIds[i];
            _burn(tokenId);
        }

        // Rearrange the list by removing the burned tokens
        for (uint256 i = _amountToBurn; i < _supply; i++) {
            _details.uniqueIds[i - _amountToBurn] = _details.uniqueIds[i];
        }

        // Reduce the length of the array to remove the trailing elements
        for (uint256 i = 0; i < _amountToBurn; i++) {
            _details.uniqueIds.pop();
        }

        /**
         * Emit Event
         */
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

        uint256 length = _endIndex - _startIndex + 1;
        uint256[] memory result = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            result[i] = _startIndex + i;
        }
        return result;
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
