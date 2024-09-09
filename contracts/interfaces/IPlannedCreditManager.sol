// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlannedCreditManager {
    function mintPlannedCredits(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToMint
    ) external;

    function burnPlannedCredits(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        address _batchOwner,
        uint256 _amountToBurn
    ) external;

    function manyToManyPlannedCreditTransfer(
        IERC20[] calldata _batchTokenIds,
        address[] calldata _projectDeveloperAddresses,
        bytes[] calldata _batchTransferData
    ) external;

    function updatePlannedDeliveryYear(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        uint256 _updatedPlannedDeliveryYear
    ) external;

    function updateURI(
        string calldata _projectId,
        string calldata _commodityId,
        address _batchId,
        string calldata _updatedURI
    ) external;
}
