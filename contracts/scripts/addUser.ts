import { ethers } from 'hardhat'

const user = '0x9e8f8C3Ad87dBE7ACFFC5f5800e7433c8dF409F2'
const fundingRoundAddress = '0x9C5638f94710BFcf77306E0aA2eC61657083957A'

async function main() {
  const fundingRound = await ethers.getContractAt(
    'FundingRound',
    fundingRoundAddress
  )

  const userRegistry = await ethers.getContractAt(
    'SimpleUserRegistry',
    await fundingRound.userRegistry()
  )
  let isVerified = await userRegistry.isVerifiedUser(user)

  if (!isVerified) {
    const addUserTx = await userRegistry.addUser(user)
    await addUserTx.wait()
  } else {
    console.log(`User ${user} has been verified`)
    return
  }

  isVerified = await userRegistry.isVerifiedUser(user)

  if (isVerified) {
    console.log(`Succeed to add user ${user}`)
  } else {
    console.log('Failed to add user')
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
