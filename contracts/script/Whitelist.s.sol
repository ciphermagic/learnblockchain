// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// forge script script/Whitelist.s.sol:WhitelistScript --rpc-url <network> --broadcast
// forge inspect src/Whitelist.sol:Whitelist abi --json > ../abis/Whitelist.json
import "./BaseScript.sol";
import {Whitelist} from "../src/Whitelist.sol";
import {Script} from "forge-std/Script.sol";

contract WhitelistScript is BaseScript {
    Whitelist public whitelist;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        whitelist = new Whitelist();
        console.log("Whitelist deployed at:", address(whitelist));
        saveContract("Whitelist", address(whitelist));
    }
}