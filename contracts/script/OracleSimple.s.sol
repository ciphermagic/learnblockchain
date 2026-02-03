// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/OracleSimple.s.sol:OracleSimpleScript --rpc-url <network> --broadcast
// forge inspect src/OracleSimple.sol:OracleSimple abi --json > ../abis/OracleSimple.json
import "./BaseScript.sol";
import {OracleSimple} from "../src/OracleSimple.sol";
import {Script} from "forge-std/Script.sol";

contract OracleSimpleScript is BaseScript {
    OracleSimple public oracleSimple;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        oracleSimple = new OracleSimple(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, // Uniswap V2 Factory address
            0x0000000000000000000000000000000000000000, // Meme token address (placeholder)
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2  // WETH address
        );
        saveContract("OracleSimple", address(oracleSimple));
    }
}