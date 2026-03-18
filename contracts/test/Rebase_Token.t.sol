// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/Rebase_Token.sol";

/**
 * @title RebaseTokenTest
 * @dev Rebase Token 合约的完整单元测试
 * 测试覆盖：
 * 1. 构造函数和初始状态
 * 2. ERC20 基本功能
 * 3. Rebase 核心机制
 * 4. 权限控制
 * 5. 边界情况和错误处理
 */
contract RebaseTokenTest is Test {
    RebaseToken public token;

    address public owner;
    address public user1;
    address public user2;

    // 常量定义
    uint256 constant INITIAL_SUPPLY = 100_000_000 * 10**18;
    uint256 constant REBASE_INTERVAL = 365 days;

    // 事件定义（用于测试事件触发）
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 indexed epoch, uint256 totalSupply);

    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署合约
        token = new RebaseToken();
    }

    // ============ 构造函数和初始状态测试 ============

    function test_InitialState() public view {
        // 验证基本信息
        assertEq(token.name(), "Rebase Deflation Token");
        assertEq(token.symbol(), "RDT");
        assertEq(token.decimals(), 18);

        // 验证所有者
        assertEq(token.owner(), owner);

        // 验证初始供应量
        assertEq(token.totalSupply(), INITIAL_SUPPLY);

        // 验证部署者余额
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);

        // 验证 rebase 状态
        assertEq(token.rebaseCount(), 0);
        assertEq(token.lastRebaseTime(), block.timestamp);
        assertFalse(token.canRebase());
    }

    function test_InitialGonsPerFragment() public view {
        uint256 gonsPerFragment = token.gonsPerFragment();
        assertTrue(gonsPerFragment > 0, "gonsPerFragment should be greater than 0");
    }

    // ============ ERC20 基本功能测试 ============

    function test_Transfer() public {
        uint256 transferAmount = 1000 * 10**18;

        // 记录转账前余额
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user1BalanceBefore = token.balanceOf(user1);

        // 执行转账
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, user1, transferAmount);
        token.transfer(user1, transferAmount);

        // 验证转账后余额
        assertEq(token.balanceOf(owner), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(user1), user1BalanceBefore + transferAmount);
    }

    function test_TransferRevertToZeroAddress() public {
        vm.expectRevert("Transfer to zero address");
        token.transfer(address(0), 1000);
    }

    function test_TransferRevertToContract() public {
        vm.expectRevert("Transfer to contract");
        token.transfer(address(token), 1000);
    }

    function test_Approve() public {
        uint256 approveAmount = 1000 * 10**18;

        // 执行授权
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, user1, approveAmount);
        token.approve(user1, approveAmount);

        // 验证授权额度
        assertEq(token.allowance(owner, user1), approveAmount);
    }

    function test_TransferFrom() public {
        uint256 transferAmount = 1000 * 10**18;

        // 先授权
        token.approve(user1, transferAmount);

        // 记录转账前余额
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user2BalanceBefore = token.balanceOf(user2);

        // user1 代表 owner 转账给 user2
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, user2, transferAmount);
        token.transferFrom(owner, user2, transferAmount);

        // 验证转账后余额
        assertEq(token.balanceOf(owner), ownerBalanceBefore - transferAmount);
        assertEq(token.balanceOf(user2), user2BalanceBefore + transferAmount);
        // 验证授权额度已扣减
        assertEq(token.allowance(owner, user1), 0);
    }

    function test_IncreaseAllowance() public {
        uint256 initialAllowance = 1000 * 10**18;
        uint256 addedAllowance = 500 * 10**18;

        // 初始授权
        token.approve(user1, initialAllowance);

        // 增加授权
        token.increaseAllowance(user1, addedAllowance);

        // 验证授权额度
        assertEq(token.allowance(owner, user1), initialAllowance + addedAllowance);
    }

    function test_DecreaseAllowance() public {
        uint256 initialAllowance = 1000 * 10**18;
        uint256 subtractedAllowance = 300 * 10**18;

        // 初始授权
        token.approve(user1, initialAllowance);

        // 减少授权
        token.decreaseAllowance(user1, subtractedAllowance);

        // 验证授权额度
        assertEq(token.allowance(owner, user1), initialAllowance - subtractedAllowance);
    }

    function test_DecreaseAllowanceToZero() public {
        uint256 initialAllowance = 1000 * 10**18;

        // 初始授权
        token.approve(user1, initialAllowance);

        // 减少授权超过当前额度
        token.decreaseAllowance(user1, initialAllowance + 1);

        // 验证授权额度归零
        assertEq(token.allowance(owner, user1), 0);
    }

    // ============ Rebase 核心机制测试 ============

    function test_ManualRebase() public {
        // 记录 rebase 前状态
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 gonsPerFragmentBefore = token.gonsPerFragment();
        uint256 rebaseCountBefore = token.rebaseCount();

        // 执行手动 rebase
        vm.expectEmit(true, false, false, true);
        emit Rebase(1, totalSupplyBefore * 99 / 100);
        token.manualRebase();

        // 验证 rebase 后状态
        uint256 expectedTotalSupply = totalSupplyBefore * 99 / 100;
        assertEq(token.totalSupply(), expectedTotalSupply, "Total supply should decrease by 1%");

        // 验证余额减少 1%
        uint256 expectedOwnerBalance = ownerBalanceBefore * 99 / 100;
        assertEq(token.balanceOf(owner), expectedOwnerBalance, "Owner balance should decrease by 1%");

        // 验证 gonsPerFragment 增加
        assertTrue(token.gonsPerFragment() > gonsPerFragmentBefore, "gonsPerFragment should increase");

        // 验证 rebaseCount 递增
        assertEq(token.rebaseCount(), rebaseCountBefore + 1, "rebaseCount should increment");

        // 验证 lastRebaseTime 更新
        assertEq(token.lastRebaseTime(), block.timestamp, "lastRebaseTime should update");
    }

    function test_RebaseWithTimeInterval() public {
        // 快进 365 天
        vm.warp(block.timestamp + REBASE_INTERVAL);

        // 验证可以 rebase
        assertTrue(token.canRebase(), "Should be able to rebase after 365 days");

        // 执行 rebase
        token.rebase();

        // 验证 rebase 成功
        assertEq(token.rebaseCount(), 1);
    }

    function test_RebaseRevertTooEarly() public {
        // 快进 364 天（不足 365 天）
        vm.warp(block.timestamp + REBASE_INTERVAL - 1 days);

        // 验证不能 rebase
        assertFalse(token.canRebase(), "Should not be able to rebase before 365 days");

        // 尝试 rebase 应该失败
        vm.expectRevert("Rebase too early");
        token.rebase();
    }

    function test_MultipleRebase() public {
        uint256 initialSupply = token.totalSupply();

        // 第一次 rebase
        token.manualRebase();
        uint256 supplyAfterFirst = token.totalSupply();
        assertEq(supplyAfterFirst, initialSupply * 99 / 100);

        // 第二次 rebase
        token.manualRebase();
        uint256 supplyAfterSecond = token.totalSupply();
        assertEq(supplyAfterSecond, supplyAfterFirst * 99 / 100);

        // 第三次 rebase
        token.manualRebase();
        uint256 supplyAfterThird = token.totalSupply();
        assertEq(supplyAfterThird, supplyAfterSecond * 99 / 100);

        // 验证累积效果：3 次 rebase 后约为初始供应量的 97.03%
        assertApproxEqRel(supplyAfterThird, initialSupply * 9703 / 10000, 0.01e18);
    }

    function test_RebaseAffectsAllUsers() public {
        // 分配代币给多个用户
        uint256 amount = 10000 * 10**18;
        token.transfer(user1, amount);
        token.transfer(user2, amount);

        // 记录 rebase 前余额
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);

        // 执行 rebase
        token.manualRebase();

        // 验证所有用户余额都减少 1%
        assertEq(token.balanceOf(owner), ownerBalanceBefore * 99 / 100);
        assertEq(token.balanceOf(user1), user1BalanceBefore * 99 / 100);
        assertEq(token.balanceOf(user2), user2BalanceBefore * 99 / 100);
    }

    function test_GonsBalanceUnchangedAfterRebase() public {
        // 分配代币给 user1
        uint256 amount = 10000 * 10**18;
        token.transfer(user1, amount);

        // 记录 rebase 前 gons 余额
        uint256 user1GonsBefore = token.gonBalanceOf(user1);

        // 执行 rebase
        token.manualRebase();

        // 验证 gons 余额不变
        assertEq(token.gonBalanceOf(user1), user1GonsBefore, "Gons balance should remain unchanged");

        // 但代币余额应该减少
        assertTrue(token.balanceOf(user1) < amount, "Token balance should decrease");
    }

    // ============ 权限控制测试 ============

    function test_RebaseOnlyOwner() public {
        // 快进 365 天
        vm.warp(block.timestamp + REBASE_INTERVAL);

        // 非 owner 尝试 rebase 应该失败
        vm.prank(user1);
        vm.expectRevert("Not owner");
        token.rebase();
    }

    function test_ManualRebaseOnlyOwner() public {
        // 非 owner 尝试手动 rebase 应该失败
        vm.prank(user1);
        vm.expectRevert("Not owner");
        token.manualRebase();
    }

    // ============ 辅助函数测试 ============

    function test_NextRebaseTime() public {
        uint256 expectedNextRebaseTime = block.timestamp + REBASE_INTERVAL;
        assertEq(token.nextRebaseTime(), expectedNextRebaseTime);
    }

    function test_CanRebaseAfterInterval() public {
        // 初始状态不能 rebase
        assertFalse(token.canRebase());

        // 快进 365 天
        vm.warp(block.timestamp + REBASE_INTERVAL);

        // 现在可以 rebase
        assertTrue(token.canRebase());
    }

    function test_GonBalanceOf() public {
        // 分配代币给 user1
        uint256 amount = 10000 * 10**18;
        token.transfer(user1, amount);

        // 验证 gons 余额
        uint256 gonsBalance = token.gonBalanceOf(user1);
        assertTrue(gonsBalance > 0, "Gons balance should be greater than 0");

        // 验证 gons 余额与代币余额的关系
        uint256 calculatedBalance = gonsBalance / token.gonsPerFragment();
        assertEq(calculatedBalance, amount, "Calculated balance should match transferred amount");
    }

    // ======================

    function testFuzz_Transfer(uint256 amount) public {
        // 限制 amount 在合理范围内
        amount = bound(amount, 1, token.balanceOf(owner));

        // 执行转账
        token.transfer(user1, amount);

        // 验证余额
        assertEq(token.balanceOf(user1), amount);
    }

    function testFuzz_MultipleRebase(uint8 rebaseCount) public {
        // 限制 rebase 次数在 1-20 之间
        rebaseCount = uint8(bound(rebaseCount, 1, 20));

        uint256 initialSupply = token.totalSupply();

        // 执行多次 rebase
        for (uint256 i = 0; i < rebaseCount; i++) {
       token.manualRebase();
        }

        // 验证总供应量减少
        assertTrue(token.totalSupply() < initialSupply, "Total supply should decrease");

        // 验证 rebaseCount
        assertEq(token.rebaseCount(), rebaseCount);
    }

    // ============ 边界情况测试 ============

    function test_TransferAllBalance() public {
        uint256 totalBalance = token.balanceOf(owner);

        // 转移所有余额
        token.transfer(user1, totalBalance);

        // 验证余额
        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(user1), totalBalance);
    }

    function test_RebaseWithSmallBalance() public {
        // 转移大部分代币，只保留少量
        uint256 smallAmount = 100;
        token.transfer(user1, token.balanceOf(owner) - smallAmount);

        // 执行 rebase
        token.manualRebase();

        // 验证小额余额也正确减少
        uint256 expectedBalance = smallAmount * 99 / 100;
        assertEq(token.balanceOf(owner), expectedBalance);
    }

    function test_ApproveDoesNotAffectRebase() public {
        // 授权
        uint256 approveAmount = 1000 * 10**18;
        token.approve(user1, approveAmount);

        // 执行 rebase
        token.manualRebase();

        // 验证授权额度不受 rebase 影响
        assertEq(token.allowance(owner, user1), approveAmount, "Allowance should not change after rebase");
    }
}
