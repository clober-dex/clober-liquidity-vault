import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { deployWithVerify, getDeployedAddress, SAFE_WALLET } from '../utils'
import { getChain } from '@nomicfoundation/hardhat-viem/internal/chains'
import { Address, zeroAddress } from 'viem'
import { arbitrumSepolia, base, monadTestnet, sonic } from 'viem/chains'
import { monadPrivateMainnet, riseTestnet } from '../utils/chains'

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
    owner = '0xEb386e036ffE592d982d1B0A835E25b11361C9cA' // bot address
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else if (chain.id === monadTestnet.id || chain.id === arbitrumSepolia.id) {
    owner = deployer
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else if (chain.id === riseTestnet.id) {
    owner = deployer
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else if (chain.id === monadPrivateMainnet.id) {
    owner = SAFE_WALLET[chain.id]
    datastreamOracle = zeroAddress
    feeAmount = 0n
  } else {
    throw new Error('Unknown chain')
  }

  const operatorAddress = await deployWithVerify(
    hre,
    'Operator',
    [await getDeployedAddress('LiquidityVault'), datastreamOracle],
    {
      proxy: {
        proxyContract: 'UUPS',
        execute: {
          methodName: 'initialize',
          args: [owner, feeAmount],
        },
      },
    },
  )

  const strategy = await hre.viem.getContractAt(
    'SimpleOracleStrategy',
    await getDeployedAddress('SimpleOracleStrategy'),
  )
  if ((await strategy.read.isOperator([operatorAddress as Address])) == false) {
    if (deployer == owner) {
      const tx = await strategy.write.setOperator([operatorAddress as Address, true])
      console.log('Set operator', tx)
    } else {
      console.log('You need to set operator manually')
    }
  }
}

deployFunction.tags = ['Operator']
deployFunction.dependencies = ['LiquidityVault', 'Oracle', 'SimpleOracleStrategy']
export default deployFunction
