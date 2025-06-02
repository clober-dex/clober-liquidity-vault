import { task } from 'hardhat/config'
import { getDeployedAddress } from '../utils'

task('strategy:config').setAction(async (_, hre) => {
  const strategy = await hre.viem.getContractAt(
    'SimpleOracleStrategy',
    await getDeployedAddress('SimpleOracleStrategy'),
  )

  const configs: `0x${string}`[] = [
    // todo: add pool keys
  ]

  for (const config of configs) {
    const remoteConfig = await strategy.read.getConfig([config])
    if (remoteConfig.rebalanceThreshold == 0) {
      const res = await strategy.write.setConfig([
        config,
        {
          referenceThreshold: 10000,
          rebalanceThreshold: 50000,
          rateA: 1000000,
          rateB: 1000000,
          minRateA: 3000,
          minRateB: 3000,
          priceThresholdA: 10000,
          priceThresholdB: 10000,
        },
      ])
      console.log(`Set config for pool ${config}: ${res}`)
    } else {
      console.log(`Pool ${config} registered: ${remoteConfig.rebalanceThreshold > 0}`)
    }
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
})

task('operator:set').setAction(async (_, hre) => {
  const operator = await hre.viem.getContractAt('Operator', await getDeployedAddress('Operator'))
  console.log(await operator.read.owner())

  const operators: `0x${string}`[] = [
    // todo: add operators
  ]

  for (const operatorAddress of operators) {
    if (!(await operator.read.isOperator([operatorAddress]))) {
      const res = await operator.write.setOperator([operatorAddress, true])
      console.log(`Registered operator ${operatorAddress} with tx:`, res)
    } else {
      console.log(`${operatorAddress} is already an operator`)
    }
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }

  for (const operatorAddress of operators) {
    const isOp = await operator.read.isOperator([operatorAddress])
    console.log(`${operatorAddress}: ${isOp}`)
  }
})
