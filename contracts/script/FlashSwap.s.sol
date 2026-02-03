// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// forge script script/FlashSwap.s.sol:FlashSwapScript --rpc-url <network> --broadcast
// forge inspect src/FlashSwap.sol:FlashSwap abi --json > ../abis/FlashSwap.json
import "./BaseScript.sol";
import {FlashSwap} from "../src/FlashSwap.sol";
import {Script} from "forge-std/Script.sol";

contract FlashSwapScript is BaseScript {
    FlashSwap public flashSwap;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        flashSwap = new FlashSwap();
        console.log("FlashSwap deployed at:", address(flashSwap));
        saveContract("FlashSwap", address(flashSwap));
    }
}