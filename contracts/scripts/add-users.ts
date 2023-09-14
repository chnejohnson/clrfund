import { ethers } from 'hardhat'

const users = [
  '0xa6dB498962edb37960750D929DBb963774C6753b', // account 8
  '0x519E03Ab0579c49bBa69912990F0779c631D2Ef6', // account 9
]

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
