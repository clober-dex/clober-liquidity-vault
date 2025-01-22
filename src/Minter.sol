// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "./interfaces/IMinter.sol";

contract Minter is IMinter {
    using CurrencyLibrary for Currency;
    using PermitParamsLibrary for *;
    using SafeERC20 for IERC20;

    IBookManager public immutable bookManager;
    LiquidityVault public immutable liquidityVault;
    address public immutable router;

    constructor(address _bookManager, address payable _liquidityVault, address _router) {
        bookManager = IBookManager(_bookManager);
        liquidityVault = LiquidityVault(_liquidityVault);
        router = _router;
    }

    function mint(
        bytes32 key,
        uint256 amountA,
        uint256 amountB,
        uint256 minLpAmount,
        ERC20PermitParams calldata currencyAPermitParams,
        ERC20PermitParams calldata currencyBPermitParams,
        SwapParams calldata swapParams
    ) external payable {
        (BookId bookIdA,) = liquidityVault.getBookPairs(key);
        IBookManager.BookKey memory bookKey = IBookManager(bookManager).getBookKey(bookIdA);

        currencyAPermitParams.tryPermit(Currency.unwrap(bookKey.quote), msg.sender, address(this));
        currencyBPermitParams.tryPermit(Currency.unwrap(bookKey.base), msg.sender, address(this));

        if (!bookKey.quote.isNative()) {
            IERC20(Currency.unwrap(bookKey.quote)).safeTransferFrom(msg.sender, address(this), amountA);
        }

        if (!bookKey.base.isNative()) {
            IERC20(Currency.unwrap(bookKey.base)).safeTransferFrom(msg.sender, address(this), amountB);
        }

        if (swapParams.data.length > 0) {
            _swap(swapParams);
        }

        uint256 lpAmount = _mint(key, bookKey.quote, bookKey.base, minLpAmount);

        liquidityVault.transfer(msg.sender, uint256(key), lpAmount);

        uint256 balance = bookKey.quote.balanceOfSelf();
        if (balance > 0) bookKey.quote.transfer(msg.sender, balance);
        balance = bookKey.base.balanceOfSelf();
        if (balance > 0) bookKey.base.transfer(msg.sender, balance);
    }

    function _swap(SwapParams calldata swapParams) internal {
        uint256 value = swapParams.inCurrency.isNative() ? swapParams.amount : 0;
        _approve(swapParams.inCurrency, router, swapParams.amount);

        (bool success, bytes memory result) = router.call{value: value}(swapParams.data);
        if (!success) revert RouterSwapFailed(result);

        _approve(swapParams.inCurrency, router, 0);
    }

    function _mint(bytes32 key, Currency quote, Currency base, uint256 minLpAmount)
        internal
        returns (uint256 lpAmount)
    {
        uint256 quoteBalance = quote.balanceOfSelf();
        uint256 baseBalance = base.balanceOfSelf();
        _approve(quote, address(liquidityVault), quoteBalance);
        _approve(base, address(liquidityVault), baseBalance);
        lpAmount = liquidityVault.mint{value: address(this).balance}(key, quoteBalance, baseBalance, minLpAmount);
        _approve(quote, address(liquidityVault), 0);
        _approve(base, address(liquidityVault), 0);
    }

    function _approve(Currency currency, address spender, uint256 amount) internal {
        if (!currency.isNative()) {
            IERC20(Currency.unwrap(currency)).forceApprove(spender, amount);
        }
    }

    receive() external payable {}
}
