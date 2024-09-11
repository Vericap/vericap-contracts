// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPlannedCreditManager {
    function mintPlannedCredits(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        address plannedCreditOwner,
        uint256 amountToMint
    ) external;

    function burnPlannedCredits(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        address plannedCreditOwner,
        uint256 amountToBurn
    ) external;

    function manyToManyPlannedCreditTransfer(
        IERC20[] calldata plannedCredits,
        address[] calldata projectDeveloperAddresses,
        bytes[] calldata dataToTransfer
    ) external;

    function updatePlannedDeliveryYear(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        uint256 updatedPlannedDeliveryYear
    ) external;

    function updateURI(
        string calldata projectId,
        string calldata commodityId,
        address plannedCredit,
        string calldata updatedURI
    ) external;
}
