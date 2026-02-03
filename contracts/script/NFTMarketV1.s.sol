// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/NFTMarketV1.s.sol:NFTMarketV1Script --rpc-url <network> --broadcast
// forge inspect src/NFTMarketV1.sol:NFTMarketV1 abi --json > ../abis/NFTMarketV1.json
import "./BaseScript.sol";
import "../src/NFTMarketV1.sol";
import "../src/MyERC1363Token.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketV1Script is BaseScript {
    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() external broadcaster {
        // 部署 MyERC1363Token
        MyERC1363Token paymentToken = new MyERC1363Token("NFT Payment Token", "NPT");
        console.log("MyERC1363Token deployed at:", address(paymentToken));
        saveContract("MyERC1363Token", address(paymentToken));

        // 部署 NFTMarketV1 实现
        address impl = address(new NFTMarketV1());
        console.log("NFTMarketV1 implementation deployed at:", impl);

        // 初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            address(paymentToken)
        );

        // 部署代理
        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        NFTMarketV1 nftMarket = NFTMarketV1(address(proxy));
        console.log("NFTMarketV1 proxy deployed at:", address(nftMarket));
        saveContract("NFTMarketV1", address(nftMarket));
    }
}