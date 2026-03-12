// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title CheatCode 测试套件
 * @notice 测试 Foundry vm cheat codes 的核心功能
 * @dev 包括区块操作（roll/warp）、地址伪装（prank）、资金操作（deal）、预期 revert 和事件验证
 *
 * 常用 Cheat Codes:
 * - vm.roll: 更改区块号
 * - vm.warp: 更改区块时间戳
 * - vm.prank/vm.startPrank/vm.stopPrank: 伪造 msg.sender
 * - vm.deal: 调整地址的 ETH 余额
 * - vm.expectRevert: 预期下一个调用会 revert
 * - vm.expectEmit: 预期下一个调用会触发特定事件
 */
import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {Owner} from "../src/Owner.sol";
import {BaseERC20} from "../src/BaseERC20.sol";

/**
 * @title CheatCodeTest
 * @notice 测试 Foundry 提供的各种测试作弊码（Cheat Codes）
 * @dev 这些 cheat codes 允许测试合约在可控环境中模拟各种区块链状态和行为
 */
contract CheatCodeTest is Test {
    Counter public counter;
    address public alice;
    address public bob;

    function setUp() public {
        counter = new Counter();
        // makeAddr: 创建一个虚拟地址（不需私钥），用于测试
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        // console.log("New Counter instance:", address(counter));
    }

    /**
     * @notice Fuzz 测试示例：使用随机 uint256 参数测试 setNumber
     * @param x 随机输入值，用于测试计数器设置
     */
    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }

    /**
     * @notice 测试 vm.roll - 更改当前区块号
     * @dev vm.roll 不会执行区块内的任何交易，只改变区块号
     *      常用于测试时间敏感的逻辑或需要特定区块状态的场景
     */
    function test_Roll() public {
        counter.increment();
        assertEq(counter.number(), 1);

        uint256 newBlockNumber = 100;
        vm.roll(newBlockNumber);  // 将区块号滚动到 100
        console.log("after roll Block number", block.number);

        assertEq(block.number, newBlockNumber);
        // 注意：vm.roll 不会触发任何合约调用，所以 counter 状态保持不变
        assertEq(counter.number(), 1);
    }

    /**
     * @notice 测试 vm.warp 和 skip - 更改区块时间戳
     * @dev vm.warp 设置绝对时间戳，skip 增加相对时间
     *      用于测试时间锁、冷却期等时间相关逻辑
     *
     * 注意：时间戳必须 >= 当前区块时间戳，且不能超过 2^256-1
     */
    function test_Warp() public {
        uint256 newTimestamp = 1753207525;
        vm.warp(newTimestamp);  // 将时间戳 Warp 到指定值
        console.log("after warp Block timestamp", block.timestamp);
        assertEq(block.timestamp, newTimestamp);

        skip(1000);  // 跳过 1000 秒
        console.log("after skip Block timestamp", block.timestamp);
        assertEq(block.timestamp, newTimestamp + 1000);
    }

    /**
     * @notice 测试 vm.prank - 单次调用伪造 msg.sender
     * @dev vm.prank 只影响下一次外部调用（EOA -> 合约或合约 -> 合约）
     *      每次调用后自动重置 msg.sender
     *
     * 安全注意：prank 只改变 msg.sender，不改变 tx.origin
     *         如需完全模拟 EOA 行为，应使用 vm.startPrank + vm.stopPrank
     */
    function test_Prank() public {
        console.log("current contract address", address(this));
        console.log("test_Prank  counter address", address(counter));

        Owner o = new Owner();
        console.log("owner address", address(o.owner()));
        // 新部署的 Owner 合约的 owner 是部署者（当前测试合约）
        assertEq(o.owner(), address(this));

        console.log("alice address", alice);
        vm.prank(alice);  // 下一次调用使用 alice 作为 msg.sender
        Owner o2 = new Owner();
        // 由于 prank，o2 的 owner 应该是 alice
        assertEq(o2.owner(), alice);
    }

    /**
     * @notice 测试 vm.startPrank / vm.stopPrank - 持续伪造 msg.sender
     * @dev startPrank 后，所有后续调用都会使用指定的地址作为 msg.sender
     *      直到调用 stopPrank 才会恢复原始调用者
     *
     * 使用场景：需要连续多次调用都使用同一假地址时
     * 注意：务必在测试结束时调用 stopPrank，避免影响其他测试
     */
    function test_StartPrank() public {
        console.log("current contract address", address(this));
        console.log("test_StartPrank  counter address", address(counter));

        Owner o = new Owner();
        console.log("owner address", address(o.owner()));
        assertEq(o.owner(), address(this));

        vm.startPrank(alice);  // 开始伪装 alice
        Owner o2 = new Owner();
        assertEq(o2.owner(), alice);

        // 连续多次调用都使用 alice
        Owner o4 = new Owner();
        assertEq(o4.owner(), alice);

        vm.stopPrank();  // 停止伪装，恢复原始调用者

        Owner o3 = new Owner();
        assertEq(o3.owner(), address(this));  // 恢复为测试合约地址
    }

    /**
     * @notice 测试 vm.deal - 调整地址的 ETH 余额
     * @dev 用于模拟任意地址的 ETH 余额，无需真正转账
     *      常用于测试需要检查余额的合约逻辑
     *
     * 注意：deal 设置的是绝对余额，不是增量
     */
    function test_Deal() public {
        vm.deal(alice, 100 ether);  // 将 alice 的余额设为 100 ether
        assertEq(alice.balance, 100 ether);

        vm.deal(alice, 1 ether);  // 重新设置为 1 ether
        assertEq(alice.balance, 1 ether);
    }

    /**
     * @notice 测试 deal 函数 - 为 ERC20 代币合约分配测试代币
     * @dev 这是 StdCheats 库提供的 deal 重载版本
     *      内部会调用代币的 mint 或直接修改余额（如果可操作）
     *
     * 注意：需要代币合约实现 ERC20Detils 或被 deal 函数识别
     */
    function test_Deal_ERC20() public {
        BaseERC20 token = new BaseERC20("OpenSpace S7", "OS6");
        console.log("token address", address(token));

        console.log("alice address", alice);

        // 1 token = 10^18 单位（ERC20 decimals 默认 18）
        // deal: 为指定地址分配指定数量的代币
        deal(address(token), alice, 100 ether);  // 100 * 10^18

        console.log("alice token balance", token.balanceOf(alice));
        assertEq(token.balanceOf(alice), 100 ether);
    }

    // forge test test/Cheatcode.t.sol --mt test_Revert_IFNOT_Owner -vv
    /**
     * @notice 测试 vm.expectRevert - 预期调用 revert 并验证错误消息
     * @dev expectRevert 会捕获下一个调用的 revert，测试继续执行
     *      如果下一个调用没有 revert，测试将失败
     *
     * 使用场景：验证访问控制、输入验证等应该 revert 的情况
     *
     * @dev 这里测试 Owner 合约的 transferOwnership 只有 owner 可以调用
     */
    function test_Revert_IFNOT_Owner() public {
        // alice 部署一个 Owner 合约
        vm.startPrank(alice);
        Owner o = new Owner();
        vm.stopPrank();

        // bob 尝试调用 transferOwnership，应该被 revert
        vm.startPrank(bob);
        // vm.expectRevert("错误消息"): 预期下一条语句会 revert 并匹配错误消息
        vm.expectRevert("Only the owner can transfer ownership");
        o.transferOwnership(alice);
        vm.stopPrank();
    }

    /**
     * @notice 测试 vm.expectRevert - 使用原始错误数据匹配
     * @dev 可以使用 abi.encodeWithSignature 生成精确的错误数据
     *      适用于自定义错误类型（custom error）的匹配
     */
    function test_Revert_IFNOT_Owner2() public {
        vm.startPrank(alice);
        Owner o = new Owner();
        vm.stopPrank();

        vm.startPrank(bob);
        // 生成自定义错误的完整编码数据
        bytes memory data = abi.encodeWithSignature("NotOwner(address)", bob);
        vm.expectRevert(data);  // 预期精确匹配错误数据
        o.transferOwnership2(alice);
        vm.stopPrank();
    }

    event OwnerTransfer(address indexed caller, address indexed newOwner);

    /**
     * @notice 测试 vm.expectEmit - 预期事件发射
     * @dev expectEmit 用于验证合约是否正确发射了期望的事件
     *      参数分别对应：checkTopic1, checkTopic2, checkTopic3, checkData
     *
     * 使用注意：
     * - true 表示需要检查该字段是否匹配
     * - false 表示跳过该字段检查
     * - 必须先调用 expectEmit，再 emit 要验证的事件，然后执行实际调用
     *
     * @dev 这里验证 Owner 合约正确发射了 OwnerTransfer 事件
     */
    function test_Emit() public {
        Owner o = new Owner();

        // 预期发射 OwnerTransfer(caller=newOwner=)
        // 参数说明：
        // - true: 检查 topic1 (caller 地址)
        // - true: 检查 topic2 (newOwner 地址)
        // - false: 不检查 topic3
        // - false: 不检查 event data
        vm.expectEmit(true, true, false, false);
        emit OwnerTransfer(address(this), bob);  // 声明期望的事件参数

        o.transferOwnership(bob);  // 实际执行调用，验证事件是否匹配
    }

}