pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "permit2-light-sdk/sdk/IPermit2.sol";
import "permit2-light-sdk/sdk/ISignatureTransfer.sol";

/**
 * @title TokenBank
 * @notice 支持Uniswap Permit2协议的代币银行合约
 * @dev 核心改进：
 *      1. 传统存款：deposit() - 需要用户先approve
 *      2. Permit2存款：depositWithPermit2() - 使用Uniswap的Permit2协议，一笔交易完成授权+存款
 *
 *      Permit2协议的优势：
 *      - 统一授权：用户只需授权一次Permit2合约，即可与所有支持Permit2的DApp交互
 *      - 更安全：支持批量授权、部分授权、时间限制等高级功能
 *      - 更灵活：支持witness数据，可以在授权中附加额外信息
 *      - 更省gas：避免每个DApp都需要单独approve
 *
 *      Permit2工作流程：
 *      1. 用户一次性授权Permit2合约（token.approve(PERMIT2_ADDRESS, type(uint256).max)）
 *      2. 用户在链下签名授权消息（包含token、amount、nonce、deadline等）
 *      3. 用户（或第三方）调用depositWithPermit2()，提交签名
 *      4. 合约调用Permit2.permitTransferFrom()验证签名并转移代币
 *      5. 更新用户的存款记录
 *
 *      与EIP-2612 Permit的区别：
 *      - EIP-2612：每个代币合约需要单独实现permit()函数
 *      - Permit2：统一的授权协议，所有ERC20代币都可以使用
 *
 *      适用场景：
 *      - 与Uniswap、1inch等支持Permit2的协议集成
 *      - 改善用户体验，减少授权步骤
 *      - 支持元交易（meta-transaction）
 */
contract TokenBank {
    /// @notice 代币合约接口
    IERC20 public token;

    /// @notice Permit2合约地址（Sepolia测试网地址）
    /// @dev Permit2是Uniswap开发的统一授权协议，部署在多个链上
    ///      主网和大多数测试网地址相同：0x000000000022D473030F116dDEE9F6B43aC78BA3
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @notice 记录每个用户存入的代币数量
    mapping(address => uint256) public deposits;

    /// @notice 存款事件
    event Deposit(address indexed user, uint256 amount);

    /// @notice 取款事件
    event Withdraw(address indexed user, uint256 amount);

    /**
     * @notice 构造函数，设置代币合约地址
     * @param _tokenAddress ERC20代币合约地址
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "TokenBank: token address cannot be zero");
        token = IERC20(_tokenAddress);
    }

    /**
     * @notice 传统存入代币方式（需要先approve）
     * @param _amount 存入数量
     * @dev 前置条件：用户必须先调用token.approve(address(this), _amount)
     */
    function deposit(uint256 _amount) external {
        require(_amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= _amount, "TokenBank: insufficient token balance");

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "TokenBank: transfer failed");

        deposits[msg.sender] += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice 使用Permit2进行授权转账并存款
     * @param _amount 存入数量
     * @param _nonce Permit2的nonce（用于防止签名重放）
     * @param _deadline 签名有效期截止时间（Unix时间戳）
     * @param _signature 用户的签名数据
     * @dev 执行流程：
     *      1. 检查金额和余额
     *      2. 构造Permit2所需的参数结构体
     *      3. 调用Permit2.permitTransferFrom()验证签名并转移代币
     *      4. 更新存款记录
     *
     *      前置条件：
     *      - 用户必须先授权Permit2合约：token.approve(PERMIT2_ADDRESS, type(uint256).max)
     *      - 用户必须在链下签名授权消息
     *
     *      Permit2参数说明：
     *      - PermitTransferFrom：包含授权信息（token、amount、nonce、deadline）
     *      - SignatureTransferDetails：包含转账目标（to、requestedAmount）
     *      - msg.sender：签名者地址
     *      - _signature：用户的签名数据
     *
     *      安全机制：
     *      - nonce：防止签名重放攻击
     *      - deadline：防止过期签名被使用
     *      - Permit2合约内部验证签名有效性
     */
    function depositWithPermit2(
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes calldata _signature
    ) external {
        require(_amount > 0, "TokenBank: deposit amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= _amount, "TokenBank: insufficient token balance");

        // 构造Permit2所需的授权参数
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(token),
                amount: _amount
            }),
            nonce: _nonce,
            deadline: _deadline
        });

        // 构造转账目标参数
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(this),
            requestedAmount: _amount
        });

        // 调用Permit2合约进行授权转账
        IPermit2(PERMIT2_ADDRESS).permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            _signature
        );

        deposits[msg.sender] += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice 提取代币
     * @param _amount 提取数量
     * @dev 安全机制：先减少记录再转账，防止重入攻击
     */
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "TokenBank: withdraw amount must be greater than zero");
        require(deposits[msg.sender] >= _amount, "TokenBank: insufficient deposit balance");

        // 先减少记录，防止重入攻击
        deposits[msg.sender] -= _amount;

        bool success = token.transfer(msg.sender, _amount);
        require(success, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @notice 查询用户在银行中的存款余额
     * @param _user 用户地址
     * @return 存款余额
     */
    function balanceOf(address _user) external view returns (uint256) {
        return deposits[_user];
    }
}