// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "clober-dex/v2-core/BookManager.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "../src/SimpleCouponStrategy.sol";
import "../src/Rebalancer.sol";
import "./mocks/TakeRouter.sol";

contract RebalancerTest is Test {
    using EpochLibrary for Epoch;
    using BookIdLibrary for IBookManager.BookKey;
    using TickLibrary for Tick;

    IBookManager public bookManager;
    SimpleCouponStrategy public strategy;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    IBookManager.BookKey public keyA;
    IBookManager.BookKey public keyB;
    IBookManager.BookKey public unopenedKeyA;
    IBookManager.BookKey public unopenedKeyB;
    bytes32 public key;
    Rebalancer public rebalancer;
    TakeRouter public takeRouter;

    function setUp() public {
        vm.warp(1710317879);
        bookManager = new BookManager(address(this), address(0x123), "URI", "URI", "Name", "SYMBOL");

        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);

        rebalancer = new Rebalancer(bookManager, address(this));

        strategy = new SimpleCouponStrategy(rebalancer, bookManager, address(this));

        keyA = IBookManager.BookKey({
            base: Currency.wrap(address(tokenB)),
            unitSize: 1e12,
            quote: Currency.wrap(address(tokenA)),
            makerPolicy: FeePolicyLibrary.encode(true, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(true, 1200)
        });
        unopenedKeyA = keyA;
        unopenedKeyA.unitSize = 1e13;
        keyB = IBookManager.BookKey({
            base: Currency.wrap(address(tokenA)),
            unitSize: 1e12,
            quote: Currency.wrap(address(tokenB)),
            makerPolicy: FeePolicyLibrary.encode(false, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(false, 1200)
        });
        unopenedKeyB = keyB;
        unopenedKeyB.unitSize = 1e13;

        key = rebalancer.open(keyA, keyB, address(strategy));

        strategy.setCouponStrategy(key, EpochLibrary.current().add(1), 98534533154674428335, 146389476364791594973); // 4%, 6%

        tokenA.mint(address(this), 1e27);
        tokenB.mint(address(this), 1e27);
        tokenA.approve(address(rebalancer), type(uint256).max);
        tokenB.approve(address(rebalancer), type(uint256).max);

        takeRouter = new TakeRouter(bookManager);
        tokenA.approve(address(takeRouter), type(uint256).max);
        tokenB.approve(address(takeRouter), type(uint256).max);
    }

    function testOpen() public {
        BookId bookIdA = unopenedKeyA.toId();
        BookId bookIdB = unopenedKeyB.toId();

        uint256 snapshotId = vm.snapshot();
        vm.expectEmit(false, true, true, true, address(rebalancer));
        emit IRebalancer.Open(bytes32(0), bookIdA, bookIdB, address(strategy));
        bytes32 key1 = rebalancer.open(unopenedKeyA, unopenedKeyB, address(strategy));
        IRebalancer.Pool memory pool = rebalancer.getPool(key1);
        assertEq(BookId.unwrap(pool.bookIdA), BookId.unwrap(bookIdA), "POOL_A");
        assertEq(BookId.unwrap(pool.bookIdB), BookId.unwrap(bookIdB), "POOL_B");
        (BookId idA, BookId idB) = rebalancer.getBookPairs(key1);
        assertEq(BookId.unwrap(idA), BookId.unwrap(bookIdA), "PAIRS_A");
        assertEq(BookId.unwrap(idB), BookId.unwrap(bookIdB), "PAIRS_B");

        vm.revertTo(snapshotId);
        vm.expectEmit(false, true, true, true, address(rebalancer));
        emit IRebalancer.Open(bytes32(0), bookIdB, bookIdA, address(strategy));
        bytes32 key2 = rebalancer.open(unopenedKeyB, unopenedKeyA, address(strategy));
        pool = rebalancer.getPool(key1);
        assertEq(BookId.unwrap(pool.bookIdA), BookId.unwrap(bookIdB), "POOL_A");
        assertEq(BookId.unwrap(pool.bookIdB), BookId.unwrap(bookIdA), "POOL_B");
        (idA, idB) = rebalancer.getBookPairs(key1);
        assertEq(BookId.unwrap(idA), BookId.unwrap(bookIdB), "PAIRS_A");
        assertEq(BookId.unwrap(idB), BookId.unwrap(bookIdA), "PAIRS_B");

        assertEq(key1, key2, "SAME_KEY");
        assertEq(BookId.unwrap(rebalancer.bookPair(bookIdA)), BookId.unwrap(bookIdB), "PAIR_A");
        assertEq(BookId.unwrap(rebalancer.bookPair(bookIdB)), BookId.unwrap(bookIdA), "PAIR_B");
        assertEq(address(pool.strategy), address(strategy), "STRATEGY");
        assertEq(pool.reserveA, 0, "RESERVE_A");
        assertEq(pool.reserveB, 0, "RESERVE_B");
        assertEq(pool.orderListA.length, 0, "ORDER_LIST_A");
        assertEq(pool.orderListB.length, 0, "ORDER_LIST_B");

        (uint256 liquidityA, uint256 liquidityB) = rebalancer.getLiquidity(key1);
        assertEq(liquidityA, 0, "LIQUIDITY_A");
        assertEq(liquidityB, 0, "LIQUIDITY_B");
    }

    function testOpenShouldCheckCurrencyPair() public {
        unopenedKeyA.quote = Currency.wrap(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidBookPair.selector));
        rebalancer.open(unopenedKeyA, unopenedKeyB, address(strategy));
    }

    function testOpenShouldCheckHooks() public {
        unopenedKeyA.hooks = IHooks(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidHook.selector));
        rebalancer.open(unopenedKeyA, unopenedKeyB, address(strategy));

        unopenedKeyA.hooks = IHooks(address(0));
        unopenedKeyB.hooks = IHooks(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidHook.selector));
        rebalancer.open(unopenedKeyA, unopenedKeyB, address(strategy));
    }

    function testOpenAccess() public {
        vm.expectRevert();
        vm.prank(address(0x123));
        rebalancer.open(unopenedKeyA, unopenedKeyB, address(strategy));
    }

    function testMintInitiallyWithZeroAmount() public {
        assertEq(rebalancer.totalSupply(uint256(key)), 0, "INITIAL_SUPPLY");

        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidAmount.selector));
        rebalancer.mint(key, 12341234, 0);

        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidAmount.selector));
        rebalancer.mint(key, 0, 12341234);
    }

    function testMintInitially() public {
        assertEq(rebalancer.totalSupply(uint256(key)), 0, "INITIAL_SUPPLY");

        uint256 snapshotId = vm.snapshot();

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Mint(address(this), key, 1e18, 1e18 + 1, 1e18 + 1);
        rebalancer.mint(key, 1e18, 1e18 + 1);
        assertEq(rebalancer.totalSupply(uint256(key)), 1e18 + 1, "AFTER_SUPPLY_2");
        assertEq(rebalancer.getPool(key).reserveA, 1e18, "RESERVE_A_2");
        assertEq(rebalancer.getPool(key).reserveB, 1e18 + 1, "RESERVE_B_2");
        (uint256 liquidityA, uint256 liquidityB) = rebalancer.getLiquidity(key);
        assertEq(liquidityA, 1e18, "LIQUIDITY_A_2");
        assertEq(liquidityB, 1e18 + 1, "LIQUIDITY_B_2");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), 1e18 + 1, "LP_BALANCE_2");

        vm.revertTo(snapshotId);

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Mint(address(this), key, 1e18 + 1, 1e18, 1e18 + 1);
        rebalancer.mint(key, 1e18 + 1, 1e18);
        assertEq(rebalancer.totalSupply(uint256(key)), 1e18 + 1, "AFTER_SUPPLY_2");
        assertEq(rebalancer.getPool(key).reserveA, 1e18 + 1, "RESERVE_A_2");
        assertEq(rebalancer.getPool(key).reserveB, 1e18, "RESERVE_B_2");
        (liquidityA, liquidityB) = rebalancer.getLiquidity(key);
        assertEq(liquidityA, 1e18 + 1, "LIQUIDITY_A_2");
        assertEq(liquidityB, 1e18, "LIQUIDITY_B_2");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), 1e18 + 1, "LP_BALANCE_2");
    }

    function testMint() public {
        rebalancer.mint(key, 1e18, 1e18);
        assertEq(rebalancer.totalSupply(uint256(key)), 1e18, "BEFORE_SUPPLY");

        IRebalancer.Pool memory beforePool = rebalancer.getPool(key);
        IRebalancer.Pool memory afterPool = beforePool;
        (uint256 beforeLiquidityA, uint256 beforeLiquidityB) = rebalancer.getLiquidity(key);
        (uint256 afterLiquidityA, uint256 afterLiquidityB) = (beforeLiquidityA, beforeLiquidityB);
        uint256 beforeLpBalance = rebalancer.balanceOf(address(this), uint256(key));
        uint256 beforeSupply = rebalancer.totalSupply(uint256(key));

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Mint(address(this), key, 1e18 / 2, 1e18 / 2, 1e18 / 2);
        rebalancer.mint(key, 1e18, 1e18 / 2);
        afterPool = rebalancer.getPool(key);
        (afterLiquidityA, afterLiquidityB) = rebalancer.getLiquidity(key);
        assertEq(rebalancer.totalSupply(uint256(key)), beforeSupply + 1e18 / 2, "AFTER_SUPPLY_0");
        assertEq(afterPool.reserveA, beforePool.reserveA + 1e18 / 2, "RESERVE_A_0");
        assertEq(afterPool.reserveB, beforePool.reserveB + 1e18 / 2, "RESERVE_B_0");
        assertEq(afterLiquidityA, beforeLiquidityA + 1e18 / 2, "LIQUIDITY_A_0");
        assertEq(afterLiquidityB, beforeLiquidityB + 1e18 / 2, "LIQUIDITY_B_0");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), beforeLpBalance + 1e18 / 2, "LP_BALANCE_0");

        beforePool = afterPool;
        (beforeLiquidityA, beforeLiquidityB) = (afterLiquidityA, afterLiquidityB);
        beforeLpBalance = rebalancer.balanceOf(address(this), uint256(key));
        beforeSupply = rebalancer.totalSupply(uint256(key));

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Mint(address(this), key, 0, 0, 0);
        rebalancer.mint(key, 1e18, 0);
        afterPool = rebalancer.getPool(key);
        (afterLiquidityA, afterLiquidityB) = rebalancer.getLiquidity(key);
        assertEq(rebalancer.totalSupply(uint256(key)), beforeSupply, "AFTER_SUPPLY_1");
        assertEq(afterPool.reserveA, beforePool.reserveA, "RESERVE_A_1");
        assertEq(afterPool.reserveB, beforePool.reserveB, "RESERVE_B_1");
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A_1");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B_1");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), beforeLpBalance, "LP_BALANCE_1");

        beforePool = afterPool;
        (beforeLiquidityA, beforeLiquidityB) = (afterLiquidityA, afterLiquidityB);
        beforeLpBalance = rebalancer.balanceOf(address(this), uint256(key));
        beforeSupply = rebalancer.totalSupply(uint256(key));

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Mint(address(this), key, 0, 0, 0);
        rebalancer.mint(key, 0, 1e18);
        afterPool = rebalancer.getPool(key);
        (afterLiquidityA, afterLiquidityB) = rebalancer.getLiquidity(key);
        assertEq(rebalancer.totalSupply(uint256(key)), beforeSupply, "AFTER_SUPPLY_2");
        assertEq(afterPool.reserveA, beforePool.reserveA, "RESERVE_A_2");
        assertEq(afterPool.reserveB, beforePool.reserveB, "RESERVE_B_2");
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A_2");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B_2");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), beforeLpBalance, "LP_BALANCE_2");
    }

    function testBurn() public {
        rebalancer.mint(key, 1e18, 1e21);

        (uint256 beforeLiquidityA, uint256 beforeLiquidityB) = rebalancer.getLiquidity(key);
        uint256 beforeLpBalance = rebalancer.balanceOf(address(this), uint256(key));
        uint256 beforeSupply = rebalancer.totalSupply(uint256(key));
        uint256 beforeABalance = tokenA.balanceOf(address(this));
        uint256 beforeBBalance = tokenB.balanceOf(address(this));

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Burn(address(this), key, 1e18 / 2, 1e21 / 2, beforeSupply / 2);
        rebalancer.burn(key, beforeSupply / 2);

        IRebalancer.Pool memory afterPool = rebalancer.getPool(key);
        (uint256 afterLiquidityA, uint256 afterLiquidityB) = rebalancer.getLiquidity(key);
        assertEq(rebalancer.totalSupply(uint256(key)), beforeSupply - beforeSupply / 2, "AFTER_SUPPLY");
        assertLt(afterPool.reserveA, keyA.unitSize, "RESERVE_A");
        assertLt(afterPool.reserveB, keyB.unitSize, "RESERVE_B");
        assertEq(afterLiquidityA, beforeLiquidityA - 1e18 / 2, "LIQUIDITY_A");
        assertEq(afterLiquidityB, beforeLiquidityB - 1e21 / 2, "LIQUIDITY_B");
        assertEq(rebalancer.balanceOf(address(this), uint256(key)), beforeLpBalance - beforeSupply / 2, "LP_BALANCE");
        assertEq(tokenA.balanceOf(address(this)) - beforeABalance, 1e18 / 2, "A_BALANCE");
        assertEq(tokenB.balanceOf(address(this)) - beforeBBalance, 1e21 / 2, "B_BALANCE");
    }

    function testRebalance() public {
        rebalancer.mint(key, 1e18 + 141231, 1e21 + 241245);

        (uint256 beforeLiquidityA, uint256 beforeLiquidityB) = rebalancer.getLiquidity(key);

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Rebalance(key);
        rebalancer.rebalance(key);

        IRebalancer.Pool memory afterPool = rebalancer.getPool(key);
        (uint256 afterLiquidityA, uint256 afterLiquidityB) = rebalancer.getLiquidity(key);
        assertLt(afterPool.reserveA, keyA.unitSize, "RESERVE_A"); // 1000141231
        assertLt(afterPool.reserveB, keyB.unitSize, "RESERVE_B"); // 241245
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B");
        assertEq(afterPool.orderListA.length, 1, "ORDER_LIST_A");
        assertEq(afterPool.orderListB.length, 1, "ORDER_LIST_B");
    }

    function testRebalanceAfterSomeOrdersHaveTaken() public {
        rebalancer.mint(key, 1e18 + 141231, 1e21 + 241245);
        rebalancer.rebalance(key);

        (uint256 beforeLiquidityA, uint256 beforeLiquidityB) = rebalancer.getLiquidity(key);

        takeRouter.take(IBookManager.TakeParams({key: keyA, tick: Tick.wrap(-57340), maxUnit: 2000}), "");

        vm.warp(block.timestamp + 24 * 3600);

        vm.expectEmit(address(rebalancer));
        emit IRebalancer.Rebalance(key);
        rebalancer.rebalance(key);

        IRebalancer.Pool memory afterPool = rebalancer.getPool(key);
        (uint256 afterLiquidityA, uint256 afterLiquidityB) = rebalancer.getLiquidity(key);

        assertLt(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A");
        assertGt(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B");
        assertEq(tokenA.balanceOf(address(rebalancer)), afterPool.reserveA, "RESERVE_A");
        assertEq(tokenB.balanceOf(address(rebalancer)), afterPool.reserveB, "RESERVE_B");
    }

    function testRebalanceRevertUnknownBookPair() public {
        vm.expectRevert(abi.encodeWithSelector(IRebalancer.InvalidBookPair.selector));
        rebalancer.rebalance(bytes32(uint256(0x123)));
    }
}
