// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/ERC721_Upgrade_V2.s.sol:ERC721UpgradeV2Script --rpc-url <network> --broadcast
// forge inspect src/ERC721_Upgrade_V2.sol:ERC721_Upgrade_V2 abi --json > ../abis/ERC721_Upgrade_V2.json
import "./BaseScript.sol";
import {ERC721_Upgrade_V2} from "../src/ERC721_Upgrade_V2.sol";
import {Script} from "forge-std/Script.sol";

contract ERC721UpgradeV2Script is BaseScript {
    ERC721_Upgrade_V2 public erc721UpgradeV2;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 部署 ERC721_Upgrade_V2 实现（这是升级合约的新实现）
        erc721UpgradeV2 = new ERC721_Upgrade_V2();
        console.log("ERC721_Upgrade_V2 implementation deployed at:", address(erc721UpgradeV2));
        saveContract("ERC721_Upgrade_V2", address(erc721UpgradeV2));
    }
}