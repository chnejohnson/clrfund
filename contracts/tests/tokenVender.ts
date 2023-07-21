import { ethers, waffle, artifacts } from 'hardhat'
import { use, expect } from 'chai'
import { solidity } from 'ethereum-waffle'
import { deployMockContract } from '@ethereum-waffle/mock-contract'
import { Contract, BigNumber } from 'ethers'
import { defaultAbiCoder } from '@ethersproject/abi'
import { genRandomSalt } from 'maci-crypto'
import { Keypair } from '@clrfund/maci-utils'

import {
  ZERO_ADDRESS,
  UNIT,
  VOICE_CREDIT_FACTOR,
  ALPHA_PRECISION,
} from '../utils/constants'
import { getEventArg, getGasUsage } from '../utils/contracts'
import { deployContract, deployMaciFactory } from '../utils/deployment'
import {
  bnSqrt,
  createMessage,
  addTallyResultsBatch,
  getRecipientClaimData,
  getRecipientTallyResultsBatch,
} from '../utils/maci'
import { sha256 } from 'ethers/lib/utils'
import { MaciParameters } from '../utils/maci'

// ethStaker test vectors for Quadratic Funding with alpha
import smallTallyTestData from './data/testTallySmall.json'

// budget = tokenVender + matchingPoolSize
const totalSpent = BigNumber.from(smallTallyTestData.totalVoiceCredits.spent)
const budget = BigNumber.from(totalSpent).mul(VOICE_CREDIT_FACTOR).mul(2)
const totalQuadraticVotes = smallTallyTestData.results.tally.reduce(
  (total, tally) => {
    return BigNumber.from(tally).pow(2).add(total)
  },
  BigNumber.from(0)
)
const matchingPoolSize = budget.sub(totalSpent.mul(VOICE_CREDIT_FACTOR))

const expectedAlpha = matchingPoolSize
  .mul(ALPHA_PRECISION)
  .div(totalQuadraticVotes.sub(totalSpent))
  .div(VOICE_CREDIT_FACTOR)

function calcAllocationAmount(tally: string, voiceCredit: string): BigNumber {
  const quadratic = expectedAlpha
    .mul(VOICE_CREDIT_FACTOR)
    .mul(BigNumber.from(tally).pow(2))
  const linear = ALPHA_PRECISION.sub(expectedAlpha).mul(
    VOICE_CREDIT_FACTOR.mul(voiceCredit)
  )
  const allocation = quadratic.add(linear)
  return allocation.div(ALPHA_PRECISION)
}

use(solidity)

describe('Token Vender', () => {
  const provider = waffle.provider
  const [, deployer, coordinator, user, contributor, recipient] =
    provider.getWallets()

  const coordinatorPubKey = new Keypair().pubKey
  const signUpDuration = 86400 * 7 // Default duration in MACI factory
  const votingDuration = 86400 * 7 // Default duration in MACI factory
  const userKeypair = new Keypair()
  const contributionAmount = UNIT.mul(10)
  const tallyHash = 'test'
  const tallyTreeDepth = 2

  let assetToken: Contract
  let assetTokenAsUser: Contract
  let maciFactory: Contract
  let fundingRoundFactory: Contract
  let fundingRound: Contract
  let recipientRegistry: Contract
  let tokenVender: Contract
  let tokenVenderAsUser: Contract
  let maci: Contract

  async function deployMaciMock(): Promise<Contract> {
    const MACIArtifact = await artifacts.readArtifact('MACI')
    const maci = await deployMockContract(deployer, MACIArtifact.abi)
    const currentTime = (await provider.getBlock('latest')).timestamp
    const signUpDeadline = currentTime + signUpDuration
    const votingDeadline = signUpDeadline + votingDuration
    await maci.mock.signUpTimestamp.returns(currentTime)
    await maci.mock.signUpDurationSeconds.returns(signUpDuration)
    await maci.mock.votingDurationSeconds.returns(votingDuration)
    await maci.mock.calcSignUpDeadline.returns(signUpDeadline)
    await maci.mock.calcVotingDeadline.returns(votingDeadline)
    await maci.mock.maxUsers.returns(100)
    await maci.mock.treeDepths.returns(10, 10, 2)
    await maci.mock.signUp.returns()
    return maci
  }

  beforeEach(async () => {
    const tokenInitialSupply = UNIT.mul(1000000)
    const Token = await ethers.getContractFactory('AnyOldERC20Token', deployer)
    assetToken = await Token.deploy(tokenInitialSupply)
    assetTokenAsUser = await assetToken.connect(user)

    await assetToken.transfer(user.address, ethers.utils.parseEther('200'))
    await assetToken.transfer(contributor.address, tokenInitialSupply.div(4))

    // deploy mock recipientRegistry
    const IRecipientRegistryArtifact = await artifacts.readArtifact(
      'IRecipientRegistry'
    )
    recipientRegistry = await deployMockContract(
      deployer,
      IRecipientRegistryArtifact.abi
    )

    expect(await assetToken.balanceOf(user.address)).to.equal(
      ethers.utils.parseEther('200')
    )

    const circuit = 'prod'
    maciFactory = await deployMaciFactory(deployer, circuit)

    fundingRoundFactory = await deployContract(
      deployer,
      'FundingRoundFactory',
      [maciFactory.address]
    )

    expect(fundingRoundFactory.address).to.properAddress
    expect(await getGasUsage(fundingRoundFactory.deployTransaction)).lessThan(
      5400000
    )

    await maciFactory.transferOwnership(fundingRoundFactory.address)

    // deploy TokenVender
    tokenVender = await deployContract(deployer, 'TokenVender', [
      fundingRoundFactory.address,
      assetToken.address,
      'Asset Token',
      'AT',
      ethers.utils.parseEther('20'), // ubi amount
    ])

    tokenVenderAsUser = await tokenVender.connect(user)

    // deploy FundingRound
    const FundingRound = await ethers.getContractFactory('FundingRound', {
      signer: deployer,
    })
    fundingRound = await FundingRound.deploy(
      tokenVender.address,
      tokenVender.address,
      recipientRegistry.address,
      coordinator.address
    )
  })

  describe('managing verified users', () => {
    it('allows owner to add user to the registry', async () => {
      expect(await tokenVender.isVerifiedUser(user.address)).to.equal(false)
      await expect(tokenVender.addUser(user.address))
        .to.emit(tokenVender, 'UserAdded')
        .withArgs(user.address)
      expect(await tokenVender.isVerifiedUser(user.address)).to.equal(true)
    })

    it('allows verified users have Unconditional Basic Income amount of voting tokens', async () => {
      const ubiAmount = await tokenVenderAsUser.ubiAmount()
      await expect(tokenVender.addUser(user.address))
        .to.emit(tokenVender, 'UserAdded')
        .withArgs(user.address)
      expect(await tokenVender.balanceOf(user.address)).to.equal(ubiAmount)
    })

    it('rejects zero-address', async () => {
      await expect(tokenVender.addUser(ZERO_ADDRESS)).to.be.revertedWith(
        'TokenVender: User address is zero'
      )
    })

    it('rejects user who is already in the registry', async () => {
      await tokenVender.addUser(user.address)
      await expect(tokenVender.addUser(user.address)).to.be.revertedWith(
        'TokenVender: User already verified'
      )
    })

    it('allows only owner to add users', async () => {
      const registryAsUser = tokenVender.connect(user)
      await expect(registryAsUser.addUser(user.address)).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })

    it('allows owner to remove user', async () => {
      await tokenVender.addUser(user.address)
      await expect(tokenVender.removeUser(user.address))
        .to.emit(tokenVender, 'UserRemoved')
        .withArgs(user.address)
      expect(await tokenVender.isVerifiedUser(user.address)).to.equal(false)
    })

    it('reverts when trying to remove user who is not in the registry', async () => {
      await expect(tokenVender.removeUser(user.address)).to.be.revertedWith(
        'UserRegistry: User is not in the registry'
      )
    })

    it('allows only owner to remove users', async () => {
      await tokenVender.addUser(user.address)
      const registryAsUser = tokenVender.connect(user)
      await expect(registryAsUser.removeUser(user.address)).to.be.revertedWith(
        'Ownable: caller is not the owner'
      )
    })
  })

  describe('buyTokens()', () => {
    it('should get tokensPerAssetToken', async () => {
      expect(await tokenVenderAsUser.tokensPerAssetToken()).to.equal(1)
    })

    it('should let user buy tokens by asset assetToken', async () => {
      const amountOfAssetTokens = ethers.utils.parseEther('100')
      const tokensPerAssetToken = await tokenVenderAsUser.tokensPerAssetToken()
      const amountOfVotingTokens = amountOfAssetTokens.mul(tokensPerAssetToken)

      await assetTokenAsUser.approve(
        tokenVenderAsUser.address,
        amountOfAssetTokens
      )

      // buy 100 voting tokens by 100 asset tokens
      await expect(tokenVenderAsUser.buyTokens(amountOfAssetTokens))
        .to.emit(tokenVenderAsUser, 'BuyTokens')
        .withArgs(user.address, amountOfAssetTokens, amountOfVotingTokens)

      expect(await assetTokenAsUser.balanceOf(user.address)).to.equal(
        ethers.utils.parseEther('100')
      )
      expect(await tokenVenderAsUser.balanceOf(user.address)).to.equal(
        ethers.utils.parseEther('100')
      )
      expect(await tokenVenderAsUser.totalSupply()).to.equal(
        ethers.utils.parseEther('100')
      )
    })
  })

  describe('redeemTokens()', () => {
    const totalVotes = totalQuadraticVotes
    const recipientIndex = 3
    const { spent: totalSpent, salt: totalSpentSalt } =
      smallTallyTestData.totalVoiceCredits
    const contributions =
      smallTallyTestData.totalVoiceCreditsPerVoteOption.tally[recipientIndex] // 559607965

    const expectedAllocatedAmount = calcAllocationAmount(
      smallTallyTestData.results.tally[recipientIndex],
      smallTallyTestData.totalVoiceCreditsPerVoteOption.tally[recipientIndex]
    ).toString()

    let fundingRoundAsRecipient: Contract
    let fundingRoundAsContributor: Contract
    let tokenVenderAsRecipient: Contract

    beforeEach(async () => {
      maci = await deployMaciMock()
      await maci.mock.hasUntalliedStateLeaves.returns(false)
      await maci.mock.totalVotes.returns(totalVotes)
      await maci.mock.verifySpentVoiceCredits.returns(true)
      await maci.mock.verifyTallyResult.returns(true)
      await maci.mock.verifyPerVOSpentVoiceCredits.returns(true)
      await maci.mock.treeDepths.returns(10, 10, tallyTreeDepth)

      // mock getRecipientAddress
      await recipientRegistry.mock.getRecipientAddress.returns(
        recipient.address
      )

      const assetTokenAsContributor = assetToken.connect(contributor)
      const contributorBudget = await assetTokenAsContributor.balanceOf(
        contributor.address
      )
      const tokenVenderAsContributor = tokenVender.connect(contributor)

      await assetTokenAsContributor.approve(
        tokenVenderAsContributor.address,
        contributorBudget
      )
      await tokenVenderAsContributor.buyTokens(contributorBudget)

      await fundingRound.setMaci(maci.address)

      await tokenVenderAsContributor.approve(
        fundingRound.address,
        contributions
      )
      fundingRoundAsContributor = fundingRound.connect(contributor)

      await provider.send('evm_increaseTime', [signUpDuration + votingDuration])
      await fundingRound.connect(coordinator).publishTallyHash(tallyHash)
      fundingRoundAsRecipient = fundingRound.connect(recipient)
      tokenVenderAsRecipient = tokenVender.connect(recipient)
    })

    it('allows recipient to redeem asset tokens by allocated voting tokens', async () => {
      // 讓 deployer 買 tokens 投入資金池
      await assetToken.approve(tokenVender.address, budget)
      await tokenVender.buyTokens(budget)
      await tokenVender.transfer(fundingRound.address, budget)

      await addTallyResultsBatch(
        fundingRound.connect(coordinator),
        tallyTreeDepth,
        smallTallyTestData,
        3
      )
      await fundingRound.finalize(totalSpent, totalSpentSalt)

      const { results, totalVoiceCreditsPerVoteOption } = smallTallyTestData
      expect(
        await fundingRound.getAllocatedAmount(
          results.tally[recipientIndex],
          totalVoiceCreditsPerVoteOption.tally[recipientIndex]
        )
      ).to.equal(expectedAllocatedAmount, 'mismatch allocated amount')

      const claimData = getRecipientClaimData(
        recipientIndex,
        tallyTreeDepth,
        smallTallyTestData
      )
      await expect(fundingRoundAsRecipient.claimFunds(...claimData))
        .to.emit(fundingRound, 'FundsClaimed')
        .withArgs(recipientIndex, recipient.address, expectedAllocatedAmount)
      expect(await tokenVender.balanceOf(recipient.address)).to.equal(
        expectedAllocatedAmount,
        'mismatch token balance'
      )

      const votingTokenBalanceBefore = await tokenVender.balanceOf(
        recipient.address
      )

      // redeem tokens
      await expect(
        tokenVenderAsRecipient.redeemTokens(
          fundingRound.address,
          claimData[0],
          claimData[1]
        )
      )
        .to.emit(tokenVender, 'TokensRedeemed')
        .withArgs(recipientIndex, recipient.address, expectedAllocatedAmount)

      // asset token 增加
      expect(await assetToken.balanceOf(recipient.address)).to.equal(
        expectedAllocatedAmount,
        'mismatch asset token balance'
      )

      // voting token 減少
      expect(await tokenVender.balanceOf(recipient.address)).to.equal(
        votingTokenBalanceBefore.sub(expectedAllocatedAmount),
        'mismatch voting token balance'
      )
    })
    // it('should not allow address different than recipient to redeem allocated funds', async () => {})
    // it('should not allow recipient to redeem funds if funds has not been claimed', async () => {})
    // it('should not allow recipient to redeem funds if funds has been redeemed', async () => {})
  })
})
