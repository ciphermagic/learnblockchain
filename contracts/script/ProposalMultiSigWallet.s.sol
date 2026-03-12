// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// forge script script/ProposalMultiSigWallet.s.sol:ProposalMultiSigWalletScript --rpc-url <network> --broadcast
// forge inspect src/ProposalMultiSigWallet.sol:ProposalMultiSigWallet abi --json > ../abis/ProposalMultiSigWallet.json
import "./BaseScript.sol";
import {ProposalMultiSigWallet} from "../src/ProposalMultiSigWallet.sol";
import {Script} from "forge-std/Script.sol";

contract ProposalMultiSigWalletScript is BaseScript {
    ProposalMultiSigWallet public proposalMultiSigWallet;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址数组作为多签持有者，至少需要3个地址
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000001;
        owners[1] = 0x0000000000000000000000000000000000000002;
        owners[2] = 0x0000000000000000000000000000000000000003;

        proposalMultiSigWallet = new ProposalMultiSigWallet(owners);
        console.log("ProposalMultiSigWallet deployed at:", address(proposalMultiSigWallet));
        saveContract("ProposalMultiSigWallet", address(proposalMultiSigWallet));
    }
}
