// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/TokenBankReceiver.s.sol:TokenBankReceiverScript --rpc-url <network> --broadcast
// forge inspect src/TokenBankReceiver.sol:TokenBankReceiver abi --json > ../abis/TokenBankReceiver.json
import "./BaseScript.sol";
import {TokenBankReceiver} from "../src/TokenBankReceiver.sol";
import {Script} from "forge-std/Script.sol";

contract TokenBankReceiverScript is BaseScript {
    TokenBankReceiver public tokenBankReceiver;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为代币地址
        address tokenAddress = 0x0000000000000000000000000000000000000000;

        tokenBankReceiver = new TokenBankReceiver(tokenAddress);
        console.log("TokenBankReceiver deployed at:", address(tokenBankReceiver));
        saveContract("TokenBankReceiver", address(tokenBankReceiver));
    }
}