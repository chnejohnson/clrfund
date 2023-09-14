import { ethers } from 'hardhat'
import { MaciParameters } from '../utils/maci'

// in seconds
const duration = {
  signUpDuration: 70000,
  votingDuration: 60,
}

async function main() {
  const factoryAddress = process.env.FACTORY_ADDRESS as string

  // Configure factory
  const factory = await ethers.getContractAt(
    'FundingRoundFactory',
    factoryAddress
  )

  // Configure MACI factory
  const maciFactoryAddress = await factory.maciFactory()
  const maciFactory = await ethers.getContractAt(
    'MACIFactory',
    maciFactoryAddress
  )
  const maciParameters = await MaciParameters.read(maciFactory)
  maciParameters.update(duration)

  const setMaciParametersTx = await factory.setMaciParameters(
    ...maciParameters.values()
  )
  await setMaciParametersTx.wait()
  console.log('setMaciParameters done')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
