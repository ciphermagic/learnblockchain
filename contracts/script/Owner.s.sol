// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/Owner.s.sol:OwnerScript --rpc-url <network> --broadcast
// forge inspect src/Owner.sol:Owner abi --json > ../abis/Owner.json
import "./BaseScript.sol";
import {Owner} from "../src/Owner.sol";
import {Script} from "forge-std/Script.sol";

contract OwnerScript is BaseScript {
    Owner public owner;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        owner = new Owner();
        saveContract("Owner", address(owner));
    }
}