# Clober Liquidity Vault Development Guide

This guide explains how third-party developers can create their own Vault by implementing the `IStrategy` interface and integrating with the Clober Liquidity Vault system.

## Overview

The Clober Liquidity Vault is a sophisticated DeFi protocol that allows users to provide liquidity to trading pairs through automated market making strategies. To create a custom vault, developers must implement the `IStrategy` interface, which defines how the vault manages liquidity positions.

## Prerequisites

- Basic understanding of Solidity and smart contract development
- Familiarity with DeFi concepts like AMM (Automated Market Making)
- Knowledge of the Clober DEX v2-core system
- Development environment with Foundry or Hardhat

## 1. Implementing the IStrategy Interface

The `IStrategy` interface is the core component that defines your vault's behavior. You **MUST** implement all the following functions:

### Required Functions

#### `computeOrders(bytes32 key) external view returns (Order[] memory ordersA, Order[] memory ordersB)`

This is the **most critical function** that determines your vault's liquidity allocation strategy.

**Purpose**: Computes the optimal liquidity distribution across different price ticks for both tokens in the trading pair.

**Parameters**:

- `key`: The unique identifier for the pool

**Returns**:

- `ordersA`: Array of orders for the first token (quote token)
- `ordersB`: Array of orders for the second token (base token)

**Order Structure**:

```solidity
struct Order {
    Tick tick;        // The price tick for the order
    uint64 rawAmount; // The amount of liquidity units to place
}
```

**Implementation Requirements**:

- Must return valid `Order` arrays for both tokens
- The `tick` values determine the price levels where liquidity will be placed
- `rawAmount` represents the liquidity units (will be multiplied by the book's `unitSize`)
- If an error occurs, the function should clear pool orders
- If the list is empty, current orders should be retained

**Example Implementation**:

```solidity
function computeOrders(bytes32 key) external view returns (Order[] memory ordersA, Order[] memory ordersB) {
    // Your strategy logic here
    // Example: Place liquidity around the current market price
    uint256 currentTick = getCurrentTick(key);

    ordersA = new Order[](3);
    ordersA[0] = Order(Tick.wrap(int24(currentTick - 10)), 1000);
    ordersA[1] = Order(Tick.wrap(int24(currentTick)), 2000);
    ordersA[2] = Order(Tick.wrap(int24(currentTick + 10)), 1000);

    ordersB = new Order[](3);
    ordersB[0] = Order(Tick.wrap(int24(currentTick - 10)), 1000);
    ordersB[1] = Order(Tick.wrap(int24(currentTick)), 2000);
    ordersB[2] = Order(Tick.wrap(int24(currentTick + 10)), 1000);

    return (ordersA, ordersB);
}
```

#### `mintHook(address sender, bytes32 key, uint256 mintAmount, uint256 lastTotalSupply) external`

**Purpose**: Called after a user mints new vault tokens, allowing your strategy to react to new liquidity.

**Parameters**:

- `sender`: Address of the user who minted tokens
- `key`: Pool identifier
- `mintAmount`: Amount of vault tokens minted
- `lastTotalSupply`: Total supply before minting

**Implementation Requirements**:

- Can be used to rebalance positions or adjust strategy parameters
- Should handle any strategy-specific logic needed after new liquidity is added
- Can be empty if no post-mint actions are required

#### `burnHook(address sender, bytes32 key, uint256 burnAmount, uint256 lastTotalSupply) external`

**Purpose**: Called after a user burns vault tokens, allowing your strategy to react to liquidity removal.

**Parameters**:

- `sender`: Address of the user who burned tokens
- `key`: Pool identifier
- `burnAmount`: Amount of vault tokens burned
- `lastTotalSupply`: Total supply before burning

**Implementation Requirements**:

- Can be used to rebalance positions or adjust strategy parameters
- Should handle any strategy-specific logic needed after liquidity is removed
- Can be empty if no post-burn actions are required

#### `rebalanceHook(address sender, bytes32 key, Order[] memory liquidityA, Order[] memory ordersB, uint256 amountA, uint256 amountB) external`

**Purpose**: Called after rebalancing operations, providing information about the new liquidity distribution.

**Parameters**:

- `sender`: Address that triggered the rebalance
- `key`: Pool identifier
- `liquidityA`: New liquidity orders for the first token
- `liquidityB`: New liquidity orders for the second token
- `amountA`: Amount of the first token allocated
- `amountB`: Amount of the second token allocated

**Implementation Requirements**:

- Can be used to track strategy performance or update internal state
- Should handle any strategy-specific logic needed after rebalancing
- Can be empty if no post-rebalance actions are required

## 2. Complete Strategy Implementation Example

Here's a complete example of a simple strategy implementation:

> **⚠️ WARNING: This is a basic example for educational purposes only. DO NOT use this in production as it lacks proper risk management, oracle integration, and security features.**

```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IStrategy} from "./interfaces/IStrategy.sol";
import {Tick} from "clober-dex/v2-core/libraries/Tick.sol";

contract SimpleStrategy is IStrategy {
    // Strategy-specific state variables
    mapping(bytes32 => uint256) public poolTicks;

    function computeOrders(bytes32 key) external view returns (Order[] memory ordersA, Order[] memory ordersB) {
        uint256 currentTick = poolTicks[key];
        if (currentTick == 0) {
            // Default tick if not set
            currentTick = 1000000; // Example tick value
        }

        // Create a simple 3-tick strategy around the current price
        ordersA = new Order[](3);
        ordersA[0] = Order(Tick.wrap(int24(int256(currentTick - 100))), 1000);
        ordersA[1] = Order(Tick.wrap(int24(int256(currentTick))), 2000);
        ordersA[2] = Order(Tick.wrap(int24(int256(currentTick + 100))), 1000);

        ordersB = new Order[](3);
        ordersB[0] = Order(Tick.wrap(int24(int256(currentTick - 100))), 1000);
        ordersB[1] = Order(Tick.wrap(int24(int256(currentTick))), 2000);
        ordersB[2] = Order(Tick.wrap(int24(int256(currentTick + 100))), 1000);

        return (ordersA, ordersB);
    }

    function mintHook(address sender, bytes32 key, uint256 mintAmount, uint256 lastTotalSupply) external {
        // Optional: Add logic for post-mint actions
        // For example, update internal state or emit events
    }

    function burnHook(address sender, bytes32 key, uint256 burnAmount, uint256 lastTotalSupply) external {
        // Optional: Add logic for post-burn actions
    }

    function rebalanceHook(
        address sender,
        bytes32 key,
        Order[] memory liquidityA,
        Order[] memory liquidityB,
        uint256 amountA,
        uint256 amountB
    ) external {
        // Optional: Add logic for post-rebalance actions
        // For example, update the current tick based on new liquidity
        if (liquidityA.length > 0) {
            poolTicks[key] = uint256(int256(Tick.unwrap(liquidityA[0].tick)));
        }
    }

    // Function to update strategy parameters
    function updateTick(bytes32 key, uint256 newTick) external {
        poolTicks[key] = newTick;
    }
}
```

### Production-Ready Strategy Reference

For production use, refer to the `SimpleOracleStrategy` contract in the codebase (`src/SimpleOracleStrategy.sol`). This is a more sophisticated implementation that:

- **Uses external oracles** to determine market prices
- **Implements spread-based orders** with one order above and one below the oracle price
- **Includes proper risk management** with configurable thresholds and rebalancing logic
- **Has access controls** and operator management
- **Handles edge cases** and provides pause functionality

The `SimpleOracleStrategy` demonstrates how to build a robust, production-ready strategy that automatically adjusts liquidity based on oracle prices while maintaining proper risk controls.

## 3. Deploying Your Strategy

After implementing your strategy contract:

1. **Compile the contract** using your preferred development framework
2. **Deploy to the target network** (Ethereum mainnet, testnets, or other supported chains)
3. **Verify the contract** on the network's block explorer
4. **Test thoroughly** on testnets before mainnet deployment

## 4. Opening a Vault with Your Strategy

Once your strategy is deployed, you can create a vault by calling `LiquidityVault.open()`:

```solidity
// Example call to open a vault
liquidityVault.open(
    bookKeyA,    // First book configuration
    bookKeyB,    // Second book configuration
    salt,        // Unique salt for the pool
    strategyAddress // Your deployed strategy contract address
);
```

**Parameters**:

- `bookKeyA` and `bookKeyB`: Book configurations for the trading pair
- `salt`: Unique identifier to distinguish between different pools with the same tokens
- `strategyAddress`: The address of your deployed strategy contract

## 5. Providing Liquidity

After opening the vault:

1. **Users can mint vault tokens** by calling `LiquidityVault.mint()`
2. **Your strategy will automatically manage** the liquidity distribution
3. **The vault handles** order placement, cancellation, and claiming automatically
4. **Users can burn tokens** to withdraw their liquidity

## Important Considerations

### Security

- **Audit your strategy** before mainnet deployment
- **Test thoroughly** with various market conditions
- **Implement proper access controls** if needed
- **Handle edge cases** gracefully

---

**Disclaimer**: This guide is for educational purposes. Always conduct thorough testing and consider professional audits before deploying to mainnet. The authors are not responsible for any financial losses resulting from the use of this guide.
