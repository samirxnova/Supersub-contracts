import { DeployFunction } from 'hardhat-deploy/types'
import { THardhatRuntimeEnvironmentExtended } from 'helpers/types/THardhatRuntimeEnvironmentExtended'

const func: DeployFunction = async (hre: THardhatRuntimeEnvironmentExtended) => {
  const { getNamedAccounts, deployments } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  return
  await deploy('TokenFaucet', {
    from: deployer,
    args: [],
    log: true,
    gasLimit: 10_000_000,
  })

  /*
    // Getting a previously deployed contract
    const Subscription_SuperApp = await ethers.getContract("Subscription_SuperApp", deployer);
    await Subscription_SuperApp.setPurpose("Hello");
    
    //const Subscription_SuperApp = await ethers.getContractAt('Subscription_SuperApp', "0xaAC799eC2d00C013f1F11c37E654e59B0429DF6A") //<-- if you want to instantiate a version of a contract at a specific address!
  */
}
export default func
func.tags = ['TokenFaucet']

/*
Tenderly verification
let verification = await tenderly.verify({
  name: contractName,
  address: contractAddress,
  network: targetNetwork,
});
*/
