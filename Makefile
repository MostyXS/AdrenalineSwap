test:
	forge test -vvv
codehash:
	cat out/AdrenalineSwapPair.sol/AdrenalineSwapPair.json | jq -r .bytecode.object | xargs cast keccak