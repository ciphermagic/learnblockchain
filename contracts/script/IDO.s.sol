// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/IDO.s.sol:IDOScript --rpc-url <network> --broadcast
// forge inspect src/IDO.sol:IDO abi --json > ../abis/IDO.json
import "./BaseScript.sol";
import {IDO} from "../src/IDO.sol";
import {Script} from "forge-std/Script.sol";

contract IDOScript is BaseScript {
    IDO public ido;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        ido = new IDO(0x0000000000000000000000000000000000000000, 30 days); // Placeholder token address and 30 days duration
        saveContract("IDO", address(ido));
    }
}