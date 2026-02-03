// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forge script script/MemeFactoryV2.s.sol:MemeFactoryV2Script --rpc-url <network> --broadcast
// forge inspect src/MemeFactoryV2.sol:MemeFactoryV2 abi --json > ../abis/MemeFactoryV2.json
import "./BaseScript.sol";
import {MemeFactoryV2} from "../src/MemeFactoryV2.sol";
import {Script} from "forge-std/Script.sol";

contract MemeFactoryV2Script is BaseScript {
    MemeFactoryV2 public memeFactoryV2;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为项目所有者和Uniswap V2 Router
        address projectOwner = 0x0000000000000000000000000000000000000000;
        address uniswapRouter = 0x0000000000000000000000000000000000000000;
        memeFactoryV2 = new MemeFactoryV2(projectOwner, uniswapRouter);
        console.log("MemeFactoryV2 deployed at:", address(memeFactoryV2));
        saveContract("MemeFactoryV2", address(memeFactoryV2));
    }
}