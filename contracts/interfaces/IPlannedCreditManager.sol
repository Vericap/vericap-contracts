// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlannedCreditManager {

    function mintMoreInABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToMint,
        address _batchOwner
    ) external;

    function burnFromABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToBurn,
        address _batchOwner
    ) external;

    function manyToManyBatchTransfer(
        IERC20[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external;

    function updateBatchPlannedDeliveryYear(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _updatedPlannedDeliveryYear
    ) external;

    function updateBatchURI(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external;
}
