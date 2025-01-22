import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { deployWithVerify, BOOK_MANAGER, SAFE_WALLET } from '../utils'
import { getChain, isDevelopmentNetwork } from '@nomicfoundation/hardhat-viem/internal/chains'
import { Address } from 'viem'
import { arbitrum, base } from 'viem/chains'

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre
  const chain = await getChain(network.provider)
  const deployer = (await getNamedAccounts())['deployer'] as Address

  if (await deployments.getOrNull('LiquidityVault')) {
    return
  }

  let owner: Address = '0x'
  let name: String = ''
  let symbol: String = ''
  if (chain.testnet || isDevelopmentNetwork(chain.id)) {
    owner = deployer
    name = 'Clober Liquidity Vault'
    symbol = 'CLV'
  } else if (chain.id === arbitrum.id || chain.id === base.id) {
    owner = SAFE_WALLET[chain.id] // Safe
    name = 'Clober Liquidity Vault'
    symbol = 'CLV'
  } else {
    throw new Error('Unknown chain')
  }

  await deployWithVerify(hre, 'LiquidityVault', [BOOK_MANAGER[chain.id], 100, name, symbol], {
    proxy: {
      proxyContract: 'UUPS',
      execute: {
        methodName: 'initialize',
        args: [owner],
      },
    },
  })
}

deployFunction.tags = ['LiquidityVault']
export default deployFunction
