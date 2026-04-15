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

- Supported networks: `base`, `monad`, `arbitrum` (see `foundry.toml` `[rpc_endpoints]`)
- Environment: copy `env.example` to `.env` and fill in values.

Examples:

```bash
cp env.example .env
./script/deploy-all.sh base
./script/deploy-all.sh monad
./script/deploy-all.sh arbitrum
./script/upgrade-uups.sh base upgradeLiquidityVault 0xYourProxyAddress
```

## Deployments

### Base (chainId: 8453)

Upgradeable contracts list **proxy addresses only**.

| Contract | Address | Explorer |
| - | - | - |
| LiquidityVault (Proxy) | `0xca1f6e4ae690d06e3bf943b9019c5ca060c0b834` | `https://basescan.org/address/0xca1f6e4ae690d06e3bf943b9019c5ca060c0b834` |
| SimpleOracleStrategy (Proxy) | `0x29e07197ccf70d0ac6cb0a3c307627819f5f2777` | `https://basescan.org/address/0x29e07197ccf70d0ac6cb0a3c307627819f5f2777` |
| Operator (Proxy) | `0x00f7a0c7e66f0e3a10d9e980e0854ebe0e308625` | `https://basescan.org/address/0x00f7a0c7e66f0e3a10d9e980e0854ebe0e308625` |
| ChainlinkOracle | `0xd08e387542121f8305bb976e222cbb7c1a56dd77` | `https://basescan.org/address/0xd08e387542121f8305bb976e222cbb7c1a56dd77` |
| Minter | `0x2092a58c47f3444c82871ecdd5ea1e96c80c59d1` | `https://basescan.org/address/0x2092a58c47f3444c82871ecdd5ea1e96c80c59d1` |

### Monad (chainId: 143)

Addresses are sourced from `deployments/143/`. Upgradeable contracts list **proxy addresses only**.

| Contract | Address | Explorer (Monvision) |
| - | - | - |
| LiquidityVault (Proxy) | `0xB09684f5486d1af80699BbC27f14dd5A905da873` | `https://monadvision.com/address/0xB09684f5486d1af80699BbC27f14dd5A905da873` |
| SimpleOracleStrategy (Proxy) | `0x54cd5332b1689b6506Ce089DA5651B1A814e9E7D` | `https://monadvision.com/address/0x54cd5332b1689b6506Ce089DA5651B1A814e9E7D` |
| Operator (Proxy) | `0xCBd3C0B81A9a36356a3669A7f60A0d2F0846195B` | `https://monadvision.com/address/0xCBd3C0B81A9a36356a3669A7f60A0d2F0846195B` |
| ChainlinkOracle | `0xFbc3CF3d77e128282c6A99D5642f28081AAf2269` | `https://monadvision.com/address/0xFbc3CF3d77e128282c6A99D5642f28081AAf2269` |
| Minter | `0xb1251BF43Bb7De76DE7e6CE7B64aF843dfc9d242` | `https://monadvision.com/address/0xb1251BF43Bb7De76DE7e6CE7B64aF843dfc9d242` |

### Arbitrum (chainId: 42161)

Upgradeable contracts list **proxy addresses only**.

| Contract | Address | Explorer |
| - | - | - |
| LiquidityVault (Proxy) | `0x21bb8709Fe339b227795809B0cb8Eb5a152Ad7E1` | `https://arbiscan.io/address/0x21bb8709Fe339b227795809B0cb8Eb5a152Ad7E1` |
| SimpleOracleStrategy (Proxy) | `0x2610DC1F2e625E57F07B0ce17152b0f4C6520bcA` | `https://arbiscan.io/address/0x2610DC1F2e625E57F07B0ce17152b0f4C6520bcA` |
| Operator (Proxy) | `0xcd166F67F13c7d5C4B899Fb1c980Dceff278F029` | `https://arbiscan.io/address/0xcd166F67F13c7d5C4B899Fb1c980Dceff278F029` |
| ChainlinkOracle | `0xBB8363721696a44273b2EdC93482AFF86C48898F` | `https://arbiscan.io/address/0xBB8363721696a44273b2EdC93482AFF86C48898F` |
| Minter | `0xFe87e2Cc08A8801a12105d862AEe71470883A76d` | `https://arbiscan.io/address/0xFe87e2Cc08A8801a12105d862AEe71470883A76d` |
