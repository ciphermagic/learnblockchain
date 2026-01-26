// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC721_Upgrade} from "../src/ERC721_Upgrade.sol";
import {ERC721_Upgrade_V2} from "../src/ERC721_Upgrade_V2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ERC721_UpgradeTest is Test {
    ERC721_Upgrade public proxy;
    ERC721_Upgrade public implementationV1;
    ERC721_Upgrade_V2 public implementationV2;

    address public owner = address(0x1);
    address public user = address(0x2);
    uint256 public tokenId = 1;

    function setUp() public {
        vm.startPrank(owner);
        // 部署V1实现合约
        implementationV1 = new ERC721_Upgrade();

        // 通过代理部署合约，使用代理进行初始化
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeWithSelector(ERC721_Upgrade.initialize.selector, "TestToken", "TT")
        );

        proxy = ERC721_Upgrade(address(proxyContract));
        console.log("init proxy address", address(proxy));
        vm.stopPrank();
    }

    function testInitialize() public {
        // 验证合约是否正确初始化
        assertEq(proxy.name(), "TestToken");
        assertEq(proxy.symbol(), "TT");
        assertEq(proxy.owner(), owner);
    }

    function testMint() public {
        // 验证只有所有者才能铸造
        vm.prank(owner);
        proxy.mint(user, tokenId);

        assertEq(proxy.balanceOf(user), 1);
        assertEq(proxy.ownerOf(tokenId), user);
    }

    function testMintUnauthorized() public {
        // 测试只有所有者才能铸造
        vm.expectRevert();
        vm.prank(user);
        proxy.mint(user, tokenId);
    }

    function testUpgradeToV2() public {
        // 为测试升级部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 测试只有所有者才能升级
        vm.prank(owner);
        proxy.upgradeToAndCall(address(implementationV2), abi.encodeWithSelector(ERC721_Upgrade_V2.initializeV2.selector, 3));

        // 现在代理指向V2实现
        ERC721_Upgrade_V2 v2Proxy = ERC721_Upgrade_V2(address(proxy));
        console.log("upgrade to v2 proxy address", address(v2Proxy));

        // 测试V1功能是否仍然正常
        vm.prank(owner);
        v2Proxy.mint(user, tokenId);

        assertEq(v2Proxy.balanceOf(user), 1);
        assertEq(v2Proxy.ownerOf(tokenId), user);

        // 测试V2新功能
        uint256 version = v2Proxy.getVersion();
        assertEq(version, 3);
    }

    function testUpgradeToV2Unauthorized() public {
        // 部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 测试非所有者不能升级
        vm.prank(user);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(implementationV2), abi.encodeWithSelector(ERC721_Upgrade_V2.initializeV2.selector, 2));
    }

    function testMintAfterUpgrade() public {
        // 部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 升级到V2
        vm.prank(owner);
        proxy.upgradeToAndCall(address(implementationV2), abi.encodeWithSelector(ERC721_Upgrade_V2.initializeV2.selector, 2));

        ERC721_Upgrade_V2 v2Proxy = ERC721_Upgrade_V2(address(proxy));

        // 在升级后验证新版本
        uint256 version = v2Proxy.getVersion();
        assertEq(version, 2);

        // 测试V1功能在升级后是否仍然工作
        vm.prank(owner);
        v2Proxy.mint(owner, 100);

        assertEq(v2Proxy.balanceOf(owner), 1);
        assertEq(v2Proxy.ownerOf(100), owner);
    }

    function testV2InitializeV2() public {
        // 部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 升级到V2
        vm.prank(owner);
        proxy.upgradeToAndCall(address(implementationV2), abi.encodeWithSelector(ERC721_Upgrade_V2.initializeV2.selector, 2));

        ERC721_Upgrade_V2 v2Proxy = ERC721_Upgrade_V2(address(proxy));

        // 验证版本号是否正确设置
        uint256 version = v2Proxy.getVersion();
        assertEq(version, 2);

        // 验证所有者才能调用initializeV2
        vm.prank(user);
        vm.expectRevert();
        v2Proxy.initializeV2(3);

        // 验证版本号没有改变
        assertEq(v2Proxy.getVersion(), 2);
    }
}