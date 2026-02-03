// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/BigBank.s.sol:BigBankScript --rpc-url <network> --broadcast
// forge inspect src/BigBank.sol:BigBank abi --json > ../abis/BigBank.json
import "./BaseScript.sol";
import {BigBank} from "../src/BigBank.sol";
import {Script} from "forge-std/Script.sol";

contract BigBankScript is BaseScript {
    BigBank public bigBank;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        bigBank = new BigBank();
        saveContract("BigBank", address(bigBank));
    }
}