// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// forge script script/MultiSigWallet.s.sol:MultiSigWalletScript --rpc-url <network> --broadcast
// forge inspect src/MultiSigWallet.sol:MultiSigWallet abi --json > ../abis/MultiSigWallet.json
import "./BaseScript.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {Script} from "forge-std/Script.sol";

contract MultiSigWalletScript is BaseScript {
    MultiSigWallet public multiSigWallet;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址数组作为多签持有者，至少需要3个地址
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000001;
        owners[1] = 0x0000000000000000000000000000000000000002;
        owners[2] = 0x0000000000000000000000000000000000000003;

        multiSigWallet = new MultiSigWallet(owners);
        console.log("MultiSigWallet deployed at:", address(multiSigWallet));
        saveContract("MultiSigWallet", address(multiSigWallet));
    }
}