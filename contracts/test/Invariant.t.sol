// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 不变量测试套件
 * @notice 测试 Foundry 的不变量测试（Invariant Testing）功能
 * @dev 通过随机执行合约函数来验证某些属性始终保持不变
 *
 * 不变量测试核心概念：
 * - 不变量（Invariant）：在合约整个生命周期中始终保持为真的属性
 * - 相比单元测试，不变量测试更关注合约的全局属性
 * - 自动随机调用合约函数，验证不变量不被破坏
 *
 * 常见不变量示例：
 * - ERC20: totalSupply == sum(balances)
 * - 治理合约：投票总数 <= 授权票数
 * - 借贷协议：总资产 + 利息 = 存款 + 借款
 * - 数学合约：操作后结果在合理范围内
 *
 * 重要安全考虑：
 * - 不变量测试不能替代形式化验证
 * - 需要精心设计 handler 函数覆盖所有关键路径
 * - 随机调用可能遗漏特定调用序列导致的漏洞
 */
import "forge-std/Test.sol";
import "../src/BaseERC20.sol";

/**
 * @title InvariantTest
 * @notice 展示不变量测试的基本用法
 * @dev 测试 ERC20 代币的总供应量等于所有账户余额之和
 *
 * 不变量测试组件：
 * 1. Handler（处理器）：被随机调用的函数，执行合约操作
 * 2. Invariant（不变量）：需要验证的属性
 * 3. targetContract：指定要测试的合约
 *
 * 测试流程：
 * 1. setUp: 初始化合约和测试账户
 * 2. Handler 函数：定义可以被随机调用的操作
 * 3. invariant_* 函数：定义需要验证的不变量
 * 4. Foundry 自动执行大量随机调用序列，然后验证不变量
 *
 * 运行方式：
 * - forge test --match-test invariant_*  // 运行所有不变量测试
 * - forge test -vv  // 查看详细执行过程
 * - 可以设置 --runs 参数调整测试迭代次数
 */
contract InvariantTest is Test {
    BaseERC20 public token;
    address[] public users;

    /**
     * @notice 初始化测试环境
     * @dev 创建 ERC20 代币合约和测试用户数组
     *
     * 设置步骤：
     * 1. 部署 BaseERC20 代币合约
     * 2. 创建 10 个测试用户地址
     * 3. 为每个用户分配初始代币
     * 4. 配置目标合约（handler）
     *
     * 注意：使用 uint160(i) 生成地址，避免与零地址冲突（从 1 开始）
     */
    function setUp() public {
        token = new BaseERC20("MyToken", "MTK");
        // console.log("New MyERC20 instance:", address(token));

        // 创建 10 个测试用户
        for (uint i = 1; i <= 10; i++) {
            // 使用 1-10 的 uint160 值作为测试地址
            // 这些是伪地址，无需私钥，仅用于测试
            address user = address(uint160(i));
            users.push(user);
            // 为每个用户分配 1000 个代币（乘以 10^18 因为 decimals=18）
            token.transfer(user, 1000 * 10 ** 18);
        }
        // 将测试合约本身也加入用户列表
        users.push(address(this));

        // 配置不变量测试的目标合约
        // 这里指定当前合约作为 handler（因为 transfer 函数在当前合约中）
        targetContract(address(this));
        // 也可以直接针对代币合约：
        // targetSelector(address(token), "transfer(address,uint256)");
    }

    /**
     * @notice Handler 函数：执行随机代币转账
     * @dev 这个函数会被 Foundry 随机调用多次，模拟各种转账场景
     *
     * Handler 设计要点：
     * - 函数必须是 public 或 external
     * - 参数由 Foundry 自动随机生成
     * - 使用 vm.assume 过滤无效参数
     *
     * 参数处理：
     * - fromIndex, toIndex: 使用模运算确保索引在有效范围内
     * - amount: 限制在发送者余额范围内，避免转账失败
     *
     * @param fromIndex 发送者索引
     * @param toIndex 接收者索引
     * @param amount 转账金额
     */
    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) public {
        // 确保索引在有效范围内
        // 使用模运算确保索引不会越界
        fromIndex = fromIndex % users.length;
        toIndex = toIndex % users.length;

        // vm.assume: 添加前置条件，确保不是同一个用户
        // 转账不能发生在同一地址之间（没有意义且可能绕过某些检查）
        vm.assume(fromIndex != toIndex);

        // 获取发送者和接收者地址
        address from = users[fromIndex];
        address to = users[toIndex];

        // 确保发送者有足够的余额
        // 使用模运算将金额限制在余额范围内，避免下溢
        uint256 fromBalance = token.balanceOf(from);
        amount = amount % (fromBalance + 1);

        // 执行转账：
        // 1. 使用 vm.prank 伪造 msg.sender
        // 2. 调用 token.transfer
        // 如果转账失败（余额不足等），测试会记录但继续执行
        vm.prank(from);
        token.transfer(to, amount);
    }

    /**
     * @notice 不变量验证：总供应量等于所有账户余额之和
     * @dev 这是 ERC20 合约的核心不变量之一
     *
     * 不变量逻辑：
     * - ERC20 规范要求：totalSupply = sum(balances)
     * - 如果这个不变量被破坏，说明存在以下问题：
     *   1. 代币增发/销毁逻辑有漏洞
     *   2. 某些函数绕过了余额更新
     *   3. 存在整数溢出/下溢
     *
     * 测试执行：
     * - Foundry 会执行数千次随机调用序列
     * - 每次调用后都会执行此不变量检查
     * - 如果任何一次检查失败，整个测试失败
     *
     * @dev 本测试验证：经过任意随机转账操作后，代币总供应量始终等于所有账户余额之和
     */
    function invariant_totalSupplyEqualsSumOfBalances() public view {
        // 获取代币的总供应量
        uint256 totalSupply = token.totalSupply();

        // 计算所有用户余额的总和
        uint256 sumOfBalances = 0;
        console.log("users.length", users.length);
        for (uint i = 0; i < users.length; i++) {
            sumOfBalances += token.balanceOf(users[i]);
        }

        // 验证不变量：总供应量必须等于所有余额之和
        // 如果不相等，说明合约存在漏洞
        assertEq(totalSupply, sumOfBalances, "Total supply does not equal the sum of all user balances");
    }

}