// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "clober-dex/v2-core/BookManager.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "../src/LiquidityVault.sol";
import "../src/interfaces/IStrategy.sol";
import "./mocks/MockStrategy.sol";
import "./mocks/TakeRouter.sol";

contract LiquidityVaultTest is Test {
    using BookIdLibrary for IBookManager.BookKey;
    using TickLibrary for Tick;

    address public constant FEE_RECEIVER = address(0x3333);

    IBookManager public bookManager;
    MockStrategy public strategy;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    IBookManager.BookKey public keyA;
    IBookManager.BookKey public keyB;
    IBookManager.BookKey public unopenedKeyA;
    IBookManager.BookKey public unopenedKeyB;
    bytes32 public key;
    LiquidityVault public liquidityVault;
    TakeRouter public takeRouter;

    function setUp() public {
        bookManager = new BookManager(address(this), address(0x123), "URI", "URI", "Name", "SYMBOL");

        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);

        address liquidityVaultTemplate = address(new LiquidityVault(bookManager, 100));
        liquidityVault = LiquidityVault(
            payable(
                address(
                    new ERC1967Proxy(
                        liquidityVaultTemplate,
                        abi.encodeWithSelector(LiquidityVault.initialize.selector, address(this))
                    )
                )
            )
        );
        liquidityVault.initializeMetadata("Liquidity Vault", "LV", "ETH");

        strategy = new MockStrategy();

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

        key = liquidityVault.open(keyA, keyB, 0x0, address(strategy));

        tokenA.mint(address(this), 1e27);
        tokenB.mint(address(this), 1e27);
        tokenA.approve(address(liquidityVault), type(uint256).max);
        tokenB.approve(address(liquidityVault), type(uint256).max);

        takeRouter = new TakeRouter(bookManager);
        tokenA.approve(address(takeRouter), type(uint256).max);
        tokenB.approve(address(takeRouter), type(uint256).max);

        _setOrders(0, 10000, 0, 10000);
    }

    function _setOrders(int24 tickA, uint64 amountA, int24 tickB, uint64 amountB) internal {
        strategy.setOrders(
            IStrategy.Order({tick: Tick.wrap(tickA), rawAmount: amountA}),
            IStrategy.Order({tick: Tick.wrap(tickB), rawAmount: amountB})
        );
    }

    function testOpen() public {
        BookId bookIdA = unopenedKeyA.toId();
        BookId bookIdB = unopenedKeyB.toId();

        uint256 snapshotId = vm.snapshotState();
        vm.expectEmit(false, true, true, true, address(liquidityVault));
        emit ILiquidityVault.Open(bytes32(0), bookIdA, bookIdB, 0x0, address(strategy));
        bytes32 key1 = liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));
        ILiquidityVault.Pool memory pool = liquidityVault.getPool(key1);
        assertEq(BookId.unwrap(pool.bookIdA), BookId.unwrap(bookIdA), "POOL_A");
        assertEq(BookId.unwrap(pool.bookIdB), BookId.unwrap(bookIdB), "POOL_B");
        (BookId idA, BookId idB) = liquidityVault.getBookPairs(key1);
        assertEq(BookId.unwrap(idA), BookId.unwrap(bookIdA), "PAIRS_A");
        assertEq(BookId.unwrap(idB), BookId.unwrap(bookIdB), "PAIRS_B");

        vm.revertToState(snapshotId);
        vm.expectEmit(false, true, true, true, address(liquidityVault));
        emit ILiquidityVault.Open(bytes32(0), bookIdB, bookIdA, 0x0, address(strategy));
        bytes32 key2 = liquidityVault.open(unopenedKeyB, unopenedKeyA, 0x0, address(strategy));
        pool = liquidityVault.getPool(key1);
        assertEq(BookId.unwrap(pool.bookIdA), BookId.unwrap(bookIdB), "POOL_A");
        assertEq(BookId.unwrap(pool.bookIdB), BookId.unwrap(bookIdA), "POOL_B");
        (idA, idB) = liquidityVault.getBookPairs(key1);
        assertEq(BookId.unwrap(idA), BookId.unwrap(bookIdB), "PAIRS_A");
        assertEq(BookId.unwrap(idB), BookId.unwrap(bookIdA), "PAIRS_B");

        assertEq(key1, key2, "SAME_KEY");
        assertEq(BookId.unwrap(liquidityVault.bookPair(bookIdA)), BookId.unwrap(bookIdB), "PAIR_A");
        assertEq(BookId.unwrap(liquidityVault.bookPair(bookIdB)), BookId.unwrap(bookIdA), "PAIR_B");
        assertEq(address(pool.strategy), address(strategy), "STRATEGY");
        assertEq(pool.reserveA, 0, "RESERVE_A");
        assertEq(pool.reserveB, 0, "RESERVE_B");
        assertEq(pool.orderListA.length, 0, "ORDER_LIST_A");
        assertEq(pool.orderListB.length, 0, "ORDER_LIST_B");

        (ILiquidityVault.Liquidity memory liquidityA, ILiquidityVault.Liquidity memory liquidityB) =
            liquidityVault.getLiquidity(key1);
        assertEq(liquidityA.reserve + liquidityA.cancelable + liquidityA.claimable, 0, "LIQUIDITY_A");
        assertEq(liquidityB.reserve + liquidityB.cancelable + liquidityB.claimable, 0, "LIQUIDITY_B");
    }

    function testOpenShouldCheckCurrencyPair() public {
        unopenedKeyA.quote = Currency.wrap(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.InvalidBookPair.selector));
        liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));
    }

    function testOpenShouldCheckHooks() public {
        unopenedKeyA.hooks = IHooks(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.InvalidHook.selector));
        liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));

        unopenedKeyA.hooks = IHooks(address(0));
        unopenedKeyB.hooks = IHooks(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.InvalidHook.selector));
        liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));
    }

    function testOpenTwice() public {
        liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));
        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.AlreadyOpened.selector));
        liquidityVault.open(unopenedKeyA, unopenedKeyB, 0x0, address(strategy));
    }

    function testMintInitiallyWithZeroAmount() public {
        assertEq(liquidityVault.totalSupply(uint256(key)), 0, "INITIAL_SUPPLY");

        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.InvalidAmount.selector));
        liquidityVault.mint(key, 12341234, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.InvalidAmount.selector));
        liquidityVault.mint(key, 0, 12341234, 0);
    }

    function testMintInitially() public {
        assertEq(liquidityVault.totalSupply(uint256(key)), 0, "INITIAL_SUPPLY");

        uint256 snapshotId = vm.snapshotState();

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Mint(address(this), key, 1e18, 1e18 + 1, 1e18 + 1);
        liquidityVault.mint(key, 1e18, 1e18 + 1, 0);
        assertEq(liquidityVault.totalSupply(uint256(key)), 1e18 + 1, "AFTER_SUPPLY_2");
        assertEq(liquidityVault.getPool(key).reserveA, 1e18, "RESERVE_A_2");
        assertEq(liquidityVault.getPool(key).reserveB, 1e18 + 1, "RESERVE_B_2");
        (ILiquidityVault.Liquidity memory liquidityA, ILiquidityVault.Liquidity memory liquidityB) =
            liquidityVault.getLiquidity(key);
        assertEq(liquidityA.reserve + liquidityA.cancelable + liquidityA.claimable, 1e18, "LIQUIDITY_A_2");
        assertEq(liquidityB.reserve + liquidityB.cancelable + liquidityB.claimable, 1e18 + 1, "LIQUIDITY_B_2");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), 1e18 + 1, "LP_BALANCE_2");

        vm.revertToState(snapshotId);

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Mint(address(this), key, 1e18 + 1, 1e18, 1e18 + 1);
        liquidityVault.mint(key, 1e18 + 1, 1e18, 0);
        assertEq(liquidityVault.totalSupply(uint256(key)), 1e18 + 1, "AFTER_SUPPLY_2");
        assertEq(liquidityVault.getPool(key).reserveA, 1e18 + 1, "RESERVE_A_2");
        assertEq(liquidityVault.getPool(key).reserveB, 1e18, "RESERVE_B_2");
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        assertEq(liquidityA.reserve + liquidityA.cancelable + liquidityA.claimable, 1e18 + 1, "LIQUIDITY_A_2");
        assertEq(liquidityB.reserve + liquidityB.cancelable + liquidityB.claimable, 1e18, "LIQUIDITY_B_2");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), 1e18 + 1, "LP_BALANCE_2");
    }

    function testMint() public {
        liquidityVault.mint(key, 1e18, 1e18, 0);
        assertEq(liquidityVault.totalSupply(uint256(key)), 1e18, "BEFORE_SUPPLY");

        ILiquidityVault.Liquidity memory liquidityA;
        ILiquidityVault.Liquidity memory liquidityB;

        ILiquidityVault.Pool memory beforePool = liquidityVault.getPool(key);
        ILiquidityVault.Pool memory afterPool = beforePool;
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 beforeLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 beforeLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        (uint256 afterLiquidityA, uint256 afterLiquidityB) = (beforeLiquidityA, beforeLiquidityB);
        uint256 beforeLpBalance = liquidityVault.balanceOf(address(this), uint256(key));
        uint256 beforeSupply = liquidityVault.totalSupply(uint256(key));

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Mint(address(this), key, 1e18 / 2, 1e18 / 2, 1e18 / 2);
        liquidityVault.mint(key, 1e18, 1e18 / 2, 0);
        afterPool = liquidityVault.getPool(key);
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(liquidityVault.totalSupply(uint256(key)), beforeSupply + 1e18 / 2, "AFTER_SUPPLY_0");
        assertEq(afterPool.reserveA, beforePool.reserveA + 1e18 / 2, "RESERVE_A_0");
        assertEq(afterPool.reserveB, beforePool.reserveB + 1e18 / 2, "RESERVE_B_0");
        assertEq(afterLiquidityA, beforeLiquidityA + 1e18 / 2, "LIQUIDITY_A_0");
        assertEq(afterLiquidityB, beforeLiquidityB + 1e18 / 2, "LIQUIDITY_B_0");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), beforeLpBalance + 1e18 / 2, "LP_BALANCE_0");

        beforePool = afterPool;
        (beforeLiquidityA, beforeLiquidityB) = (afterLiquidityA, afterLiquidityB);
        beforeLpBalance = liquidityVault.balanceOf(address(this), uint256(key));
        beforeSupply = liquidityVault.totalSupply(uint256(key));

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Mint(address(this), key, 0, 0, 0);
        liquidityVault.mint(key, 1e18, 0, 0);
        afterPool = liquidityVault.getPool(key);
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(liquidityVault.totalSupply(uint256(key)), beforeSupply, "AFTER_SUPPLY_1");
        assertEq(afterPool.reserveA, beforePool.reserveA, "RESERVE_A_1");
        assertEq(afterPool.reserveB, beforePool.reserveB, "RESERVE_B_1");
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A_1");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B_1");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), beforeLpBalance, "LP_BALANCE_1");

        beforePool = afterPool;
        (beforeLiquidityA, beforeLiquidityB) = (afterLiquidityA, afterLiquidityB);
        beforeLpBalance = liquidityVault.balanceOf(address(this), uint256(key));
        beforeSupply = liquidityVault.totalSupply(uint256(key));

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Mint(address(this), key, 0, 0, 0);
        liquidityVault.mint(key, 0, 1e18, 0);
        afterPool = liquidityVault.getPool(key);
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(liquidityVault.totalSupply(uint256(key)), beforeSupply, "AFTER_SUPPLY_2");
        assertEq(afterPool.reserveA, beforePool.reserveA, "RESERVE_A_2");
        assertEq(afterPool.reserveB, beforePool.reserveB, "RESERVE_B_2");
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A_2");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B_2");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), beforeLpBalance, "LP_BALANCE_2");
    }

    function testMintShouldCheckMinLpAmount() public {
        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.Slippage.selector));
        liquidityVault.mint(key, 1e18, 1e18, 1e18 + 1);
    }

    function testMintCheckRefund() public {
        vm.deal(address(this), 1 ether);
        vm.deal(address(liquidityVault), 1 ether);

        uint256 beforeThisBalance = address(this).balance;
        liquidityVault.mint{value: 0.5 ether}(key, 1e18, 1e18, 0);

        assertEq(address(this).balance, beforeThisBalance);
    }

    function testBurn() public {
        liquidityVault.mint(key, 1e18, 1e21, 0);

        ILiquidityVault.Liquidity memory liquidityA;
        ILiquidityVault.Liquidity memory liquidityB;

        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 beforeLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 beforeLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        uint256 beforeLpBalance = liquidityVault.balanceOf(address(this), uint256(key));
        uint256 beforeSupply = liquidityVault.totalSupply(uint256(key));
        uint256 beforeABalance = tokenA.balanceOf(address(this));
        uint256 beforeBBalance = tokenB.balanceOf(address(this));

        liquidityVault.rebalance(key);

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Burn(
            address(this),
            key,
            beforeSupply / 2,
            1e18 / 2 - 50000000000000,
            1e21 / 2 - 50000000000000000,
            50000000000000,
            50000000000000000
        );
        liquidityVault.burn(key, beforeSupply / 2, 0, 0);

        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(liquidityVault.totalSupply(uint256(key)), beforeSupply - beforeSupply / 2, "AFTER_SUPPLY");
        assertEq(afterLiquidityA, beforeLiquidityA - 1e18 / 2, "LIQUIDITY_A");
        assertEq(afterLiquidityB, beforeLiquidityB - 1e21 / 2, "LIQUIDITY_B");
        assertEq(
            liquidityVault.balanceOf(address(this), uint256(key)), beforeLpBalance - beforeSupply / 2, "LP_BALANCE"
        );
        assertEq(tokenA.balanceOf(address(this)) - beforeABalance, 1e18 / 2 - 50000000000000, "A_BALANCE");
        assertEq(tokenB.balanceOf(address(this)) - beforeBBalance, 1e21 / 2 - 50000000000000000, "B_BALANCE");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenA))), 50000000000000, "FEE_A");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenB))), 50000000000000000, "FEE_B");
    }

    function testBurnSuccessfullyWhenComputeOrdersReverted() public {
        liquidityVault.mint(key, 1e18, 1e21, 0);

        uint256 beforeSupply = liquidityVault.totalSupply(uint256(key));
        strategy.setShouldRevert(true);

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Burn(
            address(this),
            key,
            beforeSupply / 2,
            1e18 / 2 - 50000000000000,
            1e21 / 2 - 50000000000000000,
            50000000000000,
            50000000000000000
        );
        liquidityVault.burn(key, beforeSupply / 2, 0, 0);
    }

    function testBurnShouldCheckMinAmount() public {
        liquidityVault.mint(key, 1e18, 1e21, 0);

        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.Slippage.selector));
        liquidityVault.burn(key, 1e18, 1e21, 0);

        vm.expectRevert(abi.encodeWithSelector(ILiquidityVault.Slippage.selector));
        liquidityVault.burn(key, 1e18, 1e21, 1e18 + 1);
    }

    function testBurnAll() public {
        liquidityVault.mint(key, 1e18, 1e21, 0);
        liquidityVault.rebalance(key);
        uint256 lpAmount = liquidityVault.balanceOf(address(this), uint256(key));

        uint256 beforeTokenABalance = tokenA.balanceOf(address(this));
        uint256 beforeTokenBBalance = tokenB.balanceOf(address(this));

        vm.expectEmit(address(liquidityVault));
        emit ILiquidityVault.Burn(
            address(this),
            key,
            lpAmount,
            1e18 - 100000000000000,
            1e21 - 100000000000000000,
            100000000000000,
            100000000000000000
        );
        liquidityVault.burn(key, lpAmount, 0, 0);

        assertEq(liquidityVault.totalSupply(uint256(key)), 0, "TOTAL_SUPPLY");
        assertEq(liquidityVault.balanceOf(address(this), uint256(key)), 0, "LP_BALANCE");
        assertEq(tokenA.balanceOf(address(this)), 1e18 - 100000000000000 + beforeTokenABalance, "A_BALANCE");
        assertEq(tokenB.balanceOf(address(this)), 1e21 - 100000000000000000 + beforeTokenBBalance, "B_BALANCE");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenA))), 100000000000000, "FEE_A");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenB))), 100000000000000000, "FEE_B");
    }

    struct RebalanceEventData {
        OrderId[] orderListA;
        OrderId[] orderListB;
        uint256 amountA;
        uint256 amountB;
        uint256 reserveA;
        uint256 reserveB;
    }

    function testRebalance() public {
        liquidityVault.mint(key, 1e18 + 141231, 1e21 + 241245, 0);

        ILiquidityVault.Liquidity memory liquidityA;
        ILiquidityVault.Liquidity memory liquidityB;

        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 beforeLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 beforeLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;

        // Record logs to capture the actual Rebalance event
        vm.recordLogs();
        liquidityVault.rebalance(key);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        RebalanceEventData memory rebalanceEventData;
        // Find and verify the Rebalance event
        bool rebalanceEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ILiquidityVault.Rebalance.selector) {
                rebalanceEventFound = true;
                // Just verify that the event was emitted with correct indexed values
                assertEq(logs[i].topics[1], key, "EVENT_KEY_MISMATCH");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), address(this), "EVENT_CALLER_MISMATCH");
                (
                    rebalanceEventData.orderListA,
                    rebalanceEventData.orderListB,
                    rebalanceEventData.amountA,
                    rebalanceEventData.amountB,
                    rebalanceEventData.reserveA,
                    rebalanceEventData.reserveB
                ) = abi.decode(logs[i].data, (OrderId[], OrderId[], uint256, uint256, uint256, uint256));
                assertEq(rebalanceEventData.orderListA.length, 1, "ORDER_LIST_A");
                assertEq(rebalanceEventData.orderListB.length, 1, "ORDER_LIST_B");
                assertEq(rebalanceEventData.amountA, 9990000000000000, "AMOUNT_A");
                assertEq(rebalanceEventData.amountB, 10000000000000000, "AMOUNT_B");
                assertEq(rebalanceEventData.reserveA, 990010000000141231, "RESERVE_A");
                assertEq(rebalanceEventData.reserveB, 999990000000000241245, "RESERVE_B");
                break;
            }
        }
        assertTrue(rebalanceEventFound, "REBALANCE_EVENT_NOT_FOUND");

        ILiquidityVault.Pool memory afterPool = liquidityVault.getPool(key);
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(afterPool.reserveA, rebalanceEventData.reserveA, "RESERVE_A");
        assertEq(afterPool.reserveB, rebalanceEventData.reserveB, "RESERVE_B");
        assertEq(liquidityA.claimable + liquidityA.cancelable, rebalanceEventData.amountA, "AMOUNT_A");
        assertEq(liquidityB.claimable + liquidityB.cancelable, rebalanceEventData.amountB, "AMOUNT_B");
        assertEq(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A");
        assertEq(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B");
        assertEq(afterPool.orderListA.length, rebalanceEventData.orderListA.length, "ORDER_LIST_A");
        assertEq(
            OrderId.unwrap(afterPool.orderListA[0]), OrderId.unwrap(rebalanceEventData.orderListA[0]), "ORDER_LIST_A_0"
        );
        assertEq(afterPool.orderListB.length, rebalanceEventData.orderListB.length, "ORDER_LIST_B");
        assertEq(
            OrderId.unwrap(afterPool.orderListB[0]), OrderId.unwrap(rebalanceEventData.orderListB[0]), "ORDER_LIST_B_0"
        );
    }

    function testRebalanceShouldClearOrdersWhenComputeOrdersReverted() public {
        liquidityVault.mint(key, 1e18 + 141231, 1e21 + 241245, 0);
        liquidityVault.rebalance(key);

        strategy.setShouldRevert(true);

        liquidityVault.rebalance(key);

        ILiquidityVault.Pool memory afterPool = liquidityVault.getPool(key);
        assertEq(afterPool.orderListA.length, 0, "ORDER_LIST_A");
        assertEq(afterPool.orderListB.length, 0, "ORDER_LIST_B");
    }

    function testRebalanceAfterSomeOrdersHaveTaken() public {
        liquidityVault.mint(key, 1e18 + 141231, 1e21 + 241245, 0);
        liquidityVault.rebalance(key);

        ILiquidityVault.Liquidity memory liquidityA;
        ILiquidityVault.Liquidity memory liquidityB;

        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 beforeLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 beforeLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;

        takeRouter.take(IBookManager.TakeParams({key: keyA, tick: Tick.wrap(0), maxUnit: 2000}), "");

        // Record logs to capture the actual Rebalance event
        vm.recordLogs();
        liquidityVault.rebalance(key);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        RebalanceEventData memory rebalanceEventData;
        // Find and verify the Rebalance event
        bool rebalanceEventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ILiquidityVault.Rebalance.selector) {
                rebalanceEventFound = true;
                // Just verify that the event was emitted with correct indexed values
                assertEq(logs[i].topics[1], key, "EVENT_KEY_MISMATCH");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), address(this), "EVENT_CALLER_MISMATCH");
                (
                    rebalanceEventData.orderListA,
                    rebalanceEventData.orderListB,
                    rebalanceEventData.amountA,
                    rebalanceEventData.amountB,
                    rebalanceEventData.reserveA,
                    rebalanceEventData.reserveB
                ) = abi.decode(logs[i].data, (OrderId[], OrderId[], uint256, uint256, uint256, uint256));
                assertEq(rebalanceEventData.orderListA.length, 1, "ORDER_LIST_A");
                assertEq(rebalanceEventData.orderListB.length, 1, "ORDER_LIST_B");
                assertEq(rebalanceEventData.amountA, 9990000000000000, "AMOUNT_A");
                assertEq(rebalanceEventData.amountB, 10000000000000000, "AMOUNT_B");
                assertEq(rebalanceEventData.reserveA, 988012000000141231, "RESERVE_A");
                assertEq(rebalanceEventData.reserveB, 999992000000000241245, "RESERVE_B");
                break;
            }
        }
        assertTrue(rebalanceEventFound, "REBALANCE_EVENT_NOT_FOUND");

        ILiquidityVault.Pool memory afterPool = liquidityVault.getPool(key);
        (liquidityA, liquidityB) = liquidityVault.getLiquidity(key);
        uint256 afterLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
        uint256 afterLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;
        assertEq(afterPool.reserveA, rebalanceEventData.reserveA, "RESERVE_A");
        assertEq(afterPool.reserveB, rebalanceEventData.reserveB, "RESERVE_B");
        assertEq(liquidityA.claimable + liquidityA.cancelable, rebalanceEventData.amountA, "AMOUNT_A");
        assertEq(liquidityB.claimable + liquidityB.cancelable, rebalanceEventData.amountB, "AMOUNT_B");
        assertLt(afterLiquidityA, beforeLiquidityA, "LIQUIDITY_A");
        assertGt(afterLiquidityB, beforeLiquidityB, "LIQUIDITY_B");
        assertEq(tokenA.balanceOf(address(liquidityVault)), afterPool.reserveA, "RESERVE_A");
        assertEq(tokenB.balanceOf(address(liquidityVault)), afterPool.reserveB, "RESERVE_B");
        assertEq(afterPool.orderListA.length, rebalanceEventData.orderListA.length, "ORDER_LIST_A");
        assertEq(
            OrderId.unwrap(afterPool.orderListA[0]), OrderId.unwrap(rebalanceEventData.orderListA[0]), "ORDER_LIST_A_0"
        );
        assertEq(afterPool.orderListB.length, rebalanceEventData.orderListB.length, "ORDER_LIST_B");
        assertEq(
            OrderId.unwrap(afterPool.orderListB[0]), OrderId.unwrap(rebalanceEventData.orderListB[0]), "ORDER_LIST_B_0"
        );
    }

    function testCollect() public {
        uint256 beforeSupply = liquidityVault.mint(key, 1e18, 1e21, 0);
        liquidityVault.rebalance(key);
        liquidityVault.burn(key, beforeSupply / 2, 0, 0);

        assertEq(liquidityVault.fees(Currency.wrap(address(tokenA))), 50000000000000, "FEE_A");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenB))), 50000000000000000, "FEE_B");

        liquidityVault.collect(Currency.wrap(address(tokenA)), address(0x123123));
        assertEq(tokenA.balanceOf(address(0x123123)), 50000000000000, "A_BALANCE");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenA))), 0, "FEE_A");
        liquidityVault.collect(Currency.wrap(address(tokenB)), address(0x123123));
        assertEq(tokenB.balanceOf(address(0x123123)), 50000000000000000, "B_BALANCE");
        assertEq(liquidityVault.fees(Currency.wrap(address(tokenB))), 0, "FEE_B");
    }

    function testCollectOwnership() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x123)));
        vm.prank(address(0x123));
        liquidityVault.collect(Currency.wrap(address(tokenA)), address(0x3333));
    }

    function testName() public view {
        // Test with the existing key (TKA-TKB pair)
        string memory expectedName = "Liquidity Vault TKB-TKA";
        string memory actualName = liquidityVault.name(uint256(key));
        assertEq(actualName, expectedName, "NAME_MISMATCH");
    }

    function testSymbol() public view {
        // Test with the existing key (TKA-TKB pair)
        string memory expectedSymbol = "LV-TKB-TKA";
        string memory actualSymbol = liquidityVault.symbol(uint256(key));
        assertEq(actualSymbol, expectedSymbol, "SYMBOL_MISMATCH");
    }

    function testNameWithDifferentTokenPair() public {
        // Create new tokens with different symbols
        MockERC20 tokenC = new MockERC20("Token C", "TKC", 18);
        MockERC20 tokenD = new MockERC20("Token D", "TKD", 6);

        IBookManager.BookKey memory keyC = IBookManager.BookKey({
            base: Currency.wrap(address(tokenD)),
            unitSize: 1e12,
            quote: Currency.wrap(address(tokenC)),
            makerPolicy: FeePolicyLibrary.encode(true, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(true, 1200)
        });
        IBookManager.BookKey memory keyD = IBookManager.BookKey({
            base: Currency.wrap(address(tokenC)),
            unitSize: 1e12,
            quote: Currency.wrap(address(tokenD)),
            makerPolicy: FeePolicyLibrary.encode(false, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(false, 1200)
        });

        bytes32 newKey = liquidityVault.open(keyC, keyD, bytes32(uint256(0x1)), address(strategy));

        string memory expectedName = "Liquidity Vault TKD-TKC";
        string memory actualName = liquidityVault.name(uint256(newKey));
        assertEq(actualName, expectedName, "NAME_WITH_DIFFERENT_PAIR");

        string memory expectedSymbol = "LV-TKD-TKC";
        string memory actualSymbol = liquidityVault.symbol(uint256(newKey));
        assertEq(actualSymbol, expectedSymbol, "SYMBOL_WITH_DIFFERENT_PAIR");
    }

    function testNameAndSymbolWithNativeToken() public {
        // Create a pair with native token
        MockERC20 tokenE = new MockERC20("Token E", "TKE", 18);

        IBookManager.BookKey memory keyWithNative1 = IBookManager.BookKey({
            base: Currency.wrap(address(tokenE)),
            unitSize: 1e12,
            quote: CurrencyLibrary.NATIVE,
            makerPolicy: FeePolicyLibrary.encode(true, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(true, 1200)
        });
        IBookManager.BookKey memory keyWithNative2 = IBookManager.BookKey({
            base: CurrencyLibrary.NATIVE,
            unitSize: 1e12,
            quote: Currency.wrap(address(tokenE)),
            makerPolicy: FeePolicyLibrary.encode(false, -1000),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(false, 1200)
        });

        bytes32 nativeKey =
            liquidityVault.open(keyWithNative1, keyWithNative2, bytes32(uint256(0x2)), address(strategy));

        string memory expectedName = "Liquidity Vault TKE-ETH";
        string memory actualName = liquidityVault.name(uint256(nativeKey));
        assertEq(actualName, expectedName, "NAME_WITH_NATIVE");

        string memory expectedSymbol = "LV-TKE-ETH";
        string memory actualSymbol = liquidityVault.symbol(uint256(nativeKey));
        assertEq(actualSymbol, expectedSymbol, "SYMBOL_WITH_NATIVE");
    }

    function testDecimals() public view {
        uint8 decimals = liquidityVault.decimals(uint256(key));
        assertEq(decimals, 18, "DECIMALS_SHOULD_BE_18");
    }

    receive() external payable {}
}
