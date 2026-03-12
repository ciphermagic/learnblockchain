// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/AirdopMerkleNFTMarket.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";

/**
 * @title MockPaymentToken
 * @notice 模拟支付代币合约（支持ERC20、ERC20Permit、ERC1363）
 * @dev 用于测试AirdopMerkleNFTMarket合约
 */
contract MockPaymentToken is ERC20, ERC20Permit, ERC1363 {
    constructor()
    ERC20("MockPaymentToken", "MockPaymentToken")
    ERC20Permit("MockPaymentToken") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/**
 * @title MockNFT
 * @notice 模拟NFT合约
 * @dev 用于测试AirdopMerkleNFTMarket合约
 */
contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MockNFT") {}
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

/**
 * @title AirdopMerkleNFTMarketTest
 * @notice AirdopMerkleNFTMarket合约的测试套件
 * @dev 测试覆盖：上架、购买、白名单验证、Mercle证明、multicall等
 */
contract AirdopMerkleNFTMarketTest is Test {

    AirdopMerkleNFTMarket public market; // NFT市场合约实例
    MockPaymentToken public paymentToken; // 支付代币实例
    MockNFT public nftContract; // 模拟NFT实例

    address public seller = makeAddr("seller"); // 卖家地址
    address public buyer = makeAddr("buyer"); // 买家地址
    address public nonWhitelistedBuyer = makeAddr("nonWhitelistedBuyer");
    address public whitelistedBuyer;

    uint256 public constant tokenId = 1; // NFT的Token ID
    uint256 public constant price = 100 ether; // NFT价格

    // 为测试准备的Merkle树根和证明
    bytes32 public merkleRoot;
    bytes32[] public whitelistProof;

    /**
     * @notice 测试前置设置
     * @dev 部署模拟合约、设置白名单、分配测试代币
     */
    function setUp() public {

        // 部署模拟代币合约
        paymentToken = new MockPaymentToken();
        nftContract = new MockNFT();

        // 创建Merkle树根和证明，see: ../scripts/generate_merkle_tree.js
        whitelistedBuyer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        merkleRoot = 0x75f8fe6ccad6bd9cf7160214083ae8f5bfa17653fc2279cc3f0afc7e2b3cbd4e;
        whitelistProof = new bytes32[](1);
        whitelistProof[0] = 0x70b8e8088ae556faa07c4b4c972240935971ff7249949faf0cc1648dff84055b;

        // 部署NFT市场合约
        market = new AirdopMerkleNFTMarket(address(paymentToken), merkleRoot);

        // 为测试账户铸造NFT和代币
        nftContract.mint(seller, tokenId);
        paymentToken.mint(buyer, 1000 * 10 ** 18); // 1000 tokens
        paymentToken.mint(whitelistedBuyer, 1000 * 10 ** 18); // 1000 tokens
        paymentToken.mint(nonWhitelistedBuyer, 1000 * 10 ** 18); // 1000 tokens
    }

    /**
     * @notice 测试上架NFT成功
     * @dev 验证seller可以成功上架NFT，上架信息正确存储
     */
    function testListNFTSuccess() public {
        vm.startPrank(seller);

        vm.expectEmit();
        emit AirdopMerkleNFTMarket.NFTListed(0, seller, address(nftContract), tokenId, price);

        uint256 listingId = market.list(address(nftContract), tokenId, price);

        (address listedSeller, address listedNftContract, uint256 listedTokenId, uint256 listedPrice, bool isActive) = market.listings(listingId);
        assertEq(listedSeller, seller);
        assertEq(listedNftContract, address(nftContract));
        assertEq(listedTokenId, tokenId);
        assertEq(listedPrice, price);
        assertTrue(isActive);

        vm.stopPrank();
    }

    /**
     * @notice 测试普通购买NFT成功
     * @dev 验证buyer可以购买NFT，代币和NFT所有权正确转移
     */
    function testBuyNFTSuccess() public {
        // 先上架NFT
        vm.startPrank(seller);
        uint256 listingId = market.list(address(nftContract), tokenId, price);
        nftContract.approve(address(market), tokenId);
        vm.stopPrank();

        // 买家授权市场合约转移代币并购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(market), price);

        vm.expectEmit();
        emit AirdopMerkleNFTMarket.NFTSold(listingId, buyer, seller, address(nftContract), tokenId, price);

        market.buyNFT(listingId);

        // 验证NFT所有权已转移
        assertEq(nftContract.ownerOf(tokenId), buyer);

        // 验证代币已转移
        assertEq(paymentToken.balanceOf(seller), price);

        // 验证上架信息已更新为非活跃
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);

        vm.stopPrank();
    }

    /**
     * @notice 测试白名单验证功能
     * @dev 验证Merkle树验证机制正确工作
     */
    function testIsWhitelisted() public view {
        // 验证白名单用户
        assertTrue(market.isWhitelisted(whitelistedBuyer, whitelistProof));

        // 验证非白名单用户
        bytes32[] memory emptyProof = new bytes32[](0);
        assertFalse(market.isWhitelisted(nonWhitelistedBuyer, emptyProof));
    }

    /**
     * @notice 测试白名单用户优惠购买NFT成功
     * @dev 验证白名单用户享受50%折扣购买，hasUsedWhitelist标记正确
     */
    function testClaimNFTSuccess() public {
        // 先上架NFT
        vm.startPrank(seller);
        uint256 listingId = market.list(address(nftContract), tokenId, price);
        nftContract.approve(address(market), tokenId);
        vm.stopPrank();

        // 白名单用户授权市场合约转移代币并购买NFT
        vm.startPrank(whitelistedBuyer);
        uint256 discountedPrice = price / 2; // 50%优惠
        paymentToken.approve(address(market), discountedPrice);

        vm.expectEmit();
        emit AirdopMerkleNFTMarket.WhitelistNFTClaimed(listingId, whitelistedBuyer, seller, address(nftContract), tokenId, discountedPrice);

        market.claimNFT(listingId, whitelistProof);

        // 验证NFT所有权已转移
        assertEq(nftContract.ownerOf(tokenId), whitelistedBuyer);

        // 验证代币已转移（优惠价格）
        assertEq(paymentToken.balanceOf(seller), discountedPrice);

        // 验证上架信息已更新为非活跃
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);

        // 验证用户已被标记为使用过白名单
        assertTrue(market.hasUsedWhitelist(whitelistedBuyer));

        vm.stopPrank();
    }

    /**
     * @notice 测试非白名单用户优惠购买失败
     * @dev 验证非白名单用户无法使用claimNFT
     */
    function testClaimNFTFailureNotWhitelisted() public {
        // 先上架NFT
        vm.startPrank(seller);
        uint256 listingId = market.list(address(nftContract), tokenId, price);
        nftContract.approve(address(market), tokenId);
        vm.stopPrank();

        // 非白名单用户尝试购买NFT
        vm.startPrank(nonWhitelistedBuyer);
        uint256 discountedPrice = price / 2; // 50%优惠
        paymentToken.approve(address(market), discountedPrice);

        bytes32[] memory emptyProof = new bytes32[](0);
        vm.expectRevert("AirdopMerkleNFTMarket: not in whitelist");
        market.claimNFT(listingId, emptyProof);

        vm.stopPrank();
    }

    /**
     * @notice 测试白名单用户重复使用优惠失败
     * @dev 验证防重复使用机制，每人只能使用一次优惠
     */
    function testClaimNFTFailureAlreadyUsed() public {
        // 先上架两个NFT
        vm.startPrank(seller);
        uint256 listingId1 = market.list(address(nftContract), tokenId, price);
        nftContract.approve(address(market), tokenId);

        uint256 tokenId2 = 2;
        nftContract.mint(seller, tokenId2);
        uint256 listingId2 = market.list(address(nftContract), tokenId2, price);
        nftContract.approve(address(market), tokenId2);
        vm.stopPrank();

        // 白名单用户第一次使用优惠购买NFT
        vm.startPrank(whitelistedBuyer);
        uint256 discountedPrice = price / 2; // 50%优惠
        paymentToken.approve(address(market), discountedPrice);
        market.claimNFT(listingId1, whitelistProof);

        // 尝试第二次使用优惠购买NFT
        vm.expectRevert("AirdopMerkleNFTMarket: whitelist discount already used");
        market.claimNFT(listingId2, whitelistProof);

        vm.stopPrank();
    }

    /**
     * @notice 测试multicall组合调用permitPrePay和claimNFT
     * @dev 验证EIP-2612签名和multicall批量调用正确工作
     */
    function testMulticallPermitAndClaim() public {
        // 先上架NFT
        vm.startPrank(seller);
        uint256 listingId = market.list(address(nftContract), tokenId, price);
        nftContract.approve(address(market), tokenId);
        vm.stopPrank();

        // 准备白名单用户的permit签名
        vm.startPrank(whitelistedBuyer);
        uint256 discountedPrice = price / 2; // 50%优惠
        uint256 buyerNonce = paymentToken.nonces(whitelistedBuyer); // 获取当前 nonce
        uint256 deadline = block.timestamp + 1 hours;

        // 构造 EIP-2612 标准的 digest
        bytes32 permitTypeHash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypeHash, whitelistedBuyer, address(market), discountedPrice, buyerNonce, deadline));
        bytes32 domainSeparator = paymentToken.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // 执行签名
        uint256 whitelistedBuyerPK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedBuyerPK, digest);

        // 准备multicall调用
        AirdopMerkleNFTMarket.Call[] memory calls = new AirdopMerkleNFTMarket.Call[](2);

        // 第一个调用：permitPrePay
        calls[0].target = address(market);
        calls[0].callData = abi.encodeWithSelector(
            market.permitPrePay.selector,
            whitelistedBuyer,
            address(market),
            discountedPrice,
            deadline,
            v,
            r,
            s
        );

        // 第二个调用：claimNFT
        calls[1].target = address(market);
        calls[1].callData = abi.encodeWithSelector(
            market.claimNFT.selector,
            listingId,
            whitelistProof
        );

        // 验证multicall的结构
        assertEq(calls.length, 2);
        assertEq(calls[0].target, address(market));
        assertEq(calls[1].target, address(market));

        // 执行multicall
        market.multicall(calls);

        // 验证NFT所有权已转移
        assertEq(nftContract.ownerOf(tokenId), whitelistedBuyer);
        // 验证代币已转移（优惠价格）
        assertEq(paymentToken.balanceOf(seller), discountedPrice);
        // 验证上架信息已更新为非活跃
        (, , , , bool isActive) = market.listings(listingId);
        assertFalse(isActive);
        // 验证用户已被标记为使用过白名单
        assertTrue(market.hasUsedWhitelist(whitelistedBuyer));

        vm.stopPrank();
    }

    /**
     * @notice 测试更新Merkle根
     * @dev 验证updateMerkleRoot函数可以更新merkleRoot
     */
    function testUpdateMerkleRoot() public {
        bytes32 newMerkleRoot = keccak256(abi.encodePacked("new merkle root"));

        // 更新Merkle根
        market.updateMerkleRoot(newMerkleRoot);

        // 验证Merkle根已更新
        assertEq(market.merkleRoot(), newMerkleRoot);
    }

}