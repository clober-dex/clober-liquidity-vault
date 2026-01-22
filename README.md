# Clober-Liquidity-Vault

## Install

### Prerequisites

- We use [Forge Foundry](https://github.com/foundry-rs/foundry) for test. Follow the [guide](https://github.com/foundry-rs/foundry#installation) to install Foundry.

### Installing From Source

```bash
git clone https://github.com/clober-dex/liquidity-vault && cd liquidity-vault
forge install
```

## Documentation

- **[Development Guide](./DEVELOPMENT_GUIDE.md)** - Complete guide for third-party developers to create custom vaults by implementing the IStrategy interface

## Usage

### Build

```bash
forge build
```

### Tests

```bash
forge test
```

### Linting

```bash
forge fmt
```

### Scripts (Foundry)

This repo includes Foundry `forge script` deploy/upgrade helpers under `script/`.

- Supported networks: `base`, `monad` (see `foundry.toml` `[rpc_endpoints]`)
- Environment: copy `env.example` to `.env` and fill in values.

Examples:

```bash
cp env.example .env
./script/deploy-all.sh base
./script/deploy-all.sh monad
./script/upgrade-uups.sh base upgradeLiquidityVault 0xYourProxyAddress
```

## Deployments

### Base (chainId: 8453)

Upgradeable contracts list **proxy addresses only**.

| Contract | Address | Explorer |
| - | - | - |
| LiquidityVault (Proxy) | `0x5b351C9eED322616F76b8669176412e1808c06B5` | `https://basescan.org/address/0x5b351C9eED322616F76b8669176412e1808c06B5` |
| SimpleOracleStrategy (Proxy) | `0x454B85D03Ffbf86c2bFb0DaCd21d2687d36FE892` | `https://basescan.org/address/0x454B85D03Ffbf86c2bFb0DaCd21d2687d36FE892` |
| Operator (Proxy) | `0x7bA560D09BD5379216f1E4393906701210CB63Fb` | `https://basescan.org/address/0x7bA560D09BD5379216f1E4393906701210CB63Fb` |
| ChainlinkOracle | `0x3Ae1e578E511B7Bd9f777A4Bea0F6a6633Fb3c83` | `https://basescan.org/address/0x3Ae1e578E511B7Bd9f777A4Bea0F6a6633Fb3c83` |
| Minter | `0xC8f98f60Ce54E72cCBb18AA8628fa7a2885F098f` | `https://basescan.org/address/0xC8f98f60Ce54E72cCBb18AA8628fa7a2885F098f` |

### Monad (chainId: 143)

Addresses are sourced from `deployments/143/`. Upgradeable contracts list **proxy addresses only**.

| Contract | Address | Explorer (Monvision) |
| - | - | - |
| LiquidityVault (Proxy) | `0xB09684f5486d1af80699BbC27f14dd5A905da873` | `https://monadvision.com/address/0xB09684f5486d1af80699BbC27f14dd5A905da873` |
| SimpleOracleStrategy (Proxy) | `0x54cd5332b1689b6506Ce089DA5651B1A814e9E7D` | `https://monadvision.com/address/0x54cd5332b1689b6506Ce089DA5651B1A814e9E7D` |
| Operator (Proxy) | `0xCBd3C0B81A9a36356a3669A7f60A0d2F0846195B` | `https://monadvision.com/address/0xCBd3C0B81A9a36356a3669A7f60A0d2F0846195B` |
| ChainlinkOracle | `0xFbc3CF3d77e128282c6A99D5642f28081AAf2269` | `https://monadvision.com/address/0xFbc3CF3d77e128282c6A99D5642f28081AAf2269` |
| Minter | `0xb1251BF43Bb7De76DE7e6CE7B64aF843dfc9d242` | `https://monadvision.com/address/0xb1251BF43Bb7De76DE7e6CE7B64aF843dfc9d242` |
