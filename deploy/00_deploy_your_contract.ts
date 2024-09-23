import { utils } from 'ethers'
import { DeployFunction } from 'hardhat-deploy/types'
import { THardhatRuntimeEnvironmentExtended } from 'helpers/types/THardhatRuntimeEnvironmentExtended'

const func: DeployFunction = async (hre: THardhatRuntimeEnvironmentExtended) => {
  const { getNamedAccounts, deployments } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  // Mumbai
  const SUPERFLUID_HOST = '0xEB796bdb90fFA0f28255275e16936D25d3418603'
  const DAIX = '0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f'

  // OXDOG STATION
  console.log('OXDOG STATION')
  await deploy('Subscription_SuperApp', {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [SUPERFLUID_HOST, DAIX, 'OXDOG STATION', 'OXD', [0, utils.parseEther('60'), utils.parseEther('120'), utils.parseEther('240')]],
    log: true,
    gasLimit: 10_000_000,
  })

  // BREAD STATION
  console.log('BREAD STATION')
  await deploy('Subscription_SuperApp', {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [SUPERFLUID_HOST, DAIX, 'BREAD STATION', 'BRD', [0, utils.parseEther('1'), utils.parseEther('2')]],
    log: true,
    gasLimit: 10_000_000,
  })

  // MEV STATION
  console.log('MEV STATION')
  await deploy('Subscription_SuperApp', {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [
      SUPERFLUID_HOST,
      DAIX,
      'MEV STATION',
      'MEV',
      [0, utils.parseEther('240'), utils.parseEther('380'), utils.parseEther('760'), utils.parseEther('1800')],
    ],
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
func.tags = ['Subscription_SuperApp']

/*
Tenderly verification
let verification = await tenderly.verify({
  name: contractName,
  address: contractAddress,
  network: targetNetwork,
});
*/
