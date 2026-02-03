// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/ERC721_Upgrade.s.sol:ERC721UpgradeScript --rpc-url <network> --broadcast
// forge inspect src/ERC721_Upgrade.sol:ERC721_Upgrade abi --json > ../abis/ERC721_Upgrade.json
import "./BaseScript.sol";
import {ERC721_Upgrade} from "../src/ERC721_Upgrade.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Script} from "forge-std/Script.sol";

contract ERC721UpgradeScript is BaseScript {
    ERC721_Upgrade public erc721Upgrade;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 部署 ERC721_Upgrade 实现
        address impl = address(new ERC721_Upgrade());
        console.log("ERC721_Upgrade implementation deployed at:", impl);

        // 初始化数据
        bytes memory initData = abi.encodeWithSelector(
            ERC721_Upgrade.initialize.selector,
            "TestNFT", // name
            "TNFT"     // symbol
        );

        // 部署代理
        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        erc721Upgrade = ERC721_Upgrade(address(proxy));
        console.log("ERC721_Upgrade proxy deployed at:", address(erc721Upgrade));
        saveContract("ERC721_Upgrade", address(erc721Upgrade));
    }
}