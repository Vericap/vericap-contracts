// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPCCManager {
    function mintNewBatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchOwner,
        uint256 _batchSupply,
        uint256 _deliveryYear,
        string calldata _deliveryEstimate,
        string calldata _batchURI,
        uint256 _uniqueIdentifier
    ) external;

    function mintMoreInABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToMint,
        address _receiverAddress
    ) external;

    function burnFromABatch(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _amountToBurn,
        address _ownerAddress
    ) external;

    function manyToManyBatchTransfer(
        address[] calldata _batchIds,
        address[] calldata _userAddresses,
        uint256[] calldata _amountToTransfer
    ) external;

    function updateBatchDeliveryYear(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        uint256 _updatedDeliveryYear
    ) external;

    function updateBatchDetailDuringVinatgeChange(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        string calldata _updatedDeliveryEstimate
    ) external;

    function updateBatchURI(
        uint256 _projectId,
        uint256 _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external;
}
