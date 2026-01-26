// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {PermitERC20} from "../src/PermitERC20.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/ERC20_Permit.s.sol --rpc-url local --broadcast
contract ERC20PermitScript is BaseScript {
    PermitERC20 public token;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        token = new PermitERC20();
        saveContract("ERC20Permit", address(token));
    }
}
