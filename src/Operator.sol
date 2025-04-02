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

    event SetOperator(address indexed operator, bool status);

    error NotOperator();

    ILiquidityVault public immutable liquidityVault;
    IDatastreamOracle public immutable datastreamOracle;
    uint256 public requestFeeAmount;
    mapping(address => bool) public isOperator;

    modifier onlyOperator() {
        if (!isOperator[msg.sender]) revert NotOperator();
        _;
    }

    constructor(ILiquidityVault liquidityVault_, IDatastreamOracle datastreamOracle_) Ownable(msg.sender) {
        liquidityVault = liquidityVault_;
        datastreamOracle = datastreamOracle_;
    }

    function initialize(address initialOwner, uint256 requestFeeAmount_) external initializer {
        _transferOwnership(initialOwner);
        requestFeeAmount = requestFeeAmount_;
        _setOperator(initialOwner, true);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function updatePosition(bytes32 key, uint256 oraclePrice, Tick tickA, Tick tickB, uint24 rate)
        external
        onlyOperator
    {
        ISimpleOracleStrategy oracleStrategy = ISimpleOracleStrategy(address(liquidityVault.getPool(key).strategy));
        if (oracleStrategy.isPaused(key)) {
            oracleStrategy.unpause(key);
        }
        oracleStrategy.updatePosition(key, oraclePrice, tickA, tickB, rate);
        liquidityVault.rebalance(key);
    }

    function pause(bytes32 key) external onlyOperator {
        ISimpleOracleStrategy(address(liquidityVault.getPool(key).strategy)).pause(key);
        liquidityVault.rebalance(key);
    }

    function requestOraclePublic() external {
        address feeToken = datastreamOracle.feeToken();
        IERC20(feeToken).transferFrom(msg.sender, address(this), requestFeeAmount);
        datastreamOracle.request(type(uint256).max);
    }

    function requestOracle(uint256 bitmap) external onlyOperator {
        datastreamOracle.request(bitmap);
    }

    function withdraw(Currency currency, address to, uint256 amount) external onlyOwner {
        currency.transfer(to, amount);
    }

    function setRequestFeeAmount(uint256 requestFeeAmount_) external onlyOwner {
        requestFeeAmount = requestFeeAmount_;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        _setOperator(operator, status);
    }

    function _setOperator(address operator, bool status) internal {
        isOperator[operator] = status;
        emit SetOperator(operator, status);
    }
}
