// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {TokenBank} from "../src/TokenBank.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/TokenBank.s.sol --rpc-url local --broadcast
contract TokenBankScript is BaseScript {
    TokenBank public tokenBank;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        tokenBank = new TokenBank(address(0x4826533B4897376654Bb4d4AD88B7faFD0C98528));
        saveContract("TokenBank", address(tokenBank));
    }
}
