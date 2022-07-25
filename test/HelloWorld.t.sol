// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

import "forge-std/Test.sol";
import "../src/AdrenalineSwapFactory.sol";
import "../src/AdrenalineSwapPair.sol";
import "./mocks/ERC20Mintable.sol";

contract HelloWorldTest is Test {
        
    function setUp() public {

        
        

    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function test() public {
        encoded.log('zalupa');
    }
}
