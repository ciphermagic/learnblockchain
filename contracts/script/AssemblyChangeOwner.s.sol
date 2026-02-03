// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/AssemblyChangeOwner.s.sol:AssemblyChangeOwnerScript --rpc-url <network> --broadcast
// forge inspect src/AssemblyChangeOwner.sol:AssemblyChangeOwnerV1 abi --json > ../abis/AssemblyChangeOwnerV1.json
import "./BaseScript.sol";
import {AssemblyChangeOwnerV1} from "../src/AssemblyChangeOwner.sol";
import {Script} from "forge-std/Script.sol";

contract AssemblyChangeOwnerScript is BaseScript {
    AssemblyChangeOwnerV1 public assemblyChangeOwner;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        assemblyChangeOwner = new AssemblyChangeOwnerV1("DefaultName");
        saveContract("AssemblyChangeOwnerV1", address(assemblyChangeOwner));
    }
}