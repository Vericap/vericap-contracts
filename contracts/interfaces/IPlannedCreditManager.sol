// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlannedCreditManager {
    function mintMoreInABatch(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToMint
    ) external;

    function burnFromABatch(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToBurn
    ) external;

    function manyToManyBatchTransfer(
        IERC20[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external;

    function updateBatchPlannedDeliveryYear(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        uint256 _updatedPlannedDeliveryYear
    ) external;

    function updateBatchURI(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external;
}
