// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/ArrayStorage.s.sol:ArrayStorageScript --rpc-url <network> --broadcast
// forge inspect src/ArrayStorage.sol:ArrayStorage abi --json > ../abis/ArrayStorage.json
import "./BaseScript.sol";
import {ArrayStorage} from "../src/ArrayStorage.sol";
import {Script} from "forge-std/Script.sol";

contract ArrayStorageScript is BaseScript {
    ArrayStorage public arrayStorage;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        arrayStorage = new ArrayStorage();
        saveContract("ArrayStorage", address(arrayStorage));
    }
}