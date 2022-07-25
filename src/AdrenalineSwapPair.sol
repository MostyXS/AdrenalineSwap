// SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0 <=0.9.0;

import "solmate/tokens/ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IAdrenalineSwapCallee.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error AlreadyInitialized();
error BalanceOverflow();
error InsufficientInputAmount();
error InsufficientLiquidity();
error InsufficientLiquidityBurned();
error InsufficientLiquidityMinted();
error InsufficientOutputAmount();
error InvalidK();
error TransferFailed();

//Pair is implemented as another token, totalSupply - liquidity pool supply, mint, burn - addLiquidity and remove liquidity
contract AdrenalineSwapPair is ERC20, Math {
    //7bit standart represantation
    using UQ112x112 for uint224;

    //Minimum liquidity to mint
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    //Addresess of pair tokens
    address public token0;
    address public token1;

    //remaining token reserves
    uint112 private reserve0;
    uint112 private reserve1;

    //Last interaction time
    uint32 private blockTimestampLast;

    //This variable can be used by external contracts to track accurate time-weighted average prices (TWAPs) across any time interval.
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;


    //To avoid re-entrancy attack
    bool private isEntered;

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address to
    );
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    modifier nonReentrant() {
        require(!isEntered);
        isEntered = true;

        _;

        isEntered = false;
    }

    //Name, symbol, decimals
    constructor() ERC20("AdrenalineSwap Pair", "ADR", 18) {}

    //Initialize pair token addresess
    function initialize(address token0_, address token1_) public {
        if (token0 != address(0) || token1 != address(0))
            revert AlreadyInitialized();

        token0 = token0_;
        token1 = token1_;
    }

    //Same as add liquidity
    function mint(address to) public returns (uint256 liquidity) {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        //Amount - difference between total token balance and pool reserves
        // 2650 - 200 = 2450
        // 820 - 20 = 800
        uint256 amount0 = balance0 - reserve0_;
        uint256 amount1 = balance1 - reserve1_;

        //Total supply - liquidity pool supply, derived from ERC20
        if (totalSupply == 0) {

            //liquidity = sqrt(2450*800)(1960000) - 1000 = 1450
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            
            //mint minimal liquidity if total token supply is 0
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            
            liquidity = Math.min(
                (amount0 * totalSupply) / reserve0_,
                (amount1 * totalSupply) / reserve1_
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();

        //Initial mint will be
        _mint(to, liquidity);

        _update(balance0, balance1, reserve0_, reserve1_);

        emit Mint(to, amount0, amount1);
    }
    //Same as remove liquidity
    function burn(address to)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        _burn(address(this), liquidity);

        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(balance0, balance1, reserve0_, reserve1_);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) public nonReentrant {
        if (amount0Out == 0 && amount1Out == 0)
            revert InsufficientOutputAmount();

        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();

        if (amount0Out > reserve0_ || amount1Out > reserve1_)
            revert InsufficientLiquidity();

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
        if (data.length > 0)
            IAdrenalineSwapCallee(to).AdrenalineSwapCall(
                msg.sender,
                amount0Out,
                amount1Out,
                data
            );

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > reserve0 - amount0Out
            ? balance0 - (reserve0 - amount0Out)
            : 0;
        uint256 amount1In = balance1 > reserve1 - amount1Out
            ? balance1 - (reserve1 - amount1Out)
            : 0;

        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();

        // Adjusted = balance before swap - swap fee; fee stays in the contract
        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        if (
            balance0Adjusted * balance1Adjusted <
            uint256(reserve0_) * uint256(reserve1_) * (1000**2)
        ) revert InvalidK();

        _update(balance0, balance1, reserve0_, reserve1_);

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function sync() public {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0_,
            reserve1_
        );
    }

    function getReserves()
        public
        view
        returns (
            uint112,
            uint112,
            uint32
        )
    {
        return (reserve0, reserve1, blockTimestampLast);
    }

    //
    //
    //
    //  PRIVATE
    //
    //
    //
    function _update(
        uint256 balance0,
        uint256 balance1,
        uint112 reserve0_,
        uint112 reserve1_
    ) private {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max)
            revert BalanceOverflow();

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;

            if (timeElapsed > 0 && reserve0_ > 0 && reserve1_ > 0) {
                price0CumulativeLast +=
                    uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) *
                    timeElapsed;
                price1CumulativeLast +=
                    uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) *
                    timeElapsed;
            }
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TransferFailed();
    }
}
