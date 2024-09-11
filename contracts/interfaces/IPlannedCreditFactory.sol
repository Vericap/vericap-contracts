// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPlannedCreditFactory {
    struct PlannedCreditDetailByAddress {
        string projectId;
        string commodityId;
        uint256 vintage;
        address plannedCreditAddress;
    }

    function getPlannedCreditDetailsByAddress(
        address plannedCreditAddress
    ) external view returns (PlannedCreditDetailByAddress memory);
}
