// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

import "./AdrenalineSwapPair.sol";
import "./interfaces/IAdrenalineSwapPair.sol";

contract AdrenalineSwapFactory {
    error IdenticalAddresses();
    error PairExists();
    error ZeroAddress();

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    //Every liquidity pool
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB)
        public
        returns (address pair)
    {
        //Assure addreses are not the same
        if (tokenA == tokenB) revert IdenticalAddresses();

        //Address sorting ?for data key order
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        //Assure the address is not void
        if (token0 == address(0)) revert ZeroAddress();

        //Assure there is no the same pair
        if (pairs[token0][token1] != address(0)) revert PairExists();


        //bytecode of pair(pool) contract
        bytes memory bytecode = type(AdrenalineSwapPair).creationCode;

        //Salt - same as initial vector, random value to secure the actual password
        //Encode packed - standart address encoding, example ("abc", "123") - "abc123"
        bytes memory encoded = abi.encodePacked(token0, token1);
        
        //Default eth encryption
        bytes32 salt = keccak256(encoded);
        
        //Assembly - low level interaction direct to solidity assembly language(yul)
        assembly {
            //Creates pair contract (initial to send to account, size of new account, salt)
            //Mload - calculate memory offset
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //pair initialization
        IAdrenalineSwapPair(pair).initialize(token0, token1);

        //Assign both sides mapping to prevent existing creation
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        //Emit pair created event
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}