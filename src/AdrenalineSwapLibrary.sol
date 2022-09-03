// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

import "./interfaces/IAdrenalineSwapFactory.sol";
import "./interfaces/IAdrenalineSwapPair.sol";
import {AdrenalineSwapPair} from "./AdrenalineSwapPair.sol";

library AdrenalineSwapLibrary {
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InvalidPath();

    //Returns the remaining reserves of pool
    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) public returns (uint256 reserveA, uint256 reserveB) {
        //Sorting
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        //Get reserves from pair
        (uint256 reserve0, uint256 reserve1, ) = IAdrenalineSwapPair(
            pairFor(factoryAddress, token0, token1)
        ).getReserves();
        //Token0 - ADR(100), Token1 - ZAL(1000)
        //TokenA = ZAL, tokenB = ADR
        //Protects us from wrong token order
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            //ADR, ZAL
            : (reserve1, reserve0);
    }

    //calculate basic amountOut without fees and etc 
    //quote
    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        //If amount is zero we have nothing to quote
        if (amountIn == 0) revert InsufficientAmount();
        //If we have no reserves we can't quote amount out
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        //Example (150*200)/1000 = 30, calculated amountOut based on tokens in, math proportion
        return (amountIn * reserveOut) / reserveIn;
    }

    //Sorting tokens addresses
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    //Gets pair address by factory and token by finding memory offset 
    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal pure returns (address pairAddress) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(AdrenalineSwapPair).creationCode)
                        )
                    )
                )
            )
        );
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        //Fee is 0.03%
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) public returns (uint256[] memory) {
        if (path.length < 2) revert InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserve0, uint256 reserve1) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        if (amountOut == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 990;

        return (numerator / denominator) + 1;
    }

    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) public returns (uint256[] memory) {
        if (path.length < 2) revert InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserve0, uint256 reserve1) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }
}
