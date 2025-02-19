// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Currency, CurrencyLibrary} from "clober-dex/v2-core/libraries/Currency.sol";

import "./interfaces/ISimpleOracleStrategy.sol";
import "./interfaces/ILiquidityVault.sol";
import {IDatastreamOracle} from "./interfaces/IDatastreamOracle.sol";

contract Operator is UUPSUpgradeable, Initializable, Ownable2Step {
    using CurrencyLibrary for Currency;

    ILiquidityVault public immutable liquidityVault;
    IDatastreamOracle public immutable datastreamOracle;
    uint256 public requestFeeAmount;

    constructor(ILiquidityVault liquidityVault_, IDatastreamOracle datastreamOracle_) Ownable(msg.sender) {
        liquidityVault = liquidityVault_;
        datastreamOracle = datastreamOracle_;
    }

    function initialize(address initialOwner, uint256 requestFeeAmount_) external initializer {
        _transferOwnership(initialOwner);
        requestFeeAmount = requestFeeAmount_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function updatePosition(bytes32 key, uint256 oraclePrice, Tick tickA, Tick tickB, uint24 rate) external onlyOwner {
        ISimpleOracleStrategy oracleStrategy = ISimpleOracleStrategy(address(liquidityVault.getPool(key).strategy));
        if (oracleStrategy.isPaused(key)) {
            oracleStrategy.unpause(key);
        }
        oracleStrategy.updatePosition(key, oraclePrice, tickA, tickB, rate);
        liquidityVault.rebalance(key);
    }

    function pause(bytes32 key) external onlyOwner {
        ISimpleOracleStrategy(address(liquidityVault.getPool(key).strategy)).pause(key);
        liquidityVault.rebalance(key);
    }

    function requestOraclePublic() external {
        address feeToken = datastreamOracle.feeToken();
        IERC20(feeToken).transferFrom(msg.sender, address(this), requestFeeAmount);
        datastreamOracle.request(type(uint256).max);
    }

    function requestOracle(uint256 bitmap) external onlyOwner {
        datastreamOracle.request(bitmap);
    }

    function withdraw(Currency currency, address to, uint256 amount) external onlyOwner {
        currency.transfer(to, amount);
    }

    function setRequestFeeAmount(uint256 requestFeeAmount_) external onlyOwner {
        requestFeeAmount = requestFeeAmount_;
    }
}
