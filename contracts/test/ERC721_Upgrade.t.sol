// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC721_Upgrade} from "../src/ERC721_Upgrade.sol";
import {ERC721_Upgrade_V2} from "../src/ERC721_Upgrade_V2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ERC721_UpgradeTest
 * @notice ERC721可升级合约的测试套件
 * @dev 测试覆盖：
 *      1. 初始化测试：testInitialize() - 验证合约正确初始化
 *      2. 铸造测试：testMint() - 验证owner可以铸造NFT
 *      3. 铸造权限测试：testMintUnauthorized() - 验证非owner不能铸造
 *      4. 升级测试：testUpgradeToV2() - 验证V1升级到V2
 *      5. 升级权限测试：testUpgradeToV2Unauthorized() - 验证非owner不能升级
 *      6. 升级后铸造测试：testMintAfterUpgrade() - 验证升级后V1功能正常
 *      7. V2初始化测试：testV2InitializeV2() - 验证V2新功能
 *
 *      测试策略：
 *      - 使用ERC1967Proxy部署代理合约
 *      - 模拟owner和user两个角色
 *      - 验证V1到V2的平滑升级
 *      - 验证V1功能在升级后仍然可用
 *
 *      核心概念：
 *      - 实现合约：包含业务逻辑（ERC721_Upgrade、ERC721_Upgrade_V2）
 *      - 代理合约：存储数据，delegatecall到实现合约
 *      - upgradeToAndCall：升级实现并调用初始化函数
 */
contract ERC721_UpgradeTest is Test {
    /// @notice 代理合约实例（升级后转为V2类型）
    ERC721_Upgrade public proxy;

    /// @notice V1实现合约
    ERC721_Upgrade public implementationV1;

    /// @notice V2实现合约
    ERC721_Upgrade_V2 public implementationV2;

    /// @notice 合约所有者（也是测试中的owner）
    address public owner = address(0x1);

    /// @notice 普通用户
    address public user = address(0x2);

    /// @notice 测试用的tokenId
    uint256 public tokenId = 1;

    /**
     * @notice 测试前置设置
     * @dev 执行流程：
     *      1. 部署V1实现合约
     *      2. 创建代理合约，指向V1实现
     *      3. 通过代理调用initialize()初始化
     *      4. 代理合约完成部署，用户通过代理交互
     */
    function setUp() public {
        vm.startPrank(owner);
        // 部署V1实现合约
        implementationV1 = new ERC721_Upgrade();

        // 通过代理部署合约，使用代理进行初始化
        // ERC1967Proxy：标准代理实现，存储实现地址和代理管理员
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeWithSelector(ERC721_Upgrade.initialize.selector, "TestToken", "TT")
        );

        proxy = ERC721_Upgrade(address(proxyContract));
        console.log("init proxy address", address(proxy));
        vm.stopPrank();
    }

    /**
     * @notice 测试初始化功能
     * @dev 测试场景：
     *      - 验证name正确设置
     *      - 验证symbol正确设置
     *      - 验证owner正确设置
     */
    function testInitialize() public {
        // 验证合约是否正确初始化
        assertEq(proxy.name(), "TestToken");
        assertEq(proxy.symbol(), "TT");
        assertEq(proxy.owner(), owner);
    }

    /**
     * @notice 测试铸造功能
     * @dev 测试场景：
     *      - owner调用mint铸造NFT
     *      - 验证user获得NFT
     *      - 验证NFT所有权正确
     */
    function testMint() public {
        // 验证只有所有者才能铸造
        vm.prank(owner);
        proxy.mint(user, tokenId);

        assertEq(proxy.balanceOf(user), 1);
        assertEq(proxy.ownerOf(tokenId), user);
    }

    /**
     * @notice 测试非owner不能铸造
     * @dev 测试场景：
     *      - user尝试调用mint
     *      - 预期revert（只有owner可以铸造）
     *
     *      验证：权限控制正确
     */
    function testMintUnauthorized() public {
        // 测试只有所有者才能铸造
        vm.expectRevert();
        vm.prank(user);
        proxy.mint(user, tokenId);
    }

    /**
     * @notice 测试升级到V2
     * @dev 测试场景：
     *      - 部署V2实现合约
     *      - owner调用upgradeToAndCall升级
     *      - 验证V1功能（mint）仍正常
     *      - 验证V2新功能（getVersion）可用
     *
     *      测试重点：
     *      - 升级后数据保留
     *      - V1功能向后兼容
     *      - V2新功能可用
     */
    function testUpgradeToV2() public {
        // 为测试升级部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 测试只有所有者才能升级
        vm.prank(owner);
        // upgradeToAndCall：升级实现合约并调用初始化函数
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

    /**
     * @notice 测试非owner不能升级
     * @dev 测试场景：
     *      - user尝试调用upgradeToAndCall
     *      - 预期revert（只有owner可以升级）
     *
     *      验证：升级权限控制正确
     */
    function testUpgradeToV2Unauthorized() public {
        // 部署V2实现
        implementationV2 = new ERC721_Upgrade_V2();

        // 测试非所有者不能升级
        vm.prank(user);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(implementationV2), abi.encodeWithSelector(ERC721_Upgrade_V2.initializeV2.selector, 2));
    }

    /**
     * @notice 测试升级后的铸造功能
     * @dev 测试场景：
     *      - 升级到V2
     *      - 验证version正确设置
     *      - 验证V1的mint功能在升级后仍然正常
     *
     *      验证：向后兼容性
     */
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

    /**
     * @notice 测试V2的initializeV2功能
     * @dev 测试场景：
     *      - 升级到V2
     *      - 验证version正确设置
     *      - 验证非owner不能调用initializeV2
     *      - 验证owner可以更新version
     *
     *      测试重点：
     *      - V2初始化函数正确
     *      - 权限控制正确
     */
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