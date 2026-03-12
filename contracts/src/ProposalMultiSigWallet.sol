// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ProposalMultiSigWallet - 提案型多签钱包合约
 * @notice 这是一个基于提案模式的多签名钱包合约，支持多个持有者共同管理资金和执行交易
 * @dev 实现了提案-确认-执行的三步流程，确保交易安全性
 *
 * 核心功能：
 * 1. 提案提交：任何持有者都可以提交交易提案
 * 2. 提案确认：持有者对提案进行投票确认
 * 3. 提案执行：达到门槛后任何人都可以执行提案
 *
 * 安全特性：
 * - 多签门槛：默认为持有者数量的 2/3
 * - 防重复确认：每个持有者只能确认一次
 * - 防重复执行：已执行的提案无法再次执行
 */
contract ProposalMultiSigWallet {
    // 提案结构
    struct Proposal {
        address target;        // 目标合约地址
        uint256 value;         // 发送的 ETH 数量
        bytes data;            // 调用数据
        bool executed;         // 是否已执行
        uint256 confirmations; // 确认数量
    }

    // 多签持有者列表
    address[] public owners;
    // 记录地址是否为多签持有者
    mapping(address => bool) public isOwner;
    // 提案列表
    Proposal[] public proposals;
    // 记录每个多签持有者对每个提案的确认状态
    mapping(uint256 => mapping(address => bool)) public confirmations;
    // 多签门槛（2/3）
    uint256 public threshold;

    // 事件
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer, address target, uint256 value, bytes data);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed owner);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);

    // 修饰器：只有多签持有者可以调用
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    // 修饰器：提案必须存在且未执行
    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposals.length, "Proposal does not exist");
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    // 修饰器：提案必须未被该多签持有者确认
    modifier notConfirmed(uint256 proposalId) {
        require(!confirmations[proposalId][msg.sender], "Proposal already confirmed");
        _;
    }

    /**
     * @notice 构造函数：初始化多签钱包
     * @dev 设置多签持有者列表和确认门槛
     * @param _owners 多签持有者地址数组，至少需要3个地址
     *
     * 要求：
     * - 持有者数量 >= 3
     * - 所有地址必须非零
     * - 所有地址必须唯一
     *
     * 门槛计算：threshold = (owners.length * 2) / 3
     * 例如：3个持有者 -> 门槛2，4个持有者 -> 门槛2，5个持有者 -> 门槛3
     */
    constructor(address[] memory _owners) {
        require(_owners.length >= 3, "At least 3 owners required");

        // 遍历持有者列表，进行验证并初始化
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        // 设置多签门槛为 2/3（向下取整）
        threshold = (owners.length * 2) / 3;
    }

    /**
     * @notice 提交提案
     * @dev 只有多签持有者可以提交提案，提案ID自动递增
     * @param _target 目标合约地址（可以是外部合约或EOA地址）
     * @param _value 发送的 ETH 数量（单位：wei）
     * @param _data 调用数据（可以是函数调用的编码数据，或空数据）
     * @return proposalId 新创建的提案ID
     *
     * 使用场景：
     * - 转账 ETH：_target 为接收地址，_value 为金额，_data 为空
     * - 调用合约：_target 为合约地址，_value 为0或需要的ETH，_data 为函数调用编码
     */
    function propose(
        address _target,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner returns (uint256 proposalId) {
        // 使用当前提案数组长度作为新提案ID
        proposalId = proposals.length;

        // 创建新提案并添加到数组
        proposals.push(
            Proposal({
                target: _target,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0
            })
        );

        emit ProposalSubmitted(proposalId, msg.sender, _target, _value, _data);
    }

    /**
     * @notice 确认提案
     * @dev 持有者对提案进行投票确认，每个持有者只能确认一次
     * @param proposalId 提案ID
     *
     * 要求：
     * - 调用者必须是多签持有者
     * - 提案必须存在且未执行
     * - 调用者未确认过该提案
     *
     * 确认后：
     * - 提案确认数 +1
     * - 记录该持有者已确认
     * - 触发 ProposalConfirmed 事件
     */
    function confirm(uint256 proposalId)
    external
    onlyOwner
    proposalExists(proposalId)
    notConfirmed(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        proposal.confirmations += 1;
        confirmations[proposalId][msg.sender] = true;

        emit ProposalConfirmed(proposalId, msg.sender);
    }

    /**
     * @notice 执行提案
     * @dev 当提案确认数达到门槛后，任何人都可以执行提案
     * @param proposalId 提案ID
     *
     * 要求：
     * - 提案必须存在且未执行
     * - 确认数必须达到门槛（threshold）
     *
     * 执行流程：
     * 1. 检查确认数是否达到门槛
     * 2. 标记提案为已执行（防止重入攻击）
     * 3. 使用 call 执行目标交易
     * 4. 检查执行结果，失败则回滚
     *
     * 注意：
     * - 使用 call 而非 transfer，支持合约调用
     * - 先标记已执行，遵循 CEI 模式（Checks-Effects-Interactions）
     */
    function execute(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.confirmations >= threshold, "Not enough confirmations");

        // 先标记为已执行，防止重入攻击
        proposal.executed = true;

        // 执行提案：调用目标地址，发送 ETH 和数据
        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Transaction execution failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }

    /**
     * @notice 获取提案数量
     * @return 提案数量
     */
    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    /**
     * @notice 获取多签持有者数量
     * @return 多签持有者数量
     */
    function getOwnerCount() external view returns (uint256) {
        return owners.length;
    }

    /**
     * @notice 获取提案执行状态
     * @param proposalId 提案ID
     * @return 是否已执行
     */
    function isProposalExecuted(uint256 proposalId) external view returns (bool) {
        require(proposalId < proposals.length, "Proposal does not exist");
        return proposals[proposalId].executed;
    }

    // 允许合约接收 ETH
    receive() external payable {}
}
