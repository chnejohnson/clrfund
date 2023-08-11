import { ethers } from 'hardhat'

const users = ['0x8647EBFE6586372337342946245ff916EccB0432']

async function main() {
  const factoryAddress = process.env.FACTORY_ADDRESS as string
  if (!factoryAddress)
    throw new Error('Please provide factory address in .env file')

  const [deployer] = await ethers.getSigners()
  console.log(`Using the address: ${deployer.address}`)

  // Configure factory
  const factory = await ethers.getContractAt(
    'FundingRoundFactory',
    factoryAddress
  )

  // Add contributors
  const userRegistryType = process.env.USER_REGISTRY_TYPE || 'simple'
  if (userRegistryType === 'simple') {
    const userRegistryAddress = await factory.userRegistry()
    const userRegistry = await ethers.getContractAt(
      'SimpleUserRegistry',
      userRegistryAddress
    )

    let addUserTx
    for (const account of users) {
      addUserTx = await userRegistry.addUser(account)
      addUserTx.wait()
      console.log(`User ${account} added`)
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
