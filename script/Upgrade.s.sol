// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";

import {IBookManager} from "clober-dex/v2-core/interfaces/IBookManager.sol";
import {IVerifierProxy} from "../src/external/chainlink/IVerifierProxy.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {ILiquidityVault} from "../src/interfaces/ILiquidityVault.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {LiquidityVault} from "../src/LiquidityVault.sol";
import {Operator} from "../src/Operator.sol";
import {SimpleOracleStrategy} from "../src/SimpleOracleStrategy.sol";
import {DatastreamOracle} from "../src/oracle/DatastreamOracle.sol";

contract UpgradeScript is Script {
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    // Generic upgrade helper (proxy must be UUPS-compatible).
    function upgradeTo(address proxy, address newImplementation) public broadcast {
        UUPSUpgradeable(proxy).upgradeToAndCall(newImplementation, "");
        console2.log("Upgraded proxy:", proxy);
        console2.log("New implementation:", newImplementation);
    }

    // ---- LiquidityVault ----
    function deployLiquidityVaultImplementation(address proxy) public broadcast returns (address implementation) {
        LiquidityVault current = LiquidityVault(payable(proxy));
        implementation = address(new LiquidityVault(current.bookManager(), current.burnFeeRate()));
        console2.log("LiquidityVault new implementation:", implementation);
    }

    function upgradeLiquidityVault(address proxy) external {
        address implementation = deployLiquidityVaultImplementation(proxy);
        upgradeTo(proxy, implementation);
    }

    // ---- Operator ----
    function deployOperatorImplementation(address proxy) public broadcast returns (address implementation) {
        Operator current = Operator(payable(proxy));
        implementation = address(new Operator(current.liquidityVault(), current.datastreamOracle()));
        console2.log("Operator new implementation:", implementation);
    }

    function upgradeOperator(address proxy) external {
        address implementation = deployOperatorImplementation(proxy);
        upgradeTo(proxy, implementation);
    }

    // ---- SimpleOracleStrategy ----
    function deploySimpleOracleStrategyImplementation(address proxy) public broadcast returns (address implementation) {
        SimpleOracleStrategy current = SimpleOracleStrategy(payable(proxy));
        implementation = address(new SimpleOracleStrategy(current.referenceOracle(), current.liquidityVault(), current.bookManager()));
        console2.log("SimpleOracleStrategy new implementation:", implementation);
    }

    function upgradeSimpleOracleStrategy(address proxy) external {
        address implementation = deploySimpleOracleStrategyImplementation(proxy);
        upgradeTo(proxy, implementation);
    }

    // ---- DatastreamOracle ----
    function deployDatastreamOracleImplementation(address proxy) public broadcast returns (address implementation) {
        DatastreamOracle current = DatastreamOracle(payable(proxy));
        implementation = address(new DatastreamOracle(address(current.verifier())));
        console2.log("DatastreamOracle new implementation:", implementation);
    }

    function upgradeDatastreamOracle(address proxy) external {
        address implementation = deployDatastreamOracleImplementation(proxy);
        upgradeTo(proxy, implementation);
    }
}

