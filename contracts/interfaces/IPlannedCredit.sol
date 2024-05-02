// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IPlannedCredit {
    function mintPlannedCredits(address _account, uint256 _amount) external;

    function burnPlannedCredits(address _account, uint256 _amount) external;
}
