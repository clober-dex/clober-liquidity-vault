import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployWithVerify, BOOK_MANAGER } from "../utils";
import {
  getChain,
  isDevelopmentNetwork,
} from "@nomicfoundation/hardhat-viem/internal/chains";
import { Address } from "viem";
import { arbitrum } from "viem/chains";

const deployFunction: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployments, getNamedAccounts, network } = hre;
  const chain = await getChain(network.provider);
  const deployer = (await getNamedAccounts())["deployer"] as Address;

  if (await deployments.getOrNull("Rebalancer")) {
    return;
  }

  let owner: Address = "0x";
  if (chain.testnet || isDevelopmentNetwork(chain.id)) {
    owner = deployer;
  } else if (chain.id === arbitrum.id) {
    owner = "0xfb976Bae0b3Ef71843F1c6c63da7Df2e44B3836d"; // Safe
  } else {
    throw new Error("Unknown chain");
  }

  await deployWithVerify(hre, "Rebalancer", [BOOK_MANAGER[chain.id], owner]);
};

deployFunction.tags = ["Rebalancer"];
export default deployFunction;
