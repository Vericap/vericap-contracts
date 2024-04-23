// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract PCCFactoryAbstract {
    struct BatchDetail {
        address batchId;
        address batchOwner;
        string deliveryEstimates;
        string batchURI;
        uint256 uniqueIdentifier;
        uint256 projectId;
        uint256 commodityId;
        uint256 deliveryYear;
        uint256 batchSupply;
        uint256 lastUpdated;
    }

        /**
     * @dev Creating ENUM for handling PCC batch actions
     * @dev Mint - 0
     * @dev Burn - 1
     */
    enum PCCTokenActions {
        Mint,
        Burn
    }

        /**
            @dev batchDetails: Stores BatchDetail w.r.t projectId and commodityId
        */
    mapping(uint256 => mapping(uint256 => mapping(address => BatchDetail[])))
        internal batchDetails;

    /** 
            @dev commodityList: Stores commodities w.r.t projectIds
        */
    mapping(uint256 => uint256[]) internal commodityList;
}
