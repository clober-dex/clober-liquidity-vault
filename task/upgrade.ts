import { task } from 'hardhat/config'

task('upgrade')
  .addParam('target', 'The target contract name to upgrade')
  .setAction(async ({ target }, hre) => {
    const targetContract = await hre.deployments.get(target)
    const implementationContract = await hre.deployments.get(`${target}_Implementation`)
    const tx = await (await hre.viem.getContractAt('UUPSUpgradeable', targetContract.address as `0x${string}`)).write.upgradeToAndCall([
      implementationContract.address as `0x${string}`,
      '0x',
    ])
    console.log('Upgrade tx:', tx)
  })
