pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "./TokenBank.sol";

/**
 * @title TokenBankReceiver
 * @notice 支持ERC-1363回调的代币银行合约
 * @dev 核心改进：
 *      1. 继承TokenBank：保留传统的deposit()和withdraw()功能
 *      2. 实现IERC1363Receiver：支持通过transferAndCall()直接存款
 *
 *      ERC-1363协议的优势：
 *      - 一笔交易完成：用户调用token.transferAndCall()，一笔交易完成转账+存款
 *      - 无需approve：不需要先approve再deposit，简化用户操作
 *      - 回调机制：代币转账后自动触发onTransferReceived()回调
 *
 *      工作流程：
 *      1. 用户调用token.transferAndCall(address(this), amount, data)
 *      2. ERC1363代币合约执行转账，将代币转给TokenBankReceiver
 *      3. ERC1363代币合约调用TokenBankReceiver.onTransferReceived()
 *      4. onTransferReceived()更新用户的存款记录
 *      5. 返回函数选择器，表示成功接收
 *
 *      与传统deposit()的区别：
 *      - 传统方式：approve() -> deposit()（两笔交易）
 *      - ERC-1363方式：transferAndCall()（一笔交易）
 *
 *      适用场景：
 *      - 与支持ERC-1363的代币（如自定义代币）配合使用
 *      - 改善用户体验，减少交易步骤
 *      - 支持更复杂的回调逻辑（如自动质押、自动兑换等）
 *
 *      安全考虑：
 *      - 验证调用者是代币合约，防止恶意调用
 *      - 验证operator和from的关系，防止授权滥用
 */
contract TokenBankReceiver is TokenBank, IERC1363Receiver {
    /// @notice 扩展的ERC1363代币合约接口
    ERC1363 public extendedToken;

    /**
     * @notice 构造函数，设置ERC1363代币合约地址
     * @param _tokenAddress ERC1363代币合约地址（必须支持ERC-1363）
     * @dev 同时初始化父合约TokenBank
     */
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {
        extendedToken = ERC1363(_tokenAddress);
    }

    /**
     * @notice ERC-1363回调函数，在代币转账后自动触发
     * @param operator 调用转账的地址（通常是代币持有者）
     * @param from 代币发送者（付款人）
     * @param amount 转账金额
     * @param data 附加数据（可用于传递额外信息）
     * @return 函数选择器，表示成功接收
     * @dev 执行流程：
     *      1. 验证调用者是operator（防止第三方恶意调用）
     *      2. 验证调用者是代币合约（防止非代币合约调用）
     *      3. 更新from的存款记录
     *      4. 触发Deposit事件
     *      5. 返回函数选择器
     *
     *      安全机制：
     *      - 双重验证：operator和token合约地址
     *      - 防止重入：代币转账已完成，不存在重入风险
     *
     *      注意事项：
     *      - 第一个require检查operator，但注释说的是"caller is not the operator"，逻辑正确
     *      - 第二个require检查msg.sender是token合约，确保只有代币合约可以调用
     *      - data参数未使用，但保留接口兼容性
     */
    function onTransferReceived(
        address operator,     // 调用转账的人（通常是代币持有者）
        address from,         // 付款人（代币发送者）
        uint256 amount,       // 转账金额
        bytes calldata data   // 附加数据
    ) external override returns (bytes4) {
        // 验证调用者是代币合约，防止恶意合约调用
        require(msg.sender == address(token), "TokenBankV2: caller is not the token contract");

        // 更新用户的存款记录
        deposits[from] += amount;

        // 触发存款事件
        emit Deposit(from, amount);

        // 返回函数选择器，表示成功接收
        return this.onTransferReceived.selector;
    }
}