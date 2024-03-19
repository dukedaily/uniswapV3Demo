// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "./TestUtils.sol";
import "forge-std/console.sol";

// forge test -vv
contract UniswapV3PoolTest is Test, TestUtils {
    ERC20Mintable public token0;
    ERC20Mintable public token1;
    UniswapV3Pool public pool;

    bool transferInMintCallback = true;
    bool transferInSwapCallback = true;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool transferInMintCallback;
        bool transferInSwapCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        console.log("UniswapV3PoolTest");
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        console.log("token0: %s", address(token0));
        console.log("token1: %s", address(token1));
    }

    function testExample() public pure {
        assertTrue(true);
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function setupTestCase(TestCaseParams memory params)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance);
        token1.mint(address(this), params.usdcBalance);

        pool = new UniswapV3Pool(address(token0), address(token1), params.currentSqrtP, params.currentTick);

        if (params.mintLiqudity) {
            token0.approve(address(this), params.wethBalance);
            token1.approve(address(this), params.usdcBalance);

            // this is a defined struct callback for minting
            UniswapV3Pool.CallbackData memory extra =
                UniswapV3Pool.CallbackData({token0: address(token0), token1: address(token1), payer: address(this)});

            (poolBalance0, poolBalance1) =
                pool.mint(address(this), params.lowerTick, params.upperTick, params.liquidity, abi.encode(extra));
        }

        transferInMintCallback = params.transferInMintCallback;
        transferInSwapCallback = params.transferInSwapCallback;
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
        uint256 expectedAmount0 = 0.99897661834742528 ether;
        uint256 expectedAmount1 = 5000 ether;
        assertEq(poolBalance0, expectedAmount0, "incorrect token0 deposited amount");

        assertEq(poolBalance1, expectedAmount1, "incorrect token1 deposited amount");

        assertEq(token0.balanceOf(address(pool)), expectedAmount0, "incorrect token0 balance");
        assertEq(token1.balanceOf(address(pool)), expectedAmount1, "incorrect token1 balance");

        bytes32 positionKey = keccak256(abi.encodePacked(address(this), params.lowerTick, params.upperTick));
        uint128 posLiquidity = pool.positions(positionKey);
        assertEq(posLiquidity, params.liquidity, "incorrect position liquidity");

        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(params.lowerTick);
        assertTrue(tickInitialized);
        assertEq(tickLiquidity, params.liquidity, "incorrect tick liquidity");

        (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        assertEq(sqrtPriceX96, params.currentSqrtP, "incorrect current sqrtP");
        assertEq(tick, params.currentTick, "incorrect current tick");
        assertEq(pool.liquidity(), params.liquidity, "incorrect pool liquidity");
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // CALLBACKS
    //
    ////////////////////////////////////////////////////////////////////////////
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (transferInMintCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            transferInMintCallback: true,
            transferInSwapCallback: true,
            mintLiqudity: true
        });

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
        uint256 swapAmount = 42 ether;
        token1.mint(address(this), swapAmount);
        token1.approve(address(this), swapAmount);

        UniswapV3Pool.CallbackData memory extra =
            UniswapV3Pool.CallbackData({token0: address(token0), token1: address(token1), payer: address(this)});

        uint256 userBalance0Before = token0.balanceOf(address(this));
        (int256 amount0Delta, int256 amount1Delta) = pool.swap(address(this), abi.encode(extra));

        int256 expectedAmount0 = -0.008396714242162444 ether;
        assertEq(amount0Delta, expectedAmount0, "invalid ETH out");
        assertEq(amount1Delta, 42 ether, "invalid USDC in");

        assertEq(
            token0.balanceOf(address(this)),
            uint256(int256(userBalance0Before) - amount0Delta),
            "invalid user ETH balance"
        );

        // token0 is USDC, token1 is ETH
        assertEq(token1.balanceOf(address(this)), 0, "invalid user USDC balance");
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
        if (transferInSwapCallback) {
            UniswapV3Pool.CallbackData memory extra = abi.decode(data, (UniswapV3Pool.CallbackData));

            if (amount0 > 0) {
                IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
            }

            if (amount1 > 0) {
                IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
            }
        }
    }
}
