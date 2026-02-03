// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// forge script script/Vesting.s.sol:VestingScript --rpc-url <network> --broadcast
// forge inspect src/Vesting.sol:TokenVesting abi --json > ../abis/Vesting.json
import "./BaseScript.sol";
import {TokenVesting} from "../src/Vesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

contract VestingScript is BaseScript {
    TokenVesting public vesting;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为ERC20代币和受益人地址
        IERC20 token = IERC20(0x0000000000000000000000000000000000000000);
        address beneficiary = 0x0000000000000000000000000000000000000000;

        vesting = new TokenVesting(token, beneficiary);
        console.log("Vesting deployed at:", address(vesting));
        saveContract("Vesting", address(vesting));
    }
}