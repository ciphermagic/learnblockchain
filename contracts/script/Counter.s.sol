// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {Counter} from "../src/Counter.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/Counter.s.sol --rpc-url local --broadcast
contract CounterScript is BaseScript {
    Counter public counter;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        counter = new Counter();
        saveContract("Counter", address(counter));
    }
}
