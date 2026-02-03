// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// forge script script/MiniSwapPool.s.sol:MiniSwapPoolScript --rpc-url <network> --broadcast
// forge inspect src/MiniSwapPool.sol:MiniSwapPool abi --json > ../abis/MiniSwapPool.json
import "./BaseScript.sol";
import {MiniSwapPool} from "../src/MiniSwapPool.sol";
import {Script} from "forge-std/Script.sol";

contract MiniSwapPoolScript is BaseScript {
    MiniSwapPool public miniSwapPool;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为两个代币和池子的名称/符号
        address token0 = 0x0000000000000000000000000000000000000000;
        address token1 = 0x0000000000000000000000000000000000000000;
        string memory name = "MiniSwap Pool Token";
        string memory symbol = "MSP";

        miniSwapPool = new MiniSwapPool(token0, token1, name, symbol);
        console.log("MiniSwapPool deployed at:", address(miniSwapPool));
        saveContract("MiniSwapPool", address(miniSwapPool));
    }
}