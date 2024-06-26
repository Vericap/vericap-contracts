// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILiquidityToken {
    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}
