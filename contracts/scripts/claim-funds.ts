import fs from 'fs'
import { ethers } from 'hardhat'

import { getEventArg } from '../utils/contracts'
import { getRecipientClaimData } from '../utils/maci'

const recipientIndexes = [0, 1, 2, 3, 4, 5]

async function main() {
  const [deployer] = await ethers.getSigners()
  const roundAddress = process.env.ROUND_ADDRESS as string
  const tally = JSON.parse(fs.readFileSync('tally.json').toString())

  const fundingRound = await ethers.getContractAt('FundingRound', roundAddress)
  const maciAddress = await fundingRound.maci()
  const maci = await ethers.getContractAt('MACI', maciAddress)
  const recipientTreeDepth = (await maci.treeDepths()).voteOptionTreeDepth

  // Claim funds
  for (const recipientIndex of recipientIndexes) {
    const recipientClaimData = getRecipientClaimData(
      recipientIndex,
      recipientTreeDepth,
      tally
    )
    const fundingRoundAsRecipient = fundingRound.connect(deployer)
    const claimTx = await fundingRoundAsRecipient.claimFunds(
      ...recipientClaimData
    )
    const claimedAmount = await getEventArg(
      claimTx,
      fundingRound,
      'FundsClaimed',
      '_amount'
    )
    console.log(`Recipient ${recipientIndex} claimed ${claimedAmount} tokens.`)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
