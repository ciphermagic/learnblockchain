// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/TokenBankPermit2.s.sol:TokenBankPermit2Script --rpc-url <network> --broadcast
// forge inspect src/TokenBankPermit2.sol:TokenBank abi --json > ../abis/TokenBankPermit2.json
import "./BaseScript.sol";
import {TokenBank} from "../src/TokenBankPermit2.sol";
import {Script} from "forge-std/Script.sol";

contract TokenBankPermit2Script is BaseScript {
    TokenBank public tokenBank;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        tokenBank = new TokenBank(0x0000000000000000000000000000000000000000); // Placeholder token address
        saveContract("TokenBankPermit2", address(tokenBank));
    }
}