import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import {
  deployWithVerify,
  CHAINLINK_SEQUENCER_ORACLE,
  ORACLE_TIMEOUT,
  SEQUENCER_GRACE_PERIOD,
  SAFE_WALLET,
} from '../utils'
import { getChain } from '@nomicfoundation/hardhat-viem/internal/chains'
import { Address } from 'viem'
import { arbitrumSepolia, base, monadTestnet, sonic } from 'viem/chains'
import { monadPrivateMainnet, riseTestnet } from '../utils/chains'

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre
  const chain = await getChain(network.provider)
  const deployer = (await getNamedAccounts())['deployer'] as Address

  if (await deployments.getOrNull('ChainlinkOracle')) {
    return
  }

  let owner: Address = '0x'
  if (chain.id == base.id) {
    return
  } else if (chain.id == sonic.id || chain.id == monadPrivateMainnet.id) {
    owner = SAFE_WALLET[chain.id]
  } else if (chain.id == monadTestnet.id || chain.id == riseTestnet.id || chain.id == arbitrumSepolia.id) {
    owner = deployer
  } else {
    throw new Error('Unknown chain')
  }

  const args = [CHAINLINK_SEQUENCER_ORACLE[chain.id], ORACLE_TIMEOUT[chain.id], SEQUENCER_GRACE_PERIOD[chain.id], owner]
  await deployWithVerify(hre, 'ChainlinkOracle', args)
}

deployFunction.tags = ['Oracle']
export default deployFunction
