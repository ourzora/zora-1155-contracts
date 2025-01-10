// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BaseTest.sol";
import {UniswapV3LiquidityCalculator} from "../src/uniswap/UniswapV3LiquidityCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IMinter1155} from "../src/interfaces/IMinter1155.sol";
import {IERC20Z} from "../src/interfaces/IERC20Z.sol";
import {IUniswapV3Pool} from "@zoralabs/shared-contracts/interfaces/uniswap/IUniswapV3Pool.sol";

contract CollectorUniswapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) {
            address token0 = IUniswapV3Pool(msg.sender).token0();
            console2.log("token0balance", IERC20(token0).balanceOf(address(this)));
            IERC20(token0).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            address token1 = IUniswapV3Pool(msg.sender).token1();
            console2.log("token1balance", IERC20(token1).balanceOf(address(this)));
            IERC20(token1).transfer(msg.sender, uint256(amount1Delta));
        } else {
            // if both are not gt 0, both must be 0.
            assert(amount0Delta == 0 && amount1Delta == 0);
        }
    }

    receive() external payable {
        console2.log("received eth ", msg.value);
    }
}

contract ZoraTimedSaleStrategyMarketTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);

    function setUpTimedSale(uint64 saleStart, uint64 saleEnd) public returns (address erc20zAddress, address poolAddress) {
        IZoraTimedSaleStrategy.SalesConfig memory salesConfig = IZoraTimedSaleStrategy.SalesConfig({
            saleStart: saleStart,
            saleEnd: saleEnd,
            name: "Test",
            symbol: "TST"
        });
        vm.prank(users.creator);
        collection.callSale(tokenId, saleStrategy, abi.encodeWithSelector(saleStrategy.setSale.selector, tokenId, salesConfig));

        erc20zAddress = saleStrategy.sale(address(collection), tokenId).erc20zAddress;
        poolAddress = saleStrategy.sale(address(collection), tokenId).poolAddress;
        vm.label(erc20zAddress, "ERC20Z");
        vm.label(poolAddress, "V3_POOL");
    }

    function testSwapFrontrunOverERC20ZFirst(uint8 randomHash) public {
        vm.assume(randomHash >= 1);

        address collector = makeAddr("collector");

        // Allow switching order of tokens to test all cases
        vm.prevrandao(uint256(randomHash));

        (address erc20zAddress, address poolAddress) = setUpTimedSale(0, uint64(block.timestamp + 10));

        bool tokenIsFirst = erc20zAddress < address(WETH);
        // assume erc20z is first
        vm.assume(tokenIsFirst);

        IUniswapV3Pool(poolAddress).swap({
            recipient: address(this),
            zeroForOne: false,
            amountSpecified: 1,
            sqrtPriceLimitX96: 9994949499494123123123123123123,
            //////////         834720487725035753950589079
            // Expected Price
            data: bytes("")
        });

        uint160 currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, 9994949499494123123123123123123);

        // Mint 110 tokens
        saleStrategy.mint{value: 0.000111 ether * 110}(collector, 110, address(collection), tokenId, address(0), "");

        vm.warp(block.timestamp + 30 hours);

        // Launch market (assume that the market price is _reset_ to the expected price).
        saleStrategy.launchMarket(address(collection), tokenId);

        vm.startPrank(collector);
        collection.setApprovalForAll(erc20zAddress, true);
        IERC20Z(erc20zAddress).wrap(100, collector);
        IERC20(erc20zAddress).approve(poolAddress, type(uint256).max);

        currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0);

        vm.etch(collector, address(new CollectorUniswapCallback()).code);

        // we have ERC20Z Tokens -> WETH
        IUniswapV3Pool(poolAddress).swap(
            address(collector),
            true,
            10 ether,
            UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0 - ((UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0 * 10) / 100),
            bytes("")
        );

        assertGt(WETH.balanceOf(address(collector)), 0.00012 ether);
    }

    function testSwapFrontrunOverWETHFirst(uint8 randomHash) public {
        vm.assume(randomHash >= 1);

        address collector = makeAddr("collector");

        // Allow switching order of tokens to test all cases
        vm.prevrandao(uint256(randomHash));

        (address erc20zAddress, address poolAddress) = setUpTimedSale(0, uint64(block.timestamp + 10));

        // Assume WETH is first.
        vm.assume(erc20zAddress > address(WETH));

        IUniswapV3Pool(poolAddress).swap({
            recipient: address(this),
            zeroForOne: false,
            amountSpecified: 1,
            sqrtPriceLimitX96: 752000439391924042743229815193600000,
            data: bytes("")
        });

        uint160 currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, 752000439391924042743229815193600000);

        // mint 110 tokens
        saleStrategy.mint{value: 0.000111 ether * 110}(collector, 110, address(collection), tokenId, address(0), "");

        vm.warp(block.timestamp + 30 hours);

        // Launch market (assume that the market price is _reset_ to the expected price).
        saleStrategy.launchMarket(address(collection), tokenId);

        vm.startPrank(collector);
        collection.setApprovalForAll(erc20zAddress, true);
        IERC20Z(erc20zAddress).wrap(100, collector);
        IERC20(erc20zAddress).approve(poolAddress, type(uint256).max);

        currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, UniswapV3LiquidityCalculator.SQRT_PRICE_X96_WETH_0);

        vm.etch(collector, address(new CollectorUniswapCallback()).code);

        console2.log("WETH balance (from selling one zrtk): %", WETH.balanceOf(collector));

        // ERC20 -> WETH swap
        IUniswapV3Pool(poolAddress).swap(address(collector), false, 10 ether, currentSqrtPriceX96 + (currentSqrtPriceX96 / 10), bytes(""));

        assertGt(WETH.balanceOf(collector), 0.0001 ether);
    }

    function testSwapFrontrunUnderERC20First(uint8 randomHash) public {
        vm.assume(randomHash >= 1);

        // Allow switching order of tokens to test all cases
        vm.prevrandao(uint256(randomHash));

        address collector = makeAddr("collector");
        (address erc20zAddress, address poolAddress) = setUpTimedSale(0, uint64(block.timestamp + 10));

        // Assume ERC20z is first.
        vm.assume(erc20zAddress < address(WETH));

        deal(address(WETH), address(this), 1100);
        deal(address(erc20zAddress), address(this), 1100);

        IERC20(erc20zAddress).approve(address(nonfungiblePositionManager), type(uint256).max);
        WETH.approve(address(nonfungiblePositionManager), type(uint256).max);

        console2.log("initial swap");
        IUniswapV3Pool(poolAddress).swap(address(this), true, 100000, 123423123123, bytes(""));

        // mint 100 tokens
        saleStrategy.mint{value: 0.000111 ether * 110}(collector, 110, address(collection), tokenId, address(0), "");

        vm.warp(block.timestamp + 25 hours);

        saleStrategy.launchMarket(address(collection), tokenId);

        vm.startPrank(collector);
        collection.setApprovalForAll(erc20zAddress, true);
        IERC20Z(erc20zAddress).wrap(100, collector);
        IERC20(erc20zAddress).approve(poolAddress, type(uint256).max);

        uint160 currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0);

        vm.etch(collector, address(new CollectorUniswapCallback()).code);

        vm.assertEq(100 ether, IERC20(erc20zAddress).balanceOf(address(collector)));

        IUniswapV3Pool(poolAddress).swap(
            address(collector),
            true,
            10 ether,
            UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0 - UniswapV3LiquidityCalculator.SQRT_PRICE_X96_ERC20Z_0 / 20,
            bytes("")
        );

        vm.assertGt(IERC20(erc20zAddress).balanceOf(address(collector)), 90 ether);
        vm.assertGt(WETH.balanceOf(collector), 0.00001 ether);
    }

    function testSwapFrontrunUnderWETHFirst(uint8 randomHash) public {
        vm.assume(randomHash >= 1);

        // Allow switching order of tokens to test all cases
        vm.prevrandao(uint256(randomHash));

        address collector = makeAddr("collector");
        (address erc20zAddress, address poolAddress) = setUpTimedSale(0, uint64(block.timestamp + 10));

        // Assume ERC20z is first.
        vm.assume(erc20zAddress > address(WETH));

        deal(address(WETH), address(this), 1100);
        deal(address(erc20zAddress), address(this), 1100);

        IERC20(erc20zAddress).approve(address(nonfungiblePositionManager), type(uint256).max);
        WETH.approve(address(nonfungiblePositionManager), type(uint256).max);

        console2.log("initial swap");
        IUniswapV3Pool(poolAddress).swap(address(this), true, 100000, 123423123123, bytes(""));

        // mint 100 tokens
        saleStrategy.mint{value: 0.000111 ether * 110}(collector, 110, address(collection), tokenId, address(0), "");

        vm.warp(block.timestamp + 30 hours);

        saleStrategy.launchMarket(address(collection), tokenId);

        vm.startPrank(collector);
        collection.setApprovalForAll(erc20zAddress, true);
        IERC20Z(erc20zAddress).wrap(100, collector);
        IERC20(erc20zAddress).approve(poolAddress, type(uint256).max);

        uint160 currentSqrtPriceX96 = IUniswapV3Pool(poolAddress).slot0().sqrtPriceX96;
        assertEq(currentSqrtPriceX96, UniswapV3LiquidityCalculator.SQRT_PRICE_X96_WETH_0);

        vm.etch(collector, address(new CollectorUniswapCallback()).code);

        IUniswapV3Pool(poolAddress).swap(
            address(collector),
            false,
            100 ether,
            UniswapV3LiquidityCalculator.SQRT_PRICE_X96_WETH_0 + (UniswapV3LiquidityCalculator.SQRT_PRICE_X96_WETH_0 / 10),
            bytes("")
        );

        vm.assertGt(WETH.balanceOf(collector), 0.0001 ether);
    }

    function testSwapWrongPrices(uint8 randomHash) public {
        vm.assume(randomHash >= 1);

        // Allow switching order of tokens to test all cases
        vm.prevrandao(uint256(randomHash));

        address collector = makeAddr("collector");
        (address erc20zAddress, address poolAddress) = setUpTimedSale(0, uint64(block.timestamp + 10));

        deal(address(WETH), address(this), 1100);
        deal(address(erc20zAddress), address(this), 1100);

        IERC20(erc20zAddress).approve(address(nonfungiblePositionManager), type(uint256).max);
        WETH.approve(address(nonfungiblePositionManager), type(uint256).max);

        bool tokenIsFirst = erc20zAddress > address(WETH);

        console2.log("initial swap");
        IUniswapV3Pool(poolAddress).swap(
            address(this),
            tokenIsFirst,
            0.001 ether,
            !tokenIsFirst ? 14614467034852101032872730522039888223787239703 : 4295128759,
            bytes("")
        );

        // mint 100 tokens
        saleStrategy.mint{value: 0.000111 ether * 100}(collector, 100, address(collection), tokenId, address(0), "");

        vm.warp(block.timestamp + 30 hours);

        saleStrategy.launchMarket(address(collection), tokenId);

        vm.startPrank(collector);
        collection.setApprovalForAll(erc20zAddress, true);
        IERC20Z(erc20zAddress).wrap(100, collector);
        IERC20(erc20zAddress).approve(poolAddress, type(uint256).max);

        console2.log("tokenIsFirst", tokenIsFirst);
        vm.etch(collector, address(new CollectorUniswapCallback()).code);

        // MIN (plus a little) and MAX (minus a little) price being passed in here
        IUniswapV3Pool(poolAddress).swap(
            address(collector),
            !tokenIsFirst,
            tokenIsFirst ? int256(-10000000000) : int256(100000000),
            tokenIsFirst ? 14614467034852101032872730522039888223787239703 : 4295128759,
            bytes("")
        );

        console2.log("WETH balance (from selling one zrtk): %", WETH.balanceOf(address(this)));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {}
}
