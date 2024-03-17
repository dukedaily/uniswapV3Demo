// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./lib/Tick.sol";
import "./lib/Position.sol";
import "./lib/IERC20.sol";
import "./lib/IUniswapV3MintCallback.sol";
import "./lib/IUniswapV3SwapCallback.sol";
import "forge-std/console.sol";

contract UniswapV3Pool {
    // using A for B is a feature of Solidity that
    // allows you extend type B with functions from library A
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info; // don't forget this!!!

    error InsufficientInputAmount();
    error InvalidTickRange();
    error ZeroLiquidity();

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        uint128 amount0,
        uint128 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    // Packing variables taht are read together
    struct Slot0 {
        // Current sqrt(P)
        uint160 sqrtPriceX96;
        // Current tick
        int24 tick;
    }

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    Slot0 public slot0;

    // Amount of liquidity in the pool, L
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;

    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    constructor(address token0_, address token1_, uint160 sqrtPriceX96_, int24 tick_) {
        console.log("constructor called");
        token0 = token0_;
        token1 = token1_;
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96_, tick: tick_});
    }

    function mint(address owner, int24 lowerTick, int24 upperTick, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        console.log("mint called");
        if (lowerTick >= upperTick || lowerTick < MIN_TICK || upperTick > MAX_TICK) revert InvalidTickRange();

        if (amount == 0) revert ZeroLiquidity();

        console.log("will update ticks");
        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(owner, lowerTick, upperTick);

        console.log("will update position");
        position.update(amount);

        amount0 = 0.99897661834742528 ether; // TODO: replace with calculation
        amount1 = 5000 ether; // TODO: replace with calculation
        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        console.log("will call IUniswapV3MintCallback");
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

        console.log("will check account0 balances");
        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }

        console.log("will check account1 balances");
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
    }

    // END OF CONTRACT
    function balance0() internal returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }
}
