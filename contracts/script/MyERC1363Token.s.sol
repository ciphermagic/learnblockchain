// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {MyERC1363Token} from "../src/MyERC1363Token.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/MyERC1363Token.s.sol --rpc-url local --broadcast
contract MyERC1363TokenScript is BaseScript {
    MyERC1363Token public token;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        token = new MyERC1363Token("Test", "TEST");
        saveContract("MyERC1363Token", address(token));
    }
}
