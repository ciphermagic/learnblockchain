// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forge script script/ContractWallet.s.sol:ContractWalletScript --rpc-url <network> --broadcast
// forge inspect src/ContractWallet.sol:ContractWallet abi --json > ../abis/ContractWallet.json
import "./BaseScript.sol";
import {ContractWallet} from "../src/ContractWallet.sol";
import {Script} from "forge-std/Script.sol";

contract ContractWalletScript is BaseScript {
    ContractWallet public contractWallet;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址数组作为多签持有人，以及确认数
        address[] memory owners = new address[](3);
        owners[0] = 0x0000000000000000000000000000000000000001;
        owners[1] = 0x0000000000000000000000000000000000000002;
        owners[2] = 0x0000000000000000000000000000000000000003;

        uint numConfirmationsRequired = 2; // 需要2个确认

        contractWallet = new ContractWallet(owners, numConfirmationsRequired);
        console.log("ContractWallet deployed at:", address(contractWallet));
        saveContract("ContractWallet", address(contractWallet));
    }
}