// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

interface IAdrenalineSwapCallee {
    function AdrenalineSwapCall(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external;
}
