// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forge script script/TransactionMultiSigWallet.s.sol:TransactionMultiSigWalletScript --rpc-url <network> --broadcast
// forge inspect src/TransactionMultiSigWallet.sol:TransactionMultiSigWallet abi --json > ../abis/TransactionMultiSigWallet.json
import "./BaseScript.sol";
import {TransactionMultiSigWallet} from "../src/TransactionMultiSigWallet.sol";
import {Script} from "forge-std/Script.sol";

contract TransactionMultiSigWalletScript is BaseScript {
    TransactionMultiSigWallet public transactionMultiSigWallet;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址数组作为多签持有人，以及确认数
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000001;
        owners[1] = 0x0000000000000000000000000000000000000002;
        owners[2] = 0x0000000000000000000000000000000000000003;

        uint numConfirmationsRequired = 2; // 需要2个确认

        transactionMultiSigWallet = new TransactionMultiSigWallet(owners, numConfirmationsRequired);
        console.log("TransactionMultiSigWallet deployed at:", address(transactionMultiSigWallet));
        saveContract("TransactionMultiSigWallet", address(transactionMultiSigWallet));
    }
}
