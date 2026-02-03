// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/StakingPool.s.sol:StakingPoolScript --rpc-url <network> --broadcast
// forge inspect src/StakingPool.sol:StakingPool abi --json > ../abis/StakingPool.json
import "./BaseScript.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {Script} from "forge-std/Script.sol";

contract StakingPoolScript is BaseScript {
    StakingPool public stakingPool;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        stakingPool = new StakingPool(
            0x0000000000000000000000000000000000000000, // KK token address (placeholder)
            0x0000000000000000000000000000000000000000, // WETH address (placeholder)
            0x0000000000000000000000000000000000000000  // Lending pool address (placeholder)
        );
        saveContract("StakingPool", address(stakingPool));
    }
}