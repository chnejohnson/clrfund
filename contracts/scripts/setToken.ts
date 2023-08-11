import { ethers } from 'hardhat'

const tokenAddress = process.env.NATIVE_TOKEN_ADDRESS

async function main() {
  const factoryAddress = process.env.FACTORY_ADDRESS as string

  const factory = await ethers.getContractAt(
    'FundingRoundFactory',
    factoryAddress
  )

  const setTokenTx = await factory.setToken(tokenAddress)
  await setTokenTx.wait()

  console.log(`Token ${tokenAddress} set`)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
