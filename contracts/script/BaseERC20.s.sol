// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/BaseERC20.s.sol:BaseERC20Script --rpc-url <network> --broadcast
// forge inspect src/BaseERC20.sol:BaseERC20 abi --json > ../abis/BaseERC20.json
import "./BaseScript.sol";
import {BaseERC20} from "../src/BaseERC20.sol";
import {Script} from "forge-std/Script.sol";

contract BaseERC20Script is BaseScript {
    BaseERC20 public baseERC20;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        baseERC20 = new BaseERC20("TestToken", "TST");
        saveContract("BaseERC20", address(baseERC20));
    }
}