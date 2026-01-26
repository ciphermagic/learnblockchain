// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {TokenBankPermit} from "../src/TokenBankPermit.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/TokenBankPermit.s.sol --rpc-url local --broadcast
// forge inspect src/TokenBankPermit.sol:TokenBankPermit abi --json > ../abis/TokenBankPermit.json
contract TokenBankScript is BaseScript {
    TokenBankPermit public tokenBank;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        tokenBank = new TokenBankPermit(address(0x4826533B4897376654Bb4d4AD88B7faFD0C98528));
        saveContract("TokenBankPermit", address(tokenBank));
    }
}
