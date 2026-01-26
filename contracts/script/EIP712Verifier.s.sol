// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BaseScript.sol";
import {EIP712Verifier} from "../src/EIP712Verifier.sol";
import {Script} from "forge-std/Script.sol";

// forge script script/EIP712Verifier.s.sol --rpc-url local --broadcast
// forge inspect src/EIP712Verifier.sol:EIP712Verifier abi --json > ../abis/EIP712Verifier.json
contract EIP712VerifierScript is BaseScript {
    EIP712Verifier public verifier;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        verifier = new EIP712Verifier();
        saveContract("EIP712Verifier", address(verifier));
    }
}
