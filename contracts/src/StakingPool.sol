// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title 借贷池接口
/// @notice 定义了借贷池的基本操作接口
interface ILendingPool {
    /// @notice 存入资产到借贷池
    /// @param asset 资产地址
    /// @param amount 存入数量
    /// @param onBehalfOf 代表谁存入
    /// @param referralCode 推荐码
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /// @notice 从借贷池提取资产
    /// @param asset 资产地址
    /// @param amount 提取数量
    /// @param to 提取到的地址
    function withdraw(address asset, uint256 amount, address to) external;
}

/// @title WETH接口
/// @notice 封装ETH代币的标准接口，支持ETH和WETH之间的转换
interface IWETH {
    /// @notice 将ETH存入并转换为WETH
    function deposit() external payable;

    /// @notice 将WETH提取为ETH
    /// @param wad 提取的WETH数量
    function withdraw(uint256 wad) external;

    /// @notice 授权第三方使用WETH
    /// @param guy 被授权的地址
    /// @param wad 授权数量
    /// @return 是否授权成功
    function approve(address guy, uint256 wad) external returns (bool);

    /// @notice 转移WETH
    /// @param dst 目标地址
    /// @param wad 转移数量
    /// @return 是否转移成功
    function transfer(address dst, uint256 wad) external returns (bool);

    /// @notice 查询账户余额
    /// @param account 账户地址
    /// @return 账户余额
    function balanceOf(address account) external view returns (uint256);

    /// @notice 查询总供应量
    /// @return 总供应量
    function totalSupply() external view returns (uint256);

    /// @notice 查询代币精度
    /// @return 代币精度
    function decimals() external view returns (uint256);
}

/// @title 可铸造代币接口
/// @notice 扩展了ERC20标准，增加了铸币功能
interface IToken is IERC20 {
    /// @notice 铸造新代币
    /// @param to 接收代币的地址
    /// @param amount 铸造数量
    function mint(address to, uint256 amount) external;
}

/// @title 质押接口
/// @notice 定义了质押池的基本操作接口
interface IStaking {
    /// @notice 质押ETH
    function stake() external payable;

    /// @notice 取消质押
    /// @param amount 取消质押的数量
    function unstake(uint256 amount) external;

    /// @notice 领取奖励
    function claim() external;

    /// @notice 查询账户质押数量
    /// @param account 账户地址
    /// @return 质押数量
    function balanceOf(address account) external view returns (uint256);

    /// @notice 查询账户可领取奖励
    /// @param account 账户地址
    /// @return 可领取奖励数量
    function earned(address account) external view returns (uint256);
}

/// @title 质押池合约
/// @notice 允许用户质押ETH并获得奖励的合约，支持与借贷池集成
contract StakingPool is IStaking {
    /// @notice KK代币合约地址
    IToken public kkToken;
    /// @notice 借贷池合约地址
    ILendingPool public lendingPool;
    /// @notice WETH合约地址
    IWETH public weth;
    /// @notice 合约所有者地址
    address public owner;

    /// @notice 每个区块的奖励数量 (10 KK)
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    /// @notice 总质押数量
    uint256 public totalStaked;
    /// @notice 上次奖励计算区块号
    uint256 public lastRewardBlock;
    /// @notice 每份质押累计奖励 (精度: 1e12)
    uint256 public accRewardPerShare;

    /// @notice 用户信息结构体
    struct UserInfo {
        uint256 amount;        /// 质押数量
        uint256 rewardDebt;    /// 奖励债务 (用于计算待领取奖励)
        uint256 stakingTime;   /// 质押时间戳
    }

    /// @notice 用户信息映射
    mapping(address => UserInfo) public userInfo;

    /// @notice 质押事件
    event Staked(address indexed user, uint256 amount);
    /// @notice 取消质押事件
    event Unstaked(address indexed user, uint256 amount);
    /// @notice 领取奖励事件
    event Claimed(address indexed user, uint256 reward);

    /// @notice 仅所有者修饰符
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @notice 合约构造函数
    /// @param _kkToken KK代币合约地址
    /// @param _weth WETH代币合约地址
    /// @param _lendingPool 借贷池合约地址
    constructor(address _kkToken, address _weth, address _lendingPool) {
        kkToken = IToken(_kkToken);
        weth = IWETH(_weth);
        lendingPool = ILendingPool(_lendingPool);
        owner = msg.sender;
        lastRewardBlock = block.number;
    }

    /// @notice 更新奖励状态
    /// @dev 计算并更新accRewardPerShare，确保奖励分配的准确性
    function updateReward() public {
        // 如果当前区块小于等于上次奖励区块或总质押量为0，则更新区块号并返回
        if (block.number <= lastRewardBlock || totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        // 计算区块差异
        uint256 diff = block.number - lastRewardBlock;
        // 计算应分配的奖励总数
        uint256 reward = diff * REWARD_PER_BLOCK;
        // 更新每份质押累计奖励 (乘以1e12增加精度)
        accRewardPerShare += (reward * 1e12) / totalStaked;
        // 更新上次奖励计算区块号
        lastRewardBlock = block.number;
    }

    /// @notice 用户质押ETH
    /// @dev 用户存入ETH并开始赚取奖励
    function stake() external payable override {
        // 要求质押数量大于0
        require(msg.value > 0, "Cannot stake 0");
        // 更新奖励状态
        updateReward();

        // 获取用户信息的存储引用
        UserInfo storage user = userInfo[msg.sender];

        // 发放待领取的奖励
        if (user.amount > 0) {
            // 计算待领取奖励 = (用户质押数量 * 每份累计奖励) / 精度 - 奖励债务
            uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                // 铸造KK代币并发送给用户
                kkToken.mint(msg.sender, pending);
            }
        } else {
            // 如果是首次质押，记录质押时间
            user.stakingTime = block.timestamp;
        }

        // 增加用户质押数量
        user.amount += msg.value;
        // 增加总质押数量
        totalStaked += msg.value;
        // 更新用户奖励债务 (防止重复领取奖励)
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        // 存入借贷市场
        if (address(lendingPool) != address(0)) {
            // 将ETH存入WETH合约
            weth.deposit{value: msg.value}();
            // 授权借贷池使用WETH
            weth.approve(address(lendingPool), msg.value);
            // 将WETH存入借贷池
            lendingPool.deposit(address(weth), msg.value, address(this), 0);
        }

        // 触发质押事件
        emit Staked(msg.sender, msg.value);
    }

    /// @notice 用户取消质押
    /// @param amount 取消质押的数量
    /// @dev 用户提取质押的ETH并领取应得奖励
    function unstake(uint256 amount) external override {
        // 获取用户信息的存储引用
        UserInfo storage user = userInfo[msg.sender];
        // 验证用户质押数量大于等于提取数量且提取数量大于0
        require(user.amount >= amount && amount > 0, "Invalid amount");

        // 更新奖励状态
        updateReward();

        // 计算待领取奖励 = (用户质押数量 * 每份累计奖励) / 精度 - 奖励债务
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;

        // 减少用户质押数量
        user.amount -= amount;
        // 减少总质押数量
        totalStaked -= amount;

        // 如果用户质押数量为0，则重置质押时间
        if (user.amount == 0) {
            user.stakingTime = 0;
        }

        // 更新用户奖励债务 (防止重复领取奖励)
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        // 发放奖励
        if (pending > 0) {
            // 铸造KK代币并发送给用户
            kkToken.mint(msg.sender, pending);
        }

        // 从借贷市场提取
        if (address(lendingPool) != address(0)) {
            // 从借贷池提取WETH
            lendingPool.withdraw(address(weth), amount, address(this));
            // 将WETH提取为ETH
            weth.withdraw(amount);
        }

        // 将ETH转回给用户
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
        // 触发取消质押事件
        emit Unstaked(msg.sender, amount);
    }

    /// @notice 用户领取奖励
    /// @dev 领取累积的KK代币奖励
    function claim() external override {
        // 更新奖励状态
        updateReward();

        // 获取用户信息的存储引用
        UserInfo storage user = userInfo[msg.sender];
        // 计算待领取奖励 = (用户质押数量 * 每份累计奖励) / 精度 - 奖励债务
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;

        // 要求待领取奖励大于0
        require(pending > 0, "No rewards");

        // 更新用户奖励债务 (防止重复领取奖励)
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        // 铸造KK代币并发送给用户
        kkToken.mint(msg.sender, pending);

        // 触发领取奖励事件
        emit Claimed(msg.sender, pending);
    }

    /// @notice 查询账户质押数量
    /// @param account 账户地址
    /// @return 质押的ETH数量
    function balanceOf(address account) external view override returns (uint256) {
        // 返回指定账户的质押数量
        return userInfo[account].amount;
    }

    /// @notice 查询账户可领取奖励
    /// @param account 账户地址
    /// @return 可领取的奖励数量
    function earned(address account) external view override returns (uint256) {
        // 获取用户信息的内存拷贝
        UserInfo memory user = userInfo[account];
        // 如果用户没有质押，则返回0
        if (user.amount == 0) return 0;

        // 获取当前每份累计奖励
        uint256 currentAcc = accRewardPerShare;
        // 如果当前区块大于上次奖励区块且总质押量大于0，则计算最新奖励
        if (block.number > lastRewardBlock && totalStaked > 0) {
            // 计算区块差异
            uint256 diff = block.number - lastRewardBlock;
            // 计算应分配的奖励总数
            uint256 reward = diff * REWARD_PER_BLOCK;
            // 更新当前每份累计奖励 (乘以1e12增加精度)
            currentAcc += (reward * 1e12) / totalStaked;
        }

        // 计算可领取奖励 = (用户质押数量 * 当前每份累计奖励) / 精度 - 奖励债务
        return (user.amount * currentAcc) / 1e12 - user.rewardDebt;
    }

    /// @notice 查询账户质押时间
    /// @param account 账户地址
    /// @return 质押时间戳
    function getStakingTime(address account) external view returns (uint256) {
        // 返回指定账户的质押时间戳
        return userInfo[account].stakingTime;
    }

    /// @notice 更新借贷池地址
    /// @param _lendingPool 新的借贷池合约地址
    /// @dev 仅所有者可以调用此函数来更新借贷池地址
    function updateLendingPool(address _lendingPool) external onlyOwner {
        // 更新借贷池合约地址
        lendingPool = ILendingPool(_lendingPool);
    }

    /// @notice 紧急提取功能
    /// @dev 仅所有者可以提取合约中的所有ETH余额
    function emergencyWithdraw() external onlyOwner {
        // 获取合约ETH余额
        uint256 balance = address(this).balance;
        // 如果余额大于0，则转给所有者
        if (balance > 0) {
            (bool success, ) = payable(owner).call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    /// @notice 接收ETH
    /// @dev 允许合约接收ETH转账
    receive() external payable {}
}