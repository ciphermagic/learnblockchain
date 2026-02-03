// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/Bank.s.sol:BankScript --rpc-url <network> --broadcast
// forge inspect src/Bank.sol:Bank abi --json > ../abis/Bank.json
import "./BaseScript.sol";
import {Bank} from "../src/Bank.sol";
import {Script} from "forge-std/Script.sol";

contract BankScript is BaseScript {
    Bank public bank;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        bank = new Bank();
        saveContract("Bank", address(bank));
    }
}