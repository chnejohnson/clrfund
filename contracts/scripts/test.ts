import { ethers } from 'hardhat'

const user = '0xd78B5013757Ea4A7841811eF770711e6248dC282'
const fundingRoundAddress = '0x9C5638f94710BFcf77306E0aA2eC61657083957A'

async function main() {
  const fundingRound = await ethers.getContractAt(
    'FundingRound',
    fundingRoundAddress
  )

  const tokenAddress = await fundingRound.nativeToken()
  console.log('native token address', tokenAddress)

  const userRegistry = await ethers.getContractAt(
    'SimpleUserRegistry',
    await fundingRound.userRegistry()
  )
  console.log(await userRegistry.isVerifiedUser(user))

  const addUserTx = await userRegistry.addUser(user)
  await addUserTx.wait()

  console.log(await userRegistry.isVerifiedUser(user))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
