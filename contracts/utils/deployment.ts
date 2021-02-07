import { ethers } from 'hardhat'
import { Libraries } from 'hardhat/types/runtime'
import { Signer, Contract } from 'ethers'
import { link } from 'ethereum-waffle'

import { MaciParameters } from './maci'

export function linkBytecode(
  bytecode: string,
  libraries: {[name: string]: string},
): string {
  // Workarounds for https://github.com/nomiclabs/buidler/issues/611
  const linkable = { evm: { bytecode: { object: bytecode } } }
  for (const [libraryName, libraryAddress] of Object.entries(libraries)) {
    link(linkable, libraryName, libraryAddress.toLowerCase())
  }
  return linkable.evm.bytecode.object
}

const CIRCUITS: {[name: string]: any} = {
  test: {
    batchUstVerifier: 'BatchUpdateStateTreeVerifier',
    qvtVerifier: 'QuadVoteTallyVerifier',
    treeDepths: { stateTreeDepth: 4, messageTreeDepth: 4, voteOptionTreeDepth: 2 },
  },
  small: {
    batchUstVerifier: 'BatchUpdateStateTreeVerifierSmall',
    qvtVerifier: 'QuadVoteTallyVerifierSmall',
    treeDepths: { stateTreeDepth: 8, messageTreeDepth: 11, voteOptionTreeDepth: 3 },
  },
}

export async function deployContract(
  account: Signer,
  contractName: string,
  contractArgs: any[] = [],
): Promise<Contract> {
  const contractFactory = await ethers.getContractFactory(contractName, account)
  const contract = await contractFactory.deploy(...contractArgs)
  return await contract.deployed()
}

interface MaciFactoryDependencies {
  poseidonT3?: Contract;
  poseidonT6?: Contract;
  batchUstVerifier?: Contract,
  qvtVerifier?: Contract,
}

export async function deployMaciFactory(
  account: Signer,
  circuit = 'test',
  { poseidonT3, poseidonT6, batchUstVerifier, qvtVerifier }: MaciFactoryDependencies = {},
): Promise<Contract> {
  if (!poseidonT3) {
    const PoseidonT3 = await ethers.getContractFactory(':PoseidonT3', account)
    poseidonT3 = await PoseidonT3.deploy()
  }
  if (!poseidonT6) {
    const PoseidonT6 = await ethers.getContractFactory(':PoseidonT6', account)
    poseidonT6 = await PoseidonT6.deploy()
  }
  if (!batchUstVerifier) {
    const BatchUstVerifier = await ethers.getContractFactory(CIRCUITS[circuit].batchUstVerifier, account)
    batchUstVerifier = await BatchUstVerifier.deploy()
  }
  if (!qvtVerifier) {
    const QvtVerifier = await ethers.getContractFactory(CIRCUITS[circuit].qvtVerifier, account)
    qvtVerifier = await QvtVerifier.deploy()
  }

  const maciLibraries: Libraries = {
    'maci-contracts/sol/Poseidon.sol:PoseidonT3': poseidonT3.address,
    'maci-contracts/sol/Poseidon.sol:PoseidonT6': poseidonT6.address,
  }

  const MACIFactory = await ethers.getContractFactory(
    'MACIFactory',
    {
      signer: account,
      libraries: maciLibraries,
    },
  )
  const maciParameters = new MaciParameters({
    batchUstVerifier: batchUstVerifier.address,
    qvtVerifier: qvtVerifier.address,
    ...CIRCUITS[circuit].treeDepths,
  })

  const maciFactory = await MACIFactory.deploy(...maciParameters.values())
  await maciFactory.deployed()
  return maciFactory
}
