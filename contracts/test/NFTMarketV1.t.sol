// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";

/**
 * @title MockERC1363
 * @notice 模拟支持 transferAndCall 的 ERC1363 代币
 * @dev 用于测试 NFT 市场的 ERC1363 购买功能
 *
 * 功能：
 * - 支持标准 ERC20 功能
 * - 支持 ERC1363 的 transferAndCall 功能
 * - 构造时铸造 100 万代币给部署者
 */
contract MockERC1363 is ERC1363 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // 初始铸造一些代币给部署者
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

/**
 * @title MockNFT
 * @notice 模拟 NFT (ERC721) 合约
 * @dev 用于测试 NFT 市场的上架和购买功能
 *
 * 功能：
 * - 支持标准 ERC721 功能
 * - 提供公开的 mint 函数，方便测试
 */
contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MockNFT") {
    }

    /// @notice 铸造 NFT（无权限控制，仅用于测试）
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

/**
 * @title NFTMarketV1Test
 * @notice NFT 市场 V1 版本的完整测试套件
 * @dev 测试覆盖：
 * - 初始化测试（3个）
 * - 上架功能测试（6个）
 * - 购买功能测试（6个）
 * - 取消上架测试（4个）
 * - ERC1363 购买测试（5个）
 * - 升级功能测试（8个）
 *
 * 测试策略：
 * - 正常流程测试：验证功能正常工作
 * - 边界条件测试：验证参数验证
 * - 权限测试：验证权限控制
 * - 状态测试：验证状态变化
 * - 事件测试：验证事件触发
 * - 升级测试：验证合约升级
 */
contract NFTMarketV1Test is Test {
    NFTMarketV1 public nftMarket; // NFT市场合约实例（代理合约）
    MockERC1363 public paymentToken; // 支付代币实例
    MockNFT public mockNFT; // 模拟NFT实例
    address public seller; // 卖家地址
    address public buyer; // 买家地址
    uint256 public constant TOKEN_ID = 1; // NFT的Token ID
    uint256 public constant PRICE = 100 ether; // NFT价格

    /**
     * @notice 测试初始化函数
     * @dev 执行流程：
     * 1. 创建测试账户（seller, buyer）
     * 2. 部署支付代币（100万代币给测试合约）
     * 3. 部署 NFT 市场（使用 UUPS 代理模式）
     * 4. 部署模拟 NFT 合约
     * 5. 铸造 NFT 给卖家
     * 6. 卖家授权市场合约转移 NFT
     * 7. 分配代币给卖家和买家
     *
     * 初始状态：
     * - 测试合约：990,000 代币
     * - 卖家：9,000 代币，拥有 NFT #1，已授权市场
     * - 买家：1,000 代币
     */
    function setUp() public {
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        // 部署模拟支付代币，向测试合约提供100万个代币
        paymentToken = new MockERC1363("Payment Token", "PTK");

        // 使用 UUPS 代理模式部署 NFT 市场
        // 1. 部署逻辑合约
        address impl = address(new NFTMarketV1());
        // 2. 编码初始化调用数据
        bytes memory initCalldata = abi.encodeWithSelector(NFTMarketV1.initialize.selector, address(paymentToken));
        // 3. 部署代理合约并初始化
        address proxyAddr = address(new ERC1967Proxy(impl, initCalldata));
        // 4. 通过代理地址访问市场合约
        nftMarket = NFTMarketV1(proxyAddr);

        // 部署模拟NFT
        mockNFT = new MockNFT();

        // 铸造一个NFT给卖家
        vm.prank(seller);
        mockNFT.mint(seller, TOKEN_ID);

        // 批准NFT市场代表卖家转移NFT
        vm.prank(seller);
        mockNFT.approve(address(nftMarket), TOKEN_ID);

        // 先将代币转移给卖家，然后转移给买家
        paymentToken.transfer(seller, 10000 ether); // 给seller一些代币用于测试
        vm.prank(seller);
        paymentToken.transfer(buyer, 1000 ether); // 再从seller转移给buyer
    }

    // ============ 初始化测试 ============

    /**
     * @notice 测试：使用有效的代币地址初始化合约
     * @dev 验证点：
     * - paymentToken 地址设置正确
     * - owner 设置为部署者（测试合约）
     */
    function testInitializeWithValidTokenAddress() public {
        // 部署新的合约实例用于测试初始化
        address newImpl = address(new NFTMarketV1());
        bytes memory newInit = abi.encodeWithSelector(NFTMarketV1.initialize.selector, address(paymentToken));
        address newProxy = address(new ERC1967Proxy(newImpl, newInit));
        NFTMarketV1 newNFTMarket = NFTMarketV1(newProxy);
        // 验证合约已正确初始化
        assertEq(address(newNFTMarket.paymentToken()), address(paymentToken));
        assertEq(newNFTMarket.owner(), address(this)); // setUp函数中调用，所以所有者是测试合约
    }

    /**
     * @notice 测试：使用零地址初始化合约应该失败
     * @dev 验证点：
     * - 零地址验证生效
     * - 返回正确的错误信息
     */
    function testInitializeWithZeroAddressFails() public {
        address newImpl = address(new NFTMarketV1());
        bytes memory newInit = abi.encodeWithSelector(NFTMarketV1.initialize.selector, address(0));
        vm.expectRevert("NFTMarket: payment token address cannot be zero");
        new ERC1967Proxy(newImpl, newInit);
    }

    /**
     * @notice 测试：初始化函数只能调用一次
     * @dev 验证点：
     * - initializer 修饰器生效
     * - 重复初始化会 revert
     */
    function testInitializeCanOnlyBeCalledOnce() public {
        // 已在setUp中初始化，再次调用应该失败
        vm.expectRevert();
        nftMarket.initialize(address(paymentToken));
    }

    // ============ 上架功能测试 ============

    /**
     * @notice 测试：成功上架有效的 NFT
     * @dev 验证点：
     * - 上架信息正确存储
     * - listingId 从 0 开始
     * - nextListingId 正确递增
     * - 所有字段值正确
     */

    function testListValidNFTSuccessfully() public {
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 验证上架信息是否正确
        (address sellerAddr, address nftContractAddr, uint256 tokenId, uint256 price, bool isActive) = nftMarket.listings(listingId);
        assertEq(sellerAddr, seller);
        assertEq(nftContractAddr, address(mockNFT));
        assertEq(tokenId, TOKEN_ID);
        assertEq(price, PRICE);
        assertTrue(isActive);

        // 验证nextListingId增加
        assertEq(nftMarket.nextListingId(), 1);
    }

    /// @notice 测试：价格为0时上架应该失败
    function testListWithZeroPriceReverts() public {
        vm.startPrank(seller);
        vm.expectRevert("NFTMarket: price must be greater than zero");
        nftMarket.list(address(mockNFT), TOKEN_ID, 0);
        vm.stopPrank();
    }

    /// @notice 测试：NFT合约地址为零地址时上架应该失败
    function testListWithZeroAddressReverts() public {
        vm.startPrank(seller);
        vm.expectRevert("NFTMarket: NFT contract address cannot be zero");
        nftMarket.list(address(0), TOKEN_ID, PRICE);
        vm.stopPrank();
    }

    /// @notice 测试：非所有者且未授权的地址上架应该失败
    function testListNonOwnedNFTReverts() public {
        address other = makeAddr("other");
        vm.prank(other);
        vm.expectRevert("NFTMarket: caller is not owner nor approved");
        nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
    }

    /// @notice 测试：listingId 正确递增（从0开始）
    function testListWithValidListingId() public {
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        assertEq(listingId, 0); // 第一个listing应该是ID 0

        mockNFT.mint(seller, TOKEN_ID + 1); // 铸造 tokenId = 2 给 seller
        mockNFT.approve(address(nftMarket), TOKEN_ID + 1);
        uint256 listingId2 = nftMarket.list(address(mockNFT), TOKEN_ID + 1, PRICE);
        assertEq(listingId2, 1); // 第二个listing应该是ID 1
        vm.stopPrank();
    }

    /// @notice 测试：上架时触发 NFTListed 事件
    function testListEmitsNFTListedEvent() public {
        vm.startPrank(seller);
        vm.expectEmit(true, true, true, true);
        emit NFTMarketV1.NFTListed(0, seller, address(mockNFT), TOKEN_ID, PRICE);
        nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();
    }

    // ============ 购买功能测试 ============

    /// @notice 测试：成功购买 NFT（验证状态、所有权、余额变化）

    function testBuyNFTSuccessfully() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 检查初始状态
        assertEq(mockNFT.ownerOf(TOKEN_ID), seller);
        assertEq(paymentToken.balanceOf(buyer), 1000 ether);

        // 买家购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), PRICE);
        nftMarket.buyNFT(listingId);
        vm.stopPrank();

        // 验证最终状态
        (, , , , bool isActive) = nftMarket.listings(listingId);
        assertFalse(isActive);
        assertEq(mockNFT.ownerOf(TOKEN_ID), buyer);
        assertEq(paymentToken.balanceOf(buyer), 1000 ether - PRICE);
        assertEq(paymentToken.balanceOf(seller), 9000 ether + PRICE);
    }

    /// @notice 测试：余额不足时购买应该失败
    function testBuyNFTWithInsufficientBalanceReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        address poorBuyer = makeAddr("poorBuyer");
        vm.prank(seller);
        paymentToken.transfer(poorBuyer, 10 ether); // 给买家很少的代币

        vm.prank(poorBuyer);
        vm.expectRevert("NFTMarket: insufficient token balance");
        nftMarket.buyNFT(listingId);
    }

    /// @notice 测试：购买已取消的上架应该失败
    function testBuyInactiveListingReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        nftMarket.cancelListing(listingId); // 取消上架
        vm.stopPrank();

        vm.prank(buyer);
        vm.expectRevert("NFTMarket: listing is not active");
        nftMarket.buyNFT(listingId);
    }

    /// @notice 测试：购买后 NFT 所有权正确转移
    function testBuyNFTChangesOwnership() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 验证购买前的所有者
        assertEq(mockNFT.ownerOf(TOKEN_ID), seller);

        // 买家购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), PRICE);
        nftMarket.buyNFT(listingId);
        vm.stopPrank();

        // 验证购买后的所有者
        assertEq(mockNFT.ownerOf(TOKEN_ID), buyer);
    }

    /// @notice 测试：购买后代币正确转移
    function testBuyNFTTransfersPayment() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        uint256 buyerInitialBalance = paymentToken.balanceOf(buyer);
        uint256 sellerInitialBalance = paymentToken.balanceOf(seller);

        // 买家购买NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), PRICE);
        nftMarket.buyNFT(listingId);
        vm.stopPrank();

        // 验证代币转移
        assertEq(paymentToken.balanceOf(buyer), buyerInitialBalance - PRICE);
        assertEq(paymentToken.balanceOf(seller), sellerInitialBalance + PRICE);
    }

    /// @notice 测试：购买时触发 NFTSold 事件
    function testBuyNFTEmitsNFTSoldEvent() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        vm.startPrank(buyer);
        paymentToken.approve(address(nftMarket), PRICE);
        vm.expectEmit(true, true, true, true);
        emit NFTMarketV1.NFTSold(listingId, buyer, seller, address(mockNFT), TOKEN_ID, PRICE);
        nftMarket.buyNFT(listingId);
        vm.stopPrank();
    }

    // ============ 取消上架测试 ============

    /// @notice 测试：成功取消上架

    function testCancelListingSuccessfully() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 验证上架是活跃的
        (, , , , bool isActive) = nftMarket.listings(listingId);
        assertTrue(isActive);

        // 卖家取消上架
        vm.startPrank(seller);
        nftMarket.cancelListing(listingId);
        vm.stopPrank();

        // 验证上架已取消
        (,,,, isActive) = nftMarket.listings(listingId);
        assertFalse(isActive);
    }

    /// @notice 测试：取消已取消的上架应该失败
    function testCancelInactiveListingReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        nftMarket.cancelListing(listingId); // 先取消
        vm.stopPrank();

        // 尝试再次取消，应该失败
        vm.prank(seller);
        vm.expectRevert("NFTMarket: listing is not active");
        nftMarket.cancelListing(listingId);
    }

    /// @notice 测试：非卖家取消上架应该失败
    function testCancelNotSellerReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 非卖家尝试取消，应该失败
        vm.prank(buyer);
        vm.expectRevert("NFTMarket: caller is not the seller");
        nftMarket.cancelListing(listingId);
    }

    /// @notice 测试：取消上架时触发 NFTListingCancelled 事件
    function testCancelListingEmitsNFTListingCancelledEvent() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectEmit(true, true, false, false);
        emit NFTMarketV1.NFTListingCancelled(listingId);
        nftMarket.cancelListing(listingId);
        vm.stopPrank();
    }

    // ============ ERC1363 购买测试 ============

    /// @notice 测试：使用 transferAndCall 成功购买 NFT（一步完成）

    function testOnTransferReceivedSuccessfulPurchase() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 验证初始状态
        assertEq(mockNFT.ownerOf(TOKEN_ID), seller);
        assertEq(paymentToken.balanceOf(buyer), 1000 ether);

        // 买家通过transferAndCall购买NFT（触发onTransferReceived回调）
        vm.startPrank(buyer);
        bytes memory data = abi.encode(listingId);
        paymentToken.transferAndCall(address(nftMarket), PRICE, data);
        vm.stopPrank();

        // 验证最终状态
        (, , , , bool isActive) = nftMarket.listings(listingId);
        assertFalse(isActive);
        assertEq(mockNFT.ownerOf(TOKEN_ID), buyer);
        assertEq(paymentToken.balanceOf(buyer), 1000 ether - PRICE);
        assertEq(paymentToken.balanceOf(seller), 9000 ether + PRICE);
    }

    /// @notice 测试：支付金额不正确时应该失败
    function testOnTransferReceivedWithWrongAmountReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 尝试用错误的金额购买
        vm.startPrank(buyer);
        bytes memory data = abi.encode(listingId);
        vm.expectRevert("NFTMarket: incorrect payment amount");
        paymentToken.transferAndCall(address(nftMarket), PRICE - 1, data); // 金额少1
        vm.stopPrank();
    }

    /// @notice 测试：数据长度不正确时应该失败（必须是32字节）
    function testOnTransferReceivedWithInvalidDataReverts() public {
        // 上架NFT
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 尝试使用无效的数据长度
        vm.startPrank(buyer);
        bytes memory invalidData = abi.encodePacked(uint128(listingId)); // 只有16字节，不是32字节
        vm.expectRevert("NFTMarket: invalid data length");
        paymentToken.transferAndCall(address(nftMarket), PRICE, invalidData);
        vm.stopPrank();
    }

    /// @notice 测试：使用不存在的 listingId 应该失败
    function testOnTransferReceivedWithInvalidListingReverts() public {
        // 使用一个不存在的listing ID
        vm.startPrank(buyer);
        bytes memory data = abi.encode(uint256(999)); // 不存在的listing ID
        vm.expectRevert("onTransferReceived: listing is not active");
        paymentToken.transferAndCall(address(nftMarket), PRICE, data);
        vm.stopPrank();
    }

    /// @notice 测试：只有支付代币合约可以调用 onTransferReceived
    function testOnTransferReceivedOnlyByPaymentToken() public {
        // 创建另一个代币合约
        MockERC1363 otherToken = new MockERC1363("Other Token", "OTK");
        vm.deal(address(otherToken), 1000 ether);

        // 尝试从非支付代币调用onTransferReceived
        vm.startPrank(buyer);
        bytes memory data = abi.encode(uint256(0));
        vm.expectRevert();
        otherToken.transferAndCall(address(nftMarket), PRICE, data);
        vm.stopPrank();
    }

    // ============ 升级功能测试 ============

    /// @notice 测试：owner 可以升级合约

    function testOwnerCanUpgradeContract() public {
        NFTMarketV2 nftMarketV2 = new NFTMarketV2();

        vm.startPrank(address(this)); // 测试合约是所有者
        nftMarket.upgradeToAndCall(address(nftMarketV2), "");
        vm.stopPrank();

        // 验证升级后合约可访问
        NFTMarketV2 upgradedMarket = NFTMarketV2(address(nftMarket));
        assertEq(address(upgradedMarket.paymentToken()), address(paymentToken));
    }

    /// @notice 测试：非 owner 不能升级合约
    function testNonOwnerCannotUpgradeContract() public {
        NFTMarketV2 nftMarketV2 = new NFTMarketV2();
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert();
        nftMarket.upgradeToAndCall(address(nftMarketV2), "");
    }

    /// @notice 测试：升级后原有功能仍然可用
    function testExistingFunctionalityAfterUpgrade() public {
        // 首先做一些操作
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 升级合约
        NFTMarketV2 nftMarketV2 = new NFTMarketV2();

        vm.prank(address(this)); // 测试合约是所有者
        nftMarket.upgradeToAndCall(address(nftMarketV2), "");

        // 验证升级后功能
        NFTMarketV2 upgradedMarket = NFTMarketV2(address(nftMarket));
        assertEq(address(upgradedMarket.paymentToken()), address(paymentToken));

        // 验证原有上架信息仍然存在
        (address sellerAddr, address nftContractAddr, uint256 tokenId, uint256 price, bool isActive) =
                            upgradedMarket.listings(listingId);
        assertEq(sellerAddr, seller);
        assertEq(nftContractAddr, address(mockNFT));
        assertEq(tokenId, TOKEN_ID);
        assertEq(price, PRICE);
        assertTrue(isActive);
    }

    /// @notice 测试：升级时可以传递初始化数据
    function testUpgradeContractWithCallData() public {
        NFTMarketV2 nftMarketV2 = new NFTMarketV2();

        // 准备调用新合约的初始化函数
        // 对于NFTMarketV2，我们不需要特殊的初始化数据，所以传递空数据
        bytes memory callData = "";

        vm.prank(address(this)); // 测试合约是所有者
        nftMarket.upgradeToAndCall(address(nftMarketV2), callData);

        NFTMarketV2 upgradedMarket = NFTMarketV2(address(nftMarket));
        assertEq(address(upgradedMarket.paymentToken()), address(paymentToken));
    }

    /// @notice 测试：升级到非 UUPS 兼容合约应该失败
    function testUpgradeToFailsWithNonUUPSContract() public {
        // 创建一个非UUPS兼容的合约
        MockNFT nonUUPSContract = new MockNFT();

        vm.prank(address(this)); // 测试合约是所有者
        vm.expectRevert();
        nftMarket.upgradeToAndCall(address(nonUUPSContract), "");
    }

    /// @notice 测试：升级后合约状态保持不变
    function testContractStatePreservedAfterUpgrade() public {
        // 在升级前设置一些状态
        vm.startPrank(seller);
        uint256 listingId = nftMarket.list(address(mockNFT), TOKEN_ID, PRICE);
        vm.stopPrank();

        // 记录升级前的状态
        assertEq(nftMarket.nextListingId(), 1);

        NFTMarketV2 nftMarketV2 = new NFTMarketV2();

        vm.prank(address(this)); // 测试合约是所有者
        nftMarket.upgradeToAndCall(address(nftMarketV2), "");

        // 验证升级后的状态
        NFTMarketV2 upgradedMarket = NFTMarketV2(address(nftMarket));
        assertEq(upgradedMarket.nextListingId(), 1);

        // 验证上架信息仍然存在
        (, , , , bool isActive) = upgradedMarket.listings(listingId);
        assertTrue(isActive);
    }

    /// @notice 测试：升级后 owner 权限保持不变
    function testOwnerPermissionsMaintainedAfterUpgrade() public {
        NFTMarketV2 nftMarketV2 = new NFTMarketV2();

        vm.prank(address(this)); // 测试合约是所有者
        nftMarket.upgradeToAndCall(address(nftMarketV2), "");

        NFTMarketV2 upgradedMarket = NFTMarketV2(address(nftMarket));

        // 验证原所有者仍可调用仅限所有者的函数（升级功能）
        NFTMarketV2 anotherVersion = new NFTMarketV2();
        vm.prank(address(this)); // 测试合约是所有者
        upgradedMarket.upgradeToAndCall(address(anotherVersion), "");

        // 验证非所有者不能调用升级函数
        address notOwner = makeAddr("notOwner");
        NFTMarketV2 failVersion = new NFTMarketV2();
        vm.prank(notOwner);
        vm.expectRevert();
        upgradedMarket.upgradeToAndCall(address(failVersion), "");
    }
}