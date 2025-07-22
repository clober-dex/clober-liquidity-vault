import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { deployWithVerify, getDeployedAddress } from '../utils'
import { getChain } from '@nomicfoundation/hardhat-viem/internal/chains'
import { Address, zeroAddress } from 'viem'
import { arbitrumSepolia, base, monadTestnet, sonic } from 'viem/chains'

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre
  const chain = await getChain(network.provider)
  const deployer = (await getNamedAccounts())['deployer'] as Address

  if (await deployments.getOrNull('Operator')) {
    return
  }

  let owner: Address = '0x'
  let feeAmount: BigInt = 0n
  let datastreamOracle
  if (chain.id === base.id) {
    owner = deployer // bot address
    datastreamOracle = await getDeployedAddress('DatastreamOracle')
    feeAmount = 10n ** 18n / 20n
  } else if (chain.id === sonic.id) {
    owner = '0x872251F2C0cC5699c9e0C226371c4D747fDA247f' // bot address
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else if (chain.id === monadTestnet.id || chain.id === arbitrumSepolia.id) {
    owner = deployer
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else {
    throw new Error('Unknown chain')
  }

  await deployWithVerify(hre, 'Operator', [await getDeployedAddress('LiquidityVault'), datastreamOracle], {
    proxy: {
      proxyContract: 'UUPS',
      execute: {
        methodName: 'initialize',
        args: [owner, feeAmount],
      },
    },
  })
}

deployFunction.tags = ['Operator']
deployFunction.dependencies = ['LiquidityVault', 'Oracle']
export default deployFunction
