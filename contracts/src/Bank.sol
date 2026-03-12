pragma solidity ^0.8.9;

/**
 * @title Bank
 * @notice ETH存款银行合约，维护存款排行榜（前3名）
 * @dev 实现了一个简单的ETH存款系统，核心功能包括：
 *      1. 接收用户的ETH存款
 *      2. 实时维护存款金额前3名的排行榜
 *      3. 管理员可提取合约中的所有ETH
 *
 * 核心机制：
 * - 排行榜算法：使用插入排序维护前3名，时间复杂度O(n)，n=3
 * - 权限控制：只有部署时指定的admin可以提取资金
 * - 存款方式：支持receive()和deposit()两种方式
 *
 * 安全考虑：
 * - admin使用immutable修饰，部署后不可更改
 * - 提取资金使用call{value}而非transfer，避免gas限制问题
 * - 排行榜更新逻辑经过充分测试，避免数组越界
 */
contract Bank {
    /// @notice 管理员地址，部署后不可更改，只有管理员可以提取合约资金
    address public immutable admin;

    /// @notice 记录每个地址的存款总额（单位：wei）
    mapping(address => uint) public deposits;

    /// @notice 存储存款金额前3名的地址，按存款金额从高到低排序
    /// @dev 数组索引0为第1名，索引1为第2名，索引2为第3名
    address[3] public topDepositors;

    /// @dev 排行榜固定长度为3，使用常量节省gas
    uint8 private constant TOP_COUNT = 3;

    /**
     * @notice 构造函数，将部署者设置为管理员
     * @dev admin使用immutable修饰，部署后永久不可更改，提高安全性
     */
    constructor() {
        admin = msg.sender;
    }

    /**
     * @notice 接收ETH的回退函数，用户直接向合约转账时触发
     * @dev 使用receive()而非fallback()，语义更明确，gas消耗更低
     *      自动调用_handleDeposit()处理存款逻辑
     */
    receive() external payable {
        _handleDeposit();
    }

    /**
     * @notice 显式存款函数，用户可以主动调用此函数存款
     * @dev 与receive()功能相同，提供两种存款方式供用户选择
     */
    function deposit() external payable {
        _handleDeposit();
    }

    /**
     * @notice 内部函数，处理存款的核心逻辑
     * @dev 执行流程：
     *      1. 累加用户的存款金额（msg.value）
     *      2. 调用updateTopDepositors()更新排行榜
     *      注意：没有检查msg.value > 0，允许0值存款（虽然无意义但不会出错）
     */
    function _handleDeposit() internal {
        deposits[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
    }

    /**
     * @notice 更新前3名存款人排行榜
     * @param depositor 本次存款的用户地址
     * @dev 算法分为两个分支：
     *
     *      分支1：如果depositor已经在前3名中
     *      - 直接调用_updateRanking()重新排序（因为其存款金额可能已超过其他人）
     *
     *      分支2：如果depositor不在前3名中
     *      - 遍历前3名，找到第一个"空位"或"存款金额小于depositor"的位置
     *      - 将depositor插入该位置，并将后续元素向后移动（类似插入排序）
     *
     *      时间复杂度：O(n)，n=3，实际执行非常快
     *
     *      注意事项：
     *      - 使用uint8节省gas，因为TOP_COUNT=3，不会溢出
     *      - 插入时从后向前移动元素，避免覆盖数据
     */
    function updateTopDepositors(address depositor) internal {
        uint depositorBalance = deposits[depositor];

        // 分支1：检查depositor是否已在前3名中
        for (uint8 i = 0; i < TOP_COUNT; i++) {
            if (topDepositors[i] == depositor) {
                _updateRanking();
                return;
            }
        }

        // 分支2：尝试将depositor插入前3名
        for (uint8 i = 0; i < TOP_COUNT; i++) {
            address currentAddr = topDepositors[i];
            // 条件：当前位置为空 或 depositor的存款金额更大
            if (currentAddr == address(0) || depositorBalance > deposits[currentAddr]) {
                // 将后续元素向后移动，为depositor腾出位置
                for (uint8 j = 2; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = depositor;
                break;
            }
        }
    }

    /**
     * @notice 使用插入排序算法重新排序前3名
     * @dev 经典的插入排序实现，适用于小规模数据（n=3）
     *
     *      算法流程：
     *      1. 从索引1开始遍历（索引0默认已排序）
     *      2. 将当前元素（key）与前面的元素逐个比较
     *      3. 如果前面的元素存款金额更小，则向后移动
     *      4. 找到合适位置后插入key
     *
     *      排序规则：按存款金额从高到低排序
     *
     *      边界处理：
     *      - 跳过address(0)，避免无效地址参与排序
     *      - 使用int8类型的j，允许j=-1作为循环终止条件
     *
     *      时间复杂度：O(n²)，但n=3时性能优异
     */
    function _updateRanking() internal {
        for (uint8 i = 1; i < TOP_COUNT; i++) {
            address key = topDepositors[i];
            if (key == address(0)) continue;

            uint keyDeposit = deposits[key];
            int8 j = int8(i) - 1;

            // 向前查找插入位置，同时将较小的元素向后移动
            while (j >= 0 && (topDepositors[uint8(j)] == address(0) || deposits[topDepositors[uint8(j)]] < keyDeposit)) {
                topDepositors[uint8(j + 1)] = topDepositors[uint8(j)];
                j--;
            }

            topDepositors[uint8(j + 1)] = key;
        }
    }

    /**
     * @notice 查询前3名存款人及其存款金额
     * @return 返回两个数组：地址数组和对应的存款金额数组
     * @dev 返回值说明：
     *      - 第一个返回值：address[3]，前3名的地址（按存款金额从高到低）
     *      - 第二个返回值：uint[3]，对应的存款金额
     *      - 如果某个位置为空（address(0)），对应的金额为0
     *
     *      使用场景：
     *      - 前端展示排行榜
     *      - 其他合约查询排名信息
     */
    function getTopDepositors() external view returns (address[3] memory, uint[3] memory) {
        uint[3] memory amounts;
        for (uint8 i = 0; i < TOP_COUNT; i++) {
            amounts[i] = deposits[topDepositors[i]];
        }
        return (topDepositors, amounts);
    }

    /**
     * @notice 管理员提取合约中的所有ETH
     * @dev 权限控制：只有admin可以调用
     *
     *      安全机制：
     *      1. 使用require检查调用者身份
     *      2. 检查合约余额是否大于0
     *      3. 使用call{value}而非transfer，避免2300 gas限制
     *      4. 检查转账是否成功，失败则回滚
     *
     *      注意事项：
     *      - 此函数会提取合约中的所有ETH，包括所有用户的存款
     *      - 用户的deposits记录不会被清零，这是一个潜在的设计问题
     *      - 实际应用中应该实现用户单独提取自己存款的功能
     *
     *      潜在风险：
     *      - admin可以提走所有用户的存款，用户无法取回
     *      - 这是一个中心化的设计，不适合生产环境
     */
    function withdraw() external {
        require(msg.sender == admin, "Only admin can withdraw");

        uint balance = address(this).balance;

        require(balance > 0, "No balance to withdraw");

        (bool success,) = admin.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}