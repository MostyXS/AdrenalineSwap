// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

interface IAdrenalineSwapFactory {
    function pairs(address, address) external pure returns (address);

    function createPair(address, address) external returns (address);
}
