// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseScript.sol";
import "../src/NFTMarketV2.sol";
import "../src/MyERC1363Token.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketV2Script is BaseScript {
    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() external broadcaster {
        // 部署 MyERC1363Token
        MyERC1363Token paymentToken = new MyERC1363Token("NFT Payment Token", "NPT");
        console.log("MyERC1363Token deployed at:", address(paymentToken));
        saveContract("MyERC1363Token", address(paymentToken));

        // 部署 NFTMarketV2 实现
        address impl = address(new NFTMarketV2());
        console.log("NFTMarketV2 implementation deployed at:", impl);

        // 初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NFTMarketV2.initialize.selector,
            address(paymentToken)
        );

        // 部署代理
        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        NFTMarketV2 nftMarket = NFTMarketV2(address(proxy));
        console.log("NFTMarketV2 proxy deployed at:", address(nftMarket));
        saveContract("NFTMarketV2", address(nftMarket));
    }
}