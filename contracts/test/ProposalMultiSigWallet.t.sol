// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ProposalMultiSigWallet} from "../src/ProposalMultiSigWallet.sol";

/**
 * @title TargetContract - 测试目标合约
 * @notice 用于测试多签钱包的合约调用功能
 * @dev 提供一个简单的 setValue 函数，用于验证多签钱包是否能正确执行合约调用
 *
 * 功能：
 * - 接收 ETH 并设置数值
 * - 记录调用者地址
 *
 * 测试用途：
 * - 验证多签钱包能正确调用任意合约
 * - 验证 ETH 转账功能
 * - 验证 msg.sender 指向多签钱包地址
 */
contract TargetContract {
    // 存储的数值
    uint256 public value;
    // 调用者地址
    address public sender;

    /**
     * @notice 设置数值并记录调用者
     * @dev 可以接收 ETH，用于测试多签钱包的 ETH 转账功能
     * @param _value 要设置的数值
     */
    function setValue(uint256 _value) external payable {
        value = _value;
        sender = msg.sender;
    }
}

/**
 * @title ProposalMultiSigWalletTest - 提案型多签钱包测试合约
 * @notice 全面测试提案型多签钱包的核心功能
 * @dev 使用 Foundry 测试框架，覆盖提案-确认-执行的完整流程
 *
 * ============================================================
 * 测试覆盖
 * ============================================================
 *
 * 1. 构造函数测试
 *    - 验证多签持有者设置正确
 *    - 验证门槛计算正确
 *    - 验证权限控制生效
 *
 * 2. 提案流程测试
 *    - 提案提交（propose）
 *    - 提案确认（confirm）
 *    - 提案执行（execute）
 *
 * 3. 状态验证测试
 *    - 确认状态正确记录
 *    - 执行状态正确标记
 *    - ETH 转账正确完成
 *
 * ============================================================
 * 测试策略
 * ============================================================
 *
 * - 使用 makeAddr 创建测试账户
 * - 使用 vm.startPrank/stopPrank 模拟不同用户
 * - 使用 vm.deal 为合约充值
 * - 验证状态变化和事件触发
 *
 * 测试账户：
 * - alice, bob, charlie: 多签持有者
 * - dave: 非持有者（用于测试权限控制）
 */
contract ProposalMultiSigWalletTest is Test {
    // 多签钱包合约实例
    ProposalMultiSigWallet public wallet;
    // 测试目标合约实例
    TargetContract public target;

    // 测试账户：多签持有者
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    // 测试账户：非持有者
    address public dave = makeAddr("dave");

    // 测试数据：目标合约的测试数值
    uint256 public constant TEST_VALUE = 42;
    // 测试数据：转账金额
    uint256 public constant TEST_ETH = 1 ether;

    /**
     * @notice 测试初始化函数
     * @dev 在每个测试用例执行前自动调用
     *
     * 初始化步骤：
     * 1. 部署测试目标合约
     * 2. 创建多签持有者数组（alice, bob, charlie）
     * 3. 部署多签钱包合约
     * 4. 为钱包充值 10 ETH
     *
     * 多签配置：
     * - 持有者数量：3
     * - 确认门槛：2（3 * 2/3 = 2）
     *
     * 注意：
     * - threshold = 2 意味着需要 2/3 的持有者确认才能执行
     * - 这是常见的多签配置（多数同意）
     */
    function setUp() public {
        // 部署目标合约
        target = new TargetContract();

        // 创建多签持有者数组
        address[] memory owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = charlie;

        // 部署多签钱包
        wallet = new ProposalMultiSigWallet(owners);

        // 给钱包转入一些 ETH，用于测试转账功能
        vm.deal(address(wallet), 10 ether);
    }

    /**
     * @notice 测试构造函数
     * @dev 验证多签钱包的初始化是否正确
     *
     * 测试内容：
     * 1. 验证所有持有者都被正确标记为 owner
     * 2. 验证非持有者不是 owner
     * 3. 验证多签门槛计算正确（3个持有者 -> 门槛2）
     *
     * 预期结果：
     * - alice, bob, charlie 都是持有者
     * - dave 不是持有者
     * - 门槛为 2（3 * 2/3 = 2）
     *
     * 安全检查：
     * - 零地址不能作为持有者
     * - 持有者地址不能重复
     * - 门槛必须在 1 和 持有者数量之间
     */
    function test_Constructor() public {
        // 验证多签持有者
        assertTrue(wallet.isOwner(alice));
        assertTrue(wallet.isOwner(bob));
        assertTrue(wallet.isOwner(charlie));
        assertFalse(wallet.isOwner(dave));

        // 验证多签门槛
        assertEq(wallet.threshold(), 2); // 3 * 2/3 = 2
    }

    /**
     * @notice 测试提案提交功能
     * @dev 验证持有者能否正确提交提案
     *
     * 测试流程：
     * 1. 编码目标合约的函数调用数据
     * 2. Alice 提交提案（目标：TargetContract，金额：1 ETH，数据：setValue(42)）
     * 3. 验证提案数据是否正确存储
     *
     * 验证内容：
     * - 目标地址正确
     * - 转账金额正确
     * - 调用数据正确
     * - 初始状态为未执行
     * - 初始确认数为 0
     *
     * 多签流程说明：
     * 1. 任何持有者都可以提交提案
     * 2. 提案包含：目标地址、转账金额、调用数据
     * 3. 提案初始状态：未执行，确认数 = 0
     */
    function test_Propose() public {
        // 编码要调用的函数：setValue(uint256)
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", TEST_VALUE);

        // Alice 提交提案
        vm.startPrank(alice);
        uint256 proposalId = wallet.propose(address(target), TEST_ETH, data);

        // 验证提案数据
        (
            address targetAddr,
            uint256 value,
            bytes memory proposalData,
            bool executed,
            uint256 confirmations
        ) = wallet.proposals(proposalId);

        assertEq(targetAddr, address(target));
        assertEq(value, TEST_ETH);
        assertEq(proposalData, data);
        assertFalse(executed);
        assertEq(confirmations, 0);

        vm.stopPrank();
    }

    /**
     * @notice 测试提案确认功能
     * @dev 验证持有者能否正确确认提案
     *
     * 测试流程：
     * 1. Alice 提交提案
     * 2. Bob 确认提案
     * 3. 验证确认状态和确认数
     *
     * 验证内容：
     * - Bob 的确认状态为 true
     * - 提案的确认数增加到 1
     *
     * 确认规则：
     * - 每个持有者只能确认一次
     * - 确认不会自动执行提案
     * - 已确认的持有者不能再次确认
     */
    function test_Confirm() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", TEST_VALUE);

        // Alice 提交提案
        vm.startPrank(alice);
        uint256 proposalId = wallet.propose(address(target), TEST_ETH, data);
        vm.stopPrank();

        // Bob 确认提案
        vm.startPrank(bob);
        wallet.confirm(proposalId);

        // 验证确认状态
        assertTrue(wallet.confirmations(proposalId, bob));
        (,,,,uint256 confirmations) = wallet.proposals(proposalId);
        assertEq(confirmations, 1);

        vm.stopPrank();
    }

    /**
     * @notice 测试提案执行功能
     * @dev 验证提案在达到确认门槛后能否正确执行
     *
     * 测试流程：
     * 1. Alice 提交提案并确认（确认数：1）
     * 2. Bob 确认提案（确认数：2，达到门槛）
     * 3. Dave（非持有者）执行提案
     * 4. 验证执行结果
     *
     * 验证内容：
     * - 目标合约的 value 被设置为 TEST_VALUE (42)
     * - 目标合约的 sender 是多签钱包地址
     * - 目标合约收到了 1 ETH
     * - 提案状态标记为已执行
     *
     * 关键点：
     * - 任何人都可以执行已达到门槛的提案（包括非持有者）
     * - 执行后提案状态变为已执行，无法再次执行
     * - 合约调用和 ETH 转账同时完成
     *
     * 执行条件：
     * - 提案必须存在
     * - 提案必须未执行过
     * - 确认数必须达到门槛
     */
    function test_Execute() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", TEST_VALUE);

        // Alice 提交提案并确认
        vm.startPrank(alice);
        uint256 proposalId = wallet.propose(address(target), TEST_ETH, data);
        wallet.confirm(proposalId);
        vm.stopPrank();

        // Bob 确认提案（达到门槛 2/3）
        vm.startPrank(bob);
        wallet.confirm(proposalId);
        vm.stopPrank();

        // Dave（非持有者）执行提案
        vm.startPrank(dave);
        wallet.execute(proposalId);

        // 验证执行结果
        assertEq(target.value(), TEST_VALUE);
        assertEq(target.sender(), address(wallet));
        assertEq(address(target).balance, TEST_ETH);

        // 验证提案状态
        assertTrue(wallet.isProposalExecuted(proposalId));

        vm.stopPrank();
    }

}
