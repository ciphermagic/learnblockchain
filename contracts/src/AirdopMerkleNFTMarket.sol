// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AirdopMerkleNFTMarket
 * @notice 基于Merkle树白名单的NFT市场合约
 * @dev 核心功能：
 *      1. NFT上架/取消/购买（标准市场功能）
 *      2. Merkle树白名单验证（链下生成，链上验证）
 *      3. 白名单用户享受50%折扣
 *      4. 支持EIP-2612 Permit授权（无需先approve）
 *      5. 支持ERC-1363回调购买
 *      6. Multicall批量调用（permitPrePay + claimNFT）
 *
 *      Merkle树白名单机制：
 *      - 链下生成：将所有白名单地址构建成Merkle树，存储merkleRoot
 *      - 链上验证：用户提供merkleProof，合约验证proof + user => merkleRoot
 *      - 优势：节省gas（只存储32字节root，不存储所有地址）
 *      - 防作弊：hasUsedWhitelist记录已使用优惠的地址，每人只能用一次
 *
 *      Multicall工作流程：
 *      1. 用户在链下签名permit授权消息
 *      2. 用户调用multicall([permitPrePay, claimNFT])
 *      3. permitPrePay()使用签名授权代币
 *      4. claimNFT()验证白名单并转移代币和NFT
 *      5. 一笔交易完成授权+购买
 *
 *      安全机制：
 *      - 白名单验证：MerkleProof.verifyCalldata()
 *      - 防重复使用：hasUsedWhitelist映射
 *      - 权限检查：上架时验证NFT所有权或授权
 *      - 状态更新：先更新isActive再转账（防重入）
 *
 *      适用场景：
 *      - 白名单用户优惠购买NFT
 *      - 空投活动（白名单用户低价购买）
 *      - 会员专属市场
 *
 *      注意事项：
 *      - updateMerkleRoot()缺少权限控制（生产环境应添加onlyOwner）
 *      - multicall使用delegatecall，需谨慎使用（可能导致存储冲突）
 *      - 白名单优惠每个地址只能使用一次
 */
contract AirdopMerkleNFTMarket is IERC1363Receiver {
    /// @notice 支付代币合约（支持EIP-2612 Permit）
    IERC20 public immutable paymentToken;

    /// @notice Merkle树根，用于验证白名单
    /// @dev 链下生成Merkle树，将root存储在合约中
    bytes32 public merkleRoot;

    /**
     * @notice NFT上架信息结构体
     * @param seller 卖家地址
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 售价（单位：paymentToken的最小单位）
     * @param isActive 是否有效（已售出或已取消则为false）
     */
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    /// @notice 上架信息映射：listingId => Listing
    mapping(uint256 => Listing) public listings;

    /// @notice 下一个上架ID（自增）
    uint256 public nextListingId;

    /// @notice 记录已经使用白名单优惠的地址（防止重复使用）
    mapping(address => bool) public hasUsedWhitelist;

    /// @notice NFT上架事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);

    /// @notice NFT售出事件
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    /// @notice 上架取消事件
    event NFTListingCancelled(uint256 indexed listingId);

    /// @notice 白名单用户购买事件
    event WhitelistNFTClaimed(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    /**
     * @notice 构造函数
     * @param _paymentTokenAddress 支付代币合约地址（必须支持EIP-2612 Permit）
     * @param _merkleRoot Merkle树根
     */
    constructor(address _paymentTokenAddress, bytes32 _merkleRoot) {
        require(_paymentTokenAddress != address(0), "AirdopMerkleNFTMarket: payment token address cannot be zero");
        paymentToken = IERC20(_paymentTokenAddress);
        merkleRoot = _merkleRoot;
    }

    // ===== 核心函数注释 =====

    /**
     * @notice 更新Merkle树根
     * @param _merkleRoot 新的Merkle树根
     * @dev ⚠️ 安全警告：此函数缺少权限控制，任何人都可以更新merkleRoot
     *      生产环境应添加onlyOwner修饰符
     *
     *      使用场景：
     *      - 白名单更新时需要部署新的Merkle树
     *      - 定期更新白名单（如新的活动参与者）
     *
     *      风险：
     *      - 攻击者可以设置自己的merkleRoot，从而通过验证
     *      - 必须确保此函数的访问控制
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external {
        // 在实际实现中应添加访问控制
        merkleRoot = _merkleRoot;
    }

    /**
     * @notice 验证地址是否在白名单中
     * @param user 要验证的地址
     * @param proof Merkle证明（从链下生成）
     * @return 是否在白名单中
     * @dev Merkle验证原理：
     *      1. 将user地址进行keccak256哈希，得到leaf
     *      2. 使用MerkleProof.verifyCalldata()验证proof
     *      3. 验证路径：从leaf沿着Merkle树向上到root
     *      4. 如果最终计算的root等于合约存储的merkleRoot，则验证通过
     *
     *      链下准备：
     *      1. 收集所有白名单地址
     *      2. 构建Merkle树（每层对子节点哈希）
     *      3. 计算root，部署时传入合约
     *      4. 用户申请proof（只需提供路径上的兄弟节点）
     */
    function isWhitelisted(address user, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verifyCalldata(proof, merkleRoot, leaf);
    }

    /**
     * @notice 上架NFT
     * @param _nftContract NFT合约地址
     * @param _tokenId NFT的ID
     * @param _price 售价
     * @return listingId 上架ID
     * @dev 执行流程：
     *      1. 检查价格和合约地址有效性
     *      2. 验证调用者是NFT所有者或有授权
     *      3. 创建上架记录
     *      4. 触发NFTListed事件
     *
     *      权限检查：
     *      - msg.sender是NFT所有者
     *      - 或者NFT所有者授权了msg.sender（isApprovedForAll）
     *      - 或者NFT单独授权了msg.sender（getApproved）
     */
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "AirdopMerkleNFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "AirdopMerkleNFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender ||
            nftContract.isApprovedForAll(owner, msg.sender) ||
            nftContract.getApproved(_tokenId) == msg.sender,
            "AirdopMerkleNFTMarket: caller is not owner nor approved"
        );

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
        return listingId;
    }

    /**
     * @notice 取消上架
     * @param _listingId 上架ID
     * @dev 权限检查：
     *      - 上架必须处于active状态
     *      - 只有卖家可以取消
     */
    function cancelListing(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(listing.seller == msg.sender, "AirdopMerkleNFTMarket: caller is not the seller");

        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }

    /**
     * @notice 购买NFT（普通方式）
     * @param _listingId 上架ID
     * @dev 执行流程：
     *      1. 验证上架状态
     *      2. 验证买家代币余额
     *      3. 标记上架为非活跃
     *      4. 转移代币给卖家
     *      5. 转移NFT给买家
     */
    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "AirdopMerkleNFTMarket: insufficient token balance");

        listing.isActive = false;

        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    /**
     * @notice ERC-1363回调函数，支持代币直接转账购买NFT
     * @param operator 操作者地址
     * @param from 付款人地址
     * @param value 转账金额
     * @param data 附加数据（包含listingId）
     * @return 函数选择器
     * @dev 执行流程：
     *      1. 验证调用者是paymentToken合约
     *      2. 从data中解析listingId
     *      3. 验证上架状态和金额
     *      4. 转移代币和NFT
     *
     *      使用场景：
     *      - 用户调用token.transferAndCall(marketAddress, price, abi.encode(listingId))
     *      - 一笔交易完成转账+购买
     */
    function onTransferReceived(address operator, address from, uint256 value, bytes calldata data) external override returns (bytes4) {
        require(operator == address(paymentToken), "AirdopMerkleNFTMarket: caller is not the payment token contract");
        require(data.length == 32, "AirdopMerkleNFTMarket: invalid data length");

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage listing = listings[listingId];

        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(value == listing.price, "AirdopMerkleNFTMarket: incorrect payment amount");

        listing.isActive = false;

        require(paymentToken.transfer(listing.seller, value), "AirdopMerkleNFTMarket: token transfer to seller failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, value);
        return IERC1363Receiver.onTransferReceived.selector;
    }

    // ===== Multicall相关结构体和函数 =====

    /**
     * @notice 调用结构体，用于multicall
     * @param target 目标合约地址
     * @param callData 调用数据
     * @dev 使用delegatecall方式执行，允许在一次交易中执行多个函数
     *      这里是简化实现，生产环境建议使用OpenZeppelin的Multicall
     */
    struct Call {
        address target;
        bytes callData;
    }

    /**
     * @notice 批量调用函数（使用delegatecall）
     * @param calls Call结构体数组
     * @return results 每个调用的返回结果
     * @dev ⚠️ 重要警告：
     *      - 使用delegatecall执行外部函数，执行的代码在当前合约上下文中运行
     *      - 这意味着被调用的函数可以修改当前合约的状态变量
     *      - 如果target是恶意合约，可能导致存储冲突或资金被盗
     *
     *      正确使用方式：
     *      - 只调用可信的合约函数（如本合约的permitPrePay和claimNFT）
     *      - 避免调用未知合约
     *
     *      生产环境建议：
     *      - 使用OpenZeppelin的Multicall（使用call而非delegatecall）
     *      - 或者使用Multicall2合约
     */
    function multicall(Call[] memory calls) public returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.delegatecall(calls[i].callData);
            require(success, "AirdopMerkleNFTMarket: delegatecall failed");
            results[i] = result;
        }
        return results;
    }

    /**
     * @notice 预授权函数，用于multicall中
     * @param owner 代币所有者
     * @param spender 被授权者（本合约地址）
     * @param value 授权数量
     * @param deadline 签名有效期
     * @param v 签名v
     * @param r 签名r
     * @param s 签名s
     * @dev 此函数作为multicall的一部分被调用
     *      调用IERC20Permit的permit进行链下签名授权
     *
     *      Multicall使用场景：
     *      1. 用户签名permit授权
     *      2. 用户构造multicall调用：[permitPrePay, claimNFT]
     *      3. 一次交易完成授权+购买
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(paymentToken)).permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @notice 白名单用户claim NFT（使用优惠价格）
     * @param _listingId 上架ID
     * @param merkleProof Merkle证明
     * @dev 执行流程：
     *      1. 验证上架状态
     *      2. 验证用户在白名单中（Merkle Proof）
     *      3. 验证用户未使用过优惠
     *      4. 计算50%折扣价格
     *      5. 验证用户代币余额
     *      6. 标记已使用优惠
     *      7. 标记上架为非活跃
     *      8. 转移代币和NFT
     *
     *      优惠机制：
     *      - 价格 = 原价 / 2（50%折扣）
     *      - 每个地址只能使用一次
     *
     *      Multicall典型用法：
     *      multicall([
     *          Call({target: this, callData: abi.encodeCall(permitPrePay, (...))}),
     *          Call({target: this, callData: abi.encodeCall(claimNFT, (...))})
     *      ])
     */
    function claimNFT(uint256 _listingId, bytes32[] calldata merkleProof) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");

        // 验证用户是否在白名单中
        require(isWhitelisted(msg.sender, merkleProof), "AirdopMerkleNFTMarket: not in whitelist");
        require(!hasUsedWhitelist[msg.sender], "AirdopMerkleNFTMarket: whitelist discount already used");

        // 计算50%优惠后的价格
        uint256 discountedPrice = listing.price / 2;
        require(paymentToken.balanceOf(msg.sender) >= discountedPrice, "AirdopMerkleNFTMarket: insufficient token balance");

        // 标记该用户已使用白名单优惠
        hasUsedWhitelist[msg.sender] = true;
        listing.isActive = false;

        // 转移代币和NFT
        require(paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit WhitelistNFTClaimed(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, discountedPrice);
    }
}