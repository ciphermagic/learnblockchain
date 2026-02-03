// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/AbiEncode_Decode.s.sol:AbiEncodeScript --rpc-url <network> --broadcast
// forge inspect src/AbiEncode_Decode.sol:AbiEncode abi --json > ../abis/AbiEncode.json
import "./BaseScript.sol";
import {AbiEncode} from "../src/AbiEncode_Decode.sol";
import {Script} from "forge-std/Script.sol";

contract AbiEncodeScript is BaseScript {
    AbiEncode public abiEncode;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        abiEncode = new AbiEncode();
        saveContract("AbiEncode", address(abiEncode));
    }
}