// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/SchoolOptimized.s.sol:SchoolOptimizedScript --rpc-url <network> --broadcast
// forge inspect src/SchoolOptimized.sol:SchoolOptimized abi --json > ../abis/SchoolOptimized.json
import "./BaseScript.sol";
import {SchoolOptimized} from "../src/SchoolOptimized.sol";
import {Script} from "forge-std/Script.sol";

contract SchoolOptimizedScript is BaseScript {
    SchoolOptimized public schoolOptimized;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        schoolOptimized = new SchoolOptimized();
        console.log("SchoolOptimized deployed at:", address(schoolOptimized));
        saveContract("SchoolOptimized", address(schoolOptimized));
    }
}