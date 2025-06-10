import { arbitrum, arbitrumSepolia, base, berachainTestnet, monadTestnet, sepolia, sonic } from 'viem/chains'
import { Address, zeroAddress } from 'viem'

export const MINTER_ROUTER: { [chainId: number]: Address } = {
  [sepolia.id]: '0x08feDaACe14EB141E51282441b05182519D853D1',
  [base.id]: '0x19ceead7105607cd444f5ad10dd51356436095a1',
  [arbitrumSepolia.id]: '0x08feDaACe14EB141E51282441b05182519D853D1',
  [sonic.id]: '0xaC041Df48dF9791B0654f1Dbbf2CC8450C5f2e9D',
  [monadTestnet.id]: '0x7792669BEb769c4035bdFcA4F3d794d55922B954',
}

export const BOOK_MANAGER: { [chainId: number]: Address } = {
  [sepolia.id]: '0xAA9575d63dFC224b9583fC303dB3188C08d5C85A',
  [arbitrumSepolia.id]: '0xAA9575d63dFC224b9583fC303dB3188C08d5C85A',
  [base.id]: '0x382CCccbD3b142D7DA063bF68cd0c89634767F76',
  [berachainTestnet.id]: '0x982c57388101D012846aDC4997E9b073F3bC16BD',
  [sonic.id]: '0xD4aD5Ed9E1436904624b6dB8B1BE31f36317C636',
  [monadTestnet.id]: '0xAA9575d63dFC224b9583fC303dB3188C08d5C85A',
}

export const CHAINLINK_SEQUENCER_ORACLE: { [chainId: number]: Address } = {
  [base.id]: '0xBCF85224fc0756B9Fa45aA7892530B47e10b6433',
  [arbitrum.id]: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D',
  [arbitrumSepolia.id]: '0x8B0f27aDf87E037B53eF1AADB96bE629Be37CeA8',
  [sonic.id]: zeroAddress, // L1, no oracle
  [monadTestnet.id]: zeroAddress,
}

export const ORACLE_TIMEOUT: { [chainId: number]: number } = {
  [base.id]: 24 * 3600,
  [arbitrum.id]: 24 * 3600,
  [arbitrumSepolia.id]: 24 * 3600,
  [sonic.id]: 24 * 3600,
  [monadTestnet.id]: 24 * 3600,
}

export const SAFE_WALLET: { [chainId: number]: Address } = {
  [base.id]: '0xfb976Bae0b3Ef71843F1c6c63da7Df2e44B3836d',
  [arbitrum.id]: '0x290D9de8d51fDf4683Aa761865743a28909b2553',
  [sonic.id]: '0xDE4e00082c6Bd350F197693a5d485121201B0e11',
}

export const SEQUENCER_GRACE_PERIOD: { [chainId: number]: number } = {
  [base.id]: 3600,
  [arbitrum.id]: 3600,
  [arbitrumSepolia.id]: 3600,
  [sonic.id]: 3600,
  [monadTestnet.id]: 3600,
}
