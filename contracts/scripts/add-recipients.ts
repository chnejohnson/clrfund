import { ethers } from 'hardhat'

const recipients = [
  {
    address: '0xD9b6FA6B8A585EeE012DC6BdB476e5147dD715E5',
    metadata: {
      name: 'My CLR Fun',
    },
  },
  {
    address: '0xfd300B2fF7Ac475fbb1eBc81456B388bcbB7785C',
    metadata: {
      name: 'Vue Dapp',
    },
  },
  {
    address: '0x71bE63f3384f5fb98995898A86B02Fb2426c5788',
    metadata: {
      name: '11',
    },
  },
  {
    address: '0xFABB0ac9d68B0B445fB7357272Ff202C5651694a',
    metadata: {
      name: '12',
    },
  },
  {
    address: '0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec',
    metadata: {
      name: '13',
    },
  },
  {
    address: '0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097',
    metadata: {
      name: '14',
    },
  },
  {
    address: '0xcd3B766CCDd6AE721141F452C550Ca635964ce71',
    metadata: {
      name: '15',
    },
  },
]

async function main() {
  const factoryAddress = process.env.FACTORY_ADDRESS as string
  if (!factoryAddress)
    throw new Error('Please provide factory address in .env file')

  const [deployer] = await ethers.getSigners()
  console.log(`Using the address: ${deployer.address}`)

  const factory = await ethers.getContractAt(
    'FundingRoundFactory',
    factoryAddress
  )

  const recipientRegistryAddress = await factory.recipientRegistry()

  const recipientRegistry = await ethers.getContractAt(
    'SimpleRecipientRegistry',
    recipientRegistryAddress
  )

  let addRecipientTx
  for (const recipient of recipients) {
    addRecipientTx = await recipientRegistry.addRecipient(
      recipient.address,
      JSON.stringify(recipient.metadata)
    )
    addRecipientTx.wait()
    console.log(`Recipient ${recipient.address} `)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
