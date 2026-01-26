// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IBookManager} from "clober-dex/v2-core/interfaces/IBookManager.sol";

import {LiquidityVault} from "../src/LiquidityVault.sol";
import {Operator} from "../src/Operator.sol";
import {Minter} from "../src/Minter.sol";
import {SimpleOracleStrategy} from "../src/SimpleOracleStrategy.sol";
import {ChainlinkOracle} from "../src/oracle/ChainlinkOracle.sol";
import {IDatastreamOracle} from "../src/interfaces/IDatastreamOracle.sol";
import {IOracle} from "../src/interfaces/IOracle.sol";
import {ILiquidityVault} from "../src/interfaces/ILiquidityVault.sol";

contract DeployScript is Script {
    // NOTE: This repo deploy scripts are intentionally scoped.
    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant MONAD_CHAIN_ID = 143;

    // --- Owners (Safe) ---
    address internal constant BASE_SAFE = 0xfb976Bae0b3Ef71843F1c6c63da7Df2e44B3836d;
    address internal constant MONAD_SAFE = 0xfb976Bae0b3Ef71843F1c6c63da7Df2e44B3836d;

    // --- Core dependencies ---
    address internal constant BASE_BOOK_MANAGER = 0x8Ca3a6F4a6260661fcb9A25584c796a1Fa380112;
    address internal constant MONAD_BOOK_MANAGER = 0x6657d192273731C3cAc646cc82D5F28D0CBE8CCC;

    // Router used by `Minter`
    address internal constant BASE_MINTER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address internal constant MONAD_MINTER_ROUTER = 0x7B58A24C5628881a141D630f101Db433D419B372;

    // --- Oracle parameters ---
    // Chainlink sequencer uptime feeds (L2 only; set to 0 for L1-like chains).
    address internal constant BASE_SEQUENCER_ORACLE = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
    address internal constant MONAD_SEQUENCER_ORACLE = address(0);

    uint256 internal constant ORACLE_TIMEOUT = 24 hours;
    uint256 internal constant SEQUENCER_GRACE_PERIOD = 1 hours;

    // --- Vault parameters ---
    uint256 internal constant BURN_FEE_RATE = 100;

    struct DeployConfig {
        // Deployer EOA used for Foundry broadcast transactions.
        // This MUST match the signer configured by `forge script --account ... --broadcast`.
        address deployer;
        address owner;
        address bookManager;
        address minterRouter;
        address sequencerOracle;
        string nativeSymbol;
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function deployAll() external broadcast {
        DeployConfig memory cfg = _resolveDeployConfig(block.chainid);
        cfg.deployer = vm.envAddress("DEPLOYER");
        console2.log("Deployer:", cfg.deployer);

        // LiquidityVault (UUPS proxy)
        address vaultProxy = _deployLiquidityVault(cfg);

        // Oracle (Chainlink)
        address oracle = _deployOracle(cfg);

        // SimpleOracleStrategy (UUPS proxy)
        address strategyProxy = _deploySimpleOracleStrategy(cfg, oracle, vaultProxy);

        // Operator (UUPS proxy)
        address operatorProxy = _deployOperator(cfg, vaultProxy);

        // Minter (no proxy)
        address minter = _deployMinter(cfg, vaultProxy);

        // Post-deploy wiring (assumes the deployer owns the newly deployed proxies).
        _setStrategyOperator(strategyProxy, operatorProxy);

        // Transfer ownership to the target owner AFTER all owner-only setup.
        _transferOwnership(vaultProxy, cfg.owner);
        _transferOwnership(strategyProxy, cfg.owner);
        _transferOwnership(operatorProxy, cfg.owner);

        console2.log("=== Deploy summary ===");
        console2.log("LiquidityVault:", vaultProxy);
        console2.log("Oracle:", oracle);
        console2.log("SimpleOracleStrategy:", strategyProxy);
        console2.log("Operator:", operatorProxy);
        console2.log("Minter:", minter);
    }

    function _deployLiquidityVault(DeployConfig memory cfg) internal returns (address proxy) {
        // IMPORTANT: Initialize with deployer first, then transfer ownership later.
        address implementation = address(new LiquidityVault(IBookManager(cfg.bookManager), BURN_FEE_RATE));
        console2.log("LiquidityVault implementation:", implementation);

        bytes memory initData = abi.encodeCall(LiquidityVault.initialize, (cfg.deployer));
        proxy = address(new ERC1967Proxy(implementation, initData));
        console2.log("LiquidityVault proxy:", proxy);

        // Metadata is only settable by owner.
        LiquidityVault(payable(proxy)).initializeMetadata("Clober Liquidity Vault", "CLV", cfg.nativeSymbol);
        console2.log("LiquidityVault metadata initialized");
    }

    function _deployOracle(DeployConfig memory cfg) internal returns (address oracle) {
        // Base/Monad: Chainlink oracle (non-proxy)
        oracle = address(new ChainlinkOracle(cfg.sequencerOracle, ORACLE_TIMEOUT, SEQUENCER_GRACE_PERIOD, cfg.owner));
        console2.log("ChainlinkOracle:", oracle);
        return oracle;
    }

    function _deploySimpleOracleStrategy(DeployConfig memory cfg, address oracle, address liquidityVault)
        internal
        returns (address proxy)
    {
        // IMPORTANT: Initialize with deployer first, then transfer ownership later.
        address implementation = address(
            new SimpleOracleStrategy(
                IOracle(oracle), ILiquidityVault(payable(liquidityVault)), IBookManager(cfg.bookManager)
            )
        );
        console2.log("SimpleOracleStrategy implementation:", implementation);

        bytes memory initData = abi.encodeCall(SimpleOracleStrategy.initialize, (cfg.deployer));
        proxy = address(new ERC1967Proxy(implementation, initData));
        console2.log("SimpleOracleStrategy proxy:", proxy);
    }

    function _deployOperator(DeployConfig memory cfg, address liquidityVault) internal returns (address proxy) {
        // IMPORTANT: Initialize with deployer first, then transfer ownership later.
        address implementation =
            address(new Operator(ILiquidityVault(payable(liquidityVault)), IDatastreamOracle(address(0))));
        console2.log("Operator implementation:", implementation);

        bytes memory initData = abi.encodeCall(Operator.initialize, (cfg.deployer, 0));
        proxy = address(new ERC1967Proxy(implementation, initData));
        console2.log("Operator proxy:", proxy);
    }

    function _deployMinter(DeployConfig memory cfg, address liquidityVault) internal returns (address minter) {
        minter = address(new Minter(cfg.bookManager, payable(liquidityVault), cfg.minterRouter));
        console2.log("Minter:", minter);
    }

    function _setStrategyOperator(address strategyProxy, address operatorProxy) internal {
        SimpleOracleStrategy(strategyProxy).setOperator(operatorProxy, true);
        console2.log("Strategy operator set:", operatorProxy);
    }

    function _transferOwnership(address ownable2Step, address newOwner) internal {
        // Ownable2Step: this sets `pendingOwner`. The new owner must call `acceptOwnership()`.
        IOwnable2Step(ownable2Step).transferOwnership(newOwner);
        console2.log("Ownership transfer initiated (pendingOwner):", newOwner);
    }

    function _resolveDeployConfig(uint256 chainId) internal pure returns (DeployConfig memory cfg) {
        if (chainId == BASE_CHAIN_ID) {
            cfg.owner = BASE_SAFE;
            cfg.bookManager = BASE_BOOK_MANAGER;
            cfg.minterRouter = BASE_MINTER_ROUTER;
            cfg.sequencerOracle = BASE_SEQUENCER_ORACLE;
            cfg.nativeSymbol = "ETH";
            return cfg;
        }
        if (chainId == MONAD_CHAIN_ID) {
            cfg.owner = MONAD_SAFE;
            cfg.bookManager = MONAD_BOOK_MANAGER;
            cfg.minterRouter = MONAD_MINTER_ROUTER;
            cfg.sequencerOracle = MONAD_SEQUENCER_ORACLE;
            cfg.nativeSymbol = "MON";
            return cfg;
        }
        revert("Unsupported chain");
    }
}

interface IOwnable2Step {
    function transferOwnership(address newOwner) external;
}
