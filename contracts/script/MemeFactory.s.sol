// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forge script script/MemeFactory.s.sol:MemeFactoryScript --rpc-url <network> --broadcast
// forge inspect src/MemeFactory.sol:MemeFactory abi --json > ../abis/MemeFactory.json
import "./BaseScript.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {Script} from "forge-std/Script.sol";

contract MemeFactoryScript is BaseScript {
    MemeFactory public memeFactory;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为项目所有者
        address projectOwner = 0x0000000000000000000000000000000000000000;
        memeFactory = new MemeFactory(projectOwner);
        console.log("MemeFactory deployed at:", address(memeFactory));
        saveContract("MemeFactory", address(memeFactory));
    }
}