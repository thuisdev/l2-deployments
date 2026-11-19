import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { TwoWayConfig, generateConnectionsConfig } from '@layerzerolabs/metadata-tools'
import { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

// L2-15:
const optimismContract: OmniPointHardhat = {
    eid: EndpointId.OPTSEP_V2_TESTNET,
    contractName: 'MyOApp',
}

const arbitrumContract: OmniPointHardhat = {
    eid: EndpointId.ARBSEP_V2_TESTNET,
    contractName: 'MyOApp',
}

// L2-14;
const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 80000,
        value: 0,
    },
]

// L2.13:
const pathways: TwoWayConfig[] = [
    [
        optimismContract, // Chain A contract
        arbitrumContract, // Chain B contract
        [['LayerZero Labs'], []], // [ requiredDVN[], [ optionalDVN[], threshold ] ]
        [1, 1], // [A to B confirmations, B to A confirmations]
        [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS], // Chain B enforcedOptions, Chain A enforcedOptions
    ],
]

export default async function () {
    const connections = await generateConnectionsConfig(pathways)
    return {
        contracts: [{ contract: optimismContract }, { contract: arbitrumContract }],
        connections,
    }
}
