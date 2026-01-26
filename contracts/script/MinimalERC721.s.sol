// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/MinimalERC721.sol";
import "./BaseScript.sol";
import {Counter} from "../src/Counter.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/MinimalERC721.s.sol --rpc-url local --broadcast
contract MinimalERC721Script is BaseScript {
    MinimalERC721 public contractAddr;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        contractAddr = new MinimalERC721("TestNFT","TestNFT");
        saveContract("MinimalERC721", address(contractAddr));
    }
}
