import { ethers } from 'hardhat'

const recipients = [
  {
    address: '0xD9b6FA6B8A585EeE012DC6BdB476e5147dD715E5',
    metadata: {
      name: 'Macbook Air MetaMask dev-recipient',
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
