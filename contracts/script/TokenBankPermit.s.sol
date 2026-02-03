// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/TokenBankPermit.s.sol:TokenBankPermitScript --rpc-url <network> --broadcast
// forge inspect src/TokenBankPermit.sol:TokenBankPermit abi --json > ../abis/TokenBankPermit.json
import "./BaseScript.sol";
import {TokenBankPermit} from "../src/TokenBankPermit.sol";
import {Script} from "forge-std/Script.sol";

contract TokenBankPermitScript is BaseScript {
    TokenBankPermit public tokenBankPermit;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        tokenBankPermit = new TokenBankPermit(0x0000000000000000000000000000000000000000); // Placeholder token address
        saveContract("TokenBankPermit", address(tokenBankPermit));
    }
}