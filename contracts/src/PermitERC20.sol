// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title PermitERC20
 * @notice 实现EIP-2612 Permit功能的ERC20代币合约
 * @dev 核心特性：
 *      1. 标准ERC20功能：transfer、transferFrom、approve、balanceOf、allowance
 *      2. EIP-2612 Permit：通过链下签名授权，无需链上approve交易
 *      3. EIP-712结构化签名：使用域分隔符和类型化数据，提高安全性
 *
 *      Permit机制的优势：
 *      - 用户体验：一笔交易完成授权+转账，节省gas和时间
 *      - 无需ETH：用户可以在没有ETH的情况下授权代币（元交易）
 *      - 安全性：使用EIP-712签名，防止重放攻击和跨链攻击
 *
 *      工作流程：
 *      1. 用户在链下签名授权消息（包含owner、spender、value、nonce、deadline）
 *      2. 第三方（或用户自己）调用permit()函数，提交签名
 *      3. 合约验证签名有效性，自动执行approve
 *      4. 第三方可以立即调用transferFrom()转移代币
 *
 *      安全机制：
 *      - nonce：每个地址的nonce递增，防止签名重放
 *      - deadline：签名有效期限制，防止过期签名被使用
 *      - DOMAIN_SEPARATOR：绑定合约地址和链ID，防止跨链/跨合约重放
 */
contract PermitERC20 is IERC20Permit {
    /// @notice 代币名称
    string public name;

    /// @notice 代币符号
    string public symbol;

    /// @notice 代币小数位数（标准为18）
    uint8 public decimals;

    /// @notice 代币总供应量
    uint256 public totalSupply;

    /// @dev 记录每个地址的代币余额
    mapping(address => uint256) balances;

    /// @dev 记录授权额度：owner => spender => amount
    mapping(address => mapping(address => uint256)) allowances;

    /// @notice EIP-712域分隔符，用于防止跨链/跨合约签名重放攻击
    /// @dev 在构造函数中计算并存储，包含合约名称、版本、链ID、合约地址
    bytes32 private immutable _DOMAIN_SEPARATOR;

    /// @notice EIP-2612 Permit消息的类型哈希
    /// @dev 定义了Permit消息的结构，用于EIP-712签名验证
    bytes32 private constant _PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev 记录每个地址的当前nonce，用于防止签名重放攻击
    mapping(address => uint256) private _nonces;

    /// @notice 代币转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice 构造函数，初始化代币并计算域分隔符
     * @dev 执行流程：
     *      1. 设置代币基本信息（名称、符号、小数位）
     *      2. 铸造1亿代币给部署者
     *      3. 计算并存储EIP-712域分隔符
     *
     *      域分隔符计算：
     *      - 包含合约名称、版本号、链ID、合约地址
     *      - 使用immutable存储，部署后不可更改
     *      - 防止签名在不同链或不同合约间重放
     */
    constructor() {
        name = "AndyToken";
        symbol = "AnToken";
        decimals = 18;
        totalSupply = 100000000 * 10 ** uint256(decimals); // 1亿代币

        balances[msg.sender] = totalSupply;

        // 计算EIP-712域分隔符
        // 域分隔符绑定了合约的唯一标识，防止跨链/跨合约签名重放
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),  // 版本号
                block.chainid,           // 链ID（防止跨链重放）
                address(this)            // 合约地址（防止跨合约重放）
            )
        );
    }

    /**
     * @notice 查询指定地址的代币余额
     * @param _owner 要查询的地址
     * @return balance 该地址的代币余额
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
     * @notice 转账代币给指定地址
     * @param _to 接收地址
     * @param _value 转账数量
     * @return success 是否成功
     * @dev 安全检查：
     *      1. 发送者余额充足
     *      2. 接收地址不是零地址
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice 从指定地址转账代币（需要事先授权）
     * @param _from 发送地址
     * @param _to 接收地址
     * @param _value 转账数量
     * @return success 是否成功
     * @dev 安全检查：
     *      1. 发送者余额充足
     *      2. 调用者的授权额度充足
     *      3. 接收地址不是零地址
     *      4. 转账后自动扣减授权额度
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
     * @notice 授权指定地址可以转移的代币数量
     * @param _spender 被授权的地址
     * @param _value 授权数量
     * @return success 是否成功
     * @dev 注意：直接覆盖原有授权额度，不是累加
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "ERC20: approve to the zero address");

        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice 查询授权额度
     * @param _owner 代币所有者
     * @param _spender 被授权者
     * @return remaining 剩余授权额度
     */
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    /**
     * @notice EIP-2612 Permit函数，通过链下签名授权代币转移
     * @param owner 代币所有者（签名者）
     * @param spender 被授权者
     * @param value 授权数量
     * @param deadline 签名有效期截止时间（Unix时间戳）
     * @param v 签名参数v（ECDSA签名的恢复标识）
     * @param r 签名参数r（ECDSA签名的前32字节）
     * @param s 签名参数s（ECDSA签名的后32字节）
     * @dev 核心流程：
     *      1. 检查签名是否过期（block.timestamp <= deadline）
     *      2. 构造EIP-712结构化消息哈希（包含owner、spender、value、nonce、deadline）
     *      3. 使用ecrecover恢复签名者地址
     *      4. 验证签名者是否为owner
     *      5. 执行授权（设置allowances）
     *      6. 递增nonce（防止签名重放）
     *
     *      安全机制：
     *      - deadline：防止过期签名被使用
     *      - nonce：每次使用后递增，防止签名重放
     *      - DOMAIN_SEPARATOR：防止跨链/跨合约签名重放
     *      - ecrecover：验证签名的真实性
     *
     *      使用场景：
     *      - 用户在链下签名授权消息
     *      - 第三方（或用户自己）调用permit()提交签名
     *      - 合约自动执行授权，无需用户发送approve交易
     *      - 第三方可以立即调用transferFrom()转移代币
     *
     *      注意事项：
     *      - nonce在验证签名前递增（_nonces[owner]++），防止重入攻击
     *      - 签名格式必须符合EIP-712标准
     *      - v值通常为27或28
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        // 构造EIP-712结构化消息哈希
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner]++,  // 使用后立即递增nonce
                deadline
            )
        );

        // 构造最终的签名消息哈希（EIP-191格式）
        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, structHash));

        // 使用ecrecover恢复签名者地址
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner, "ERC20Permit: invalid signature");

        // 执行授权
        allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 查询指定地址的当前nonce
     * @param owner 要查询的地址
     * @return 当前nonce值
     * @dev nonce用于防止签名重放攻击，每次使用permit后递增
     */
    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @notice 查询EIP-712域分隔符
     * @return 域分隔符的哈希值
     * @dev 域分隔符绑定了合约的唯一标识（名称、版本、链ID、地址）
     *      用于防止签名在不同链或不同合约间重放
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }
}