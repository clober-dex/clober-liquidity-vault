// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "clober-dex/v2-core/BookManager.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "../src/SimpleCouponStrategy.sol";
import "./mocks/OpenRouter.sol";

contract SimpleCouponStrategyTest is Test {
    using EpochLibrary for Epoch;
    using BookIdLibrary for IBookManager.BookKey;
    using TickLibrary for Tick;

    IBookManager public bookManager;
    OpenRouter public cloberOpenRouter;
    SimpleCouponStrategy public strategy;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    IBookManager.BookKey public keyA;
    IBookManager.BookKey public keyB;
    bytes32 public key;

    function setUp() public {
        vm.warp(1710317879);
        bookManager = new BookManager(address(this), address(0x123), "URI", "URI", "Name", "SYMBOL");
        cloberOpenRouter = new OpenRouter(bookManager);

        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);

        keyA = IBookManager.BookKey({
            base: Currency.wrap(address(tokenB)),
            unit: 1e12,
            quote: Currency.wrap(address(tokenA)),
            makerPolicy: FeePolicyLibrary.encode(true, 0),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(true, 0)
        });
        keyB = IBookManager.BookKey({
            base: Currency.wrap(address(tokenA)),
            unit: 1e12,
            quote: Currency.wrap(address(tokenB)),
            makerPolicy: FeePolicyLibrary.encode(true, 0),
            hooks: IHooks(address(0)),
            takerPolicy: FeePolicyLibrary.encode(true, 0)
        });
        cloberOpenRouter.open(keyA, "");
        cloberOpenRouter.open(keyB, "");

        BookId bookIdA = keyA.toId();
        BookId bookIdB = keyB.toId();
        if (BookId.unwrap(bookIdA) > BookId.unwrap(bookIdB)) (bookIdA, bookIdB) = (bookIdB, bookIdA);
        key = keccak256(abi.encodePacked(bookIdA, bookIdB));

        strategy = new SimpleCouponStrategy(bookManager, address(this));
        strategy.setCouponStrategy(key, EpochLibrary.current().add(1), 98534533154674428335, 146389476364791594973); // 4%, 6%
    }

    function testCalculateCouponPrice() public view {
        uint96 rate = 98534533154674428335; // 1.243 * 1e9
        Epoch current = EpochLibrary.current();

        assertEq(strategy.calculateCouponPrice(current.sub(1), rate), 0);
        uint256 p = strategy.calculateCouponPrice(current, rate);
        assertEq(p, 158969348697323155774989773);
        assertEq(FixedPointMathLib.mulDivDown(p, 1e18, 1 << 96), 2006475269052240);
        p = strategy.calculateCouponPrice(current.add(1), rate);
        assertEq(p, 256326894903603305869921641);
        assertEq(FixedPointMathLib.mulDivDown(p, 1e18, 1 << 96), 3235300261538362);
        p = strategy.calculateCouponPrice(current.add(11), rate);
        assertEq(p, 247208994008569190377949630);
        assertEq(FixedPointMathLib.mulDivDown(p, 1e18, 1 << 96), 3120216172678009);

        uint256 sum;
        for (uint16 i; i < 13; ++i) {
            uint256 price = strategy.calculateCouponPrice(current.add(i).sub(1), rate);
            sum += price;
        }
        assertEq(sum, 3059889965301269778927184551);
        assertEq(FixedPointMathLib.mulDivDown(sum, 1e18, 1 << 96), 38621241086468001);
    }

    function testCalculateCouponTick() public view {
        (Tick bidTick, Tick askTick) = strategy.calculateCouponTick(key);
        assertEq(Tick.unwrap(bidTick), -57340, "BID_TICK");
        assertEq(Tick.unwrap(askTick), 53363, "ASK_TICK");
        assertEq(FixedPointMathLib.mulDivDown(bidTick.toPrice(), 1e18, 1 << 128), 3235042158527404, "BID_PRICE");
        assertEq(FixedPointMathLib.mulDivDown(askTick.toPrice(), 1e18, 1 << 128), 207687221007653627846, "ASK_PRICE");
    }

    function testConvertAmount() public view {
        uint256 amount = 1e18;
        BookId bookIdA = keyA.toId();
        BookId bookIdB = keyB.toId();

        assertEq(strategy.convertAmount(bookIdA, bookIdB, amount, true), 3235042158527404, "A -> B");
        assertEq(strategy.convertAmount(bookIdA, bookIdB, amount, false), 207687221007653627846, "B -> A");
    }

    function testComputeAllocation() public view {
        (SimpleCouponStrategy.Liquidity[] memory bids, SimpleCouponStrategy.Liquidity[] memory asks) =
            strategy.computeAllocation(keyA.toId(), 1e18 + 123, keyB.toId(), 1e15 - 123);
        assertEq(bids.length, 1, "BIDS_LENGTH");
        assertEq(asks.length, 1, "ASKS_LENGTH");
        assertEq(Tick.unwrap(bids[0].tick), -57340, "BID_TICK");
        assertEq(bids[0].rawAmount, 1e6, "BID_AMOUNT");
        assertEq(Tick.unwrap(asks[0].tick), 53363, "ASK_TICK");
        assertEq(asks[0].rawAmount, 1e3 - 1, "ASK_AMOUNT");
    }

    function testSetCouponStrategy() public {
        Epoch epoch = EpochLibrary.current().add(2);
        uint96 bidRate = 123456789;
        uint96 askRate = 987654321;

        strategy.setCouponStrategy(key, epoch, bidRate, askRate);

        SimpleCouponStrategy.CouponStrategy memory s = strategy.getCouponStrategy(key);
        assertEq(Epoch.unwrap(s.epoch), Epoch.unwrap(epoch), "EPOCH");
        assertEq(s.bidRate, bidRate, "BID_RATE");
        assertEq(s.askRate, askRate, "ASK_RATE");
    }

    function testSetCouponStrategyAccess() public {
        Epoch epoch = EpochLibrary.current().add(2);
        uint96 bidRate = 123456789;
        uint96 askRate = 987654321;

        vm.prank(address(123));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(123))));
        strategy.setCouponStrategy(key, epoch, bidRate, askRate);
    }
}
