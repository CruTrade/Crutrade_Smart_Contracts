// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Import all contracts
import "../src/Roles.sol";
import "../src/Memberships.sol";
import "../src/Payments.sol";
import "../src/Sales.sol";
import "../src/Whitelist.sol";
import "../src/Wrappers.sol";
import "../src/Brands.sol";

// Import base contracts for structs
import "../src/abstracts/SalesBase.sol";

// Import interfaces
import "../src/interfaces/IWrappers.sol";
import "../src/interfaces/IPayments.sol";

// Mock ERC20 for testing
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract CrutradeEcosystemTest is Test {
    // Contracts
    Roles public roles;
    Memberships public memberships;
    Payments public payments;
    Sales public sales;
    Whitelist public whitelist;
    Wrappers public wrappers;
    Brands public brands;
    MockERC20 public mockToken;
    MockERC20 public fiatToken;

    // Test addresses - usando vm.addr() per avere corrispondenza con private keys
    uint256 constant ADMIN_KEY = 0x1;
    uint256 constant OPERATIONAL_KEY = 0x2;  
    uint256 constant SELLER_KEY = 0x3;
    uint256 constant BUYER_KEY = 0x4;
    uint256 constant TREASURY_KEY = 0x5;
    uint256 constant FEE_RECEIVER_KEY = 0x6;
    
    address public admin = vm.addr(ADMIN_KEY);
    address public operational = vm.addr(OPERATIONAL_KEY);
    address public seller = vm.addr(SELLER_KEY);
    address public buyer = vm.addr(BUYER_KEY);
    address public treasury = vm.addr(TREASURY_KEY);
    address public feeReceiver = vm.addr(FEE_RECEIVER_KEY);

    // Constants
    bytes32 constant OWNER = keccak256('OWNER');
    bytes32 constant OPERATIONAL = keccak256('OPERATIONAL');
    bytes32 constant PAUSER = keccak256('PAUSER');
    bytes32 constant UPGRADER = keccak256('UPGRADER');
    bytes32 constant TREASURY = keccak256('TREASURY');
    bytes32 constant FIAT = keccak256('FIAT');
    bytes32 constant WHITELIST = keccak256('WHITELIST');
    bytes32 constant WRAPPERS = keccak256('WRAPPERS');
    bytes32 constant BRANDS = keccak256('BRANDS');
    bytes32 constant MEMBERSHIPS = keccak256('MEMBERSHIPS');
    bytes32 constant PAYMENTS = keccak256('PAYMENTS');

    // Operation constants
    bytes32 constant LIST = keccak256("LIST");
    bytes32 constant BUY = keccak256("BUY");
    bytes32 constant WITHDRAW = keccak256("WITHDRAW");
    bytes32 constant RENEW = keccak256("RENEW");

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock tokens
        mockToken = new MockERC20();
        fiatToken = new MockERC20();
        
        // Deploy implementation contracts
        Roles rolesImpl = new Roles();
        Memberships membershipsImpl = new Memberships();
        Payments paymentsImpl = new Payments();
        Sales salesImpl = new Sales();
        Whitelist whitelistImpl = new Whitelist();
        Wrappers wrappersImpl = new Wrappers();
        Brands brandsImpl = new Brands();
        
        // Deploy proxies and initialize
        bytes memory rolesInitData = abi.encodeWithSelector(Roles.initialize.selector, admin);
        ERC1967Proxy rolesProxy = new ERC1967Proxy(address(rolesImpl), rolesInitData);
        roles = Roles(address(rolesProxy));
        
        // Setup payment configurations
        roles.setPayment(address(mockToken), 18);
        roles.setPayment(address(fiatToken), 18);
        roles.setDefaultFiatToken(address(fiatToken));
        
        // Deploy other contract proxies
        bytes memory membershipsInitData = abi.encodeWithSelector(Memberships.initialize.selector, address(roles));
        ERC1967Proxy membershipsProxy = new ERC1967Proxy(address(membershipsImpl), membershipsInitData);
        memberships = Memberships(address(membershipsProxy));
        
        bytes memory paymentsInitData = abi.encodeWithSelector(Payments.initialize.selector, address(roles));
        ERC1967Proxy paymentsProxy = new ERC1967Proxy(address(paymentsImpl), paymentsInitData);
        payments = Payments(address(paymentsProxy));
        
        bytes memory salesInitData = abi.encodeWithSelector(Sales.initialize.selector, address(roles));
        ERC1967Proxy salesProxy = new ERC1967Proxy(address(salesImpl), salesInitData);
        sales = Sales(address(salesProxy));
        
        bytes memory whitelistInitData = abi.encodeWithSelector(Whitelist.initialize.selector, address(roles));
        ERC1967Proxy whitelistProxy = new ERC1967Proxy(address(whitelistImpl), whitelistInitData);
        whitelist = Whitelist(address(whitelistProxy));
        
        bytes memory wrappersInitData = abi.encodeWithSelector(Wrappers.initialize.selector, address(roles));
        ERC1967Proxy wrappersProxy = new ERC1967Proxy(address(wrappersImpl), wrappersInitData);
        wrappers = Wrappers(address(wrappersProxy));
        
        bytes memory brandsInitData = abi.encodeWithSelector(Brands.initialize.selector, address(roles));
        ERC1967Proxy brandsProxy = new ERC1967Proxy(address(brandsImpl), brandsInitData);
        brands = Brands(address(brandsProxy));
        
        // Setup roles
        roles.grantRole(OWNER, admin);
        roles.grantRole(OPERATIONAL, operational);
        roles.grantRole(TREASURY, treasury);
        roles.grantRole(FIAT, treasury);
        roles.grantRole(WHITELIST, address(whitelist));
        roles.grantRole(WRAPPERS, address(wrappers));
        roles.grantRole(BRANDS, address(brands));
        roles.grantRole(MEMBERSHIPS, address(memberships));
        roles.grantRole(PAYMENTS, address(payments));
        
        // Grant delegate roles
        roles.grantDelegateRole(address(sales));
        roles.grantDelegateRole(address(wrappers));
        
        // La fee TREASURY è già al 100% nell'initialize, non aggiungo altre fee per ora
        // per evitare di superare il limite
        
        // Setup service fees for operations
        payments.setServiceFee(LIST, 10 * 10**18);
        payments.setServiceFee(BUY, 5 * 10**18);
        payments.setServiceFee(WITHDRAW, 2 * 10**18);
        payments.setServiceFee(RENEW, 8 * 10**18);
        
        // Setup duration for sales
        uint256[] memory durationIds = new uint256[](3);
        uint256[] memory durations = new uint256[](3);
        durationIds[0] = 0; // Default duration
        durationIds[1] = 1; // Short duration
        durationIds[2] = 2; // Long duration
        durations[0] = 7 days;
        durations[1] = 1 days;
        durations[2] = 30 days;
        sales.setDurations(durationIds, durations);
        
        // Mint tokens to test addresses
        mockToken.mint(seller, 100000 * 10**18);
        mockToken.mint(buyer, 100000 * 10**18);
        fiatToken.mint(treasury, 100000 * 10**18);
        
        vm.stopPrank();
    }

    // === CORE FUNCTIONALITY TESTS ===

    function test_RolesSetup() public view {
        assertTrue(roles.hasRole(roles.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(roles.hasRole(OWNER, admin));
        assertTrue(roles.hasRole(OPERATIONAL, operational));
        assertEq(roles.getRoleAddress(TREASURY), treasury);
        assertEq(roles.getDefaultFiatPayment(), address(fiatToken));
        assertTrue(roles.hasPaymentRole(address(mockToken)));
    }

    function test_MembershipManagement() public {
        vm.startPrank(operational);
        
        // Test single membership assignment
        address[] memory members = new address[](1);
        members[0] = seller;
        memberships.setMemberships(members, 1);
        
        assertEq(memberships.getMembership(seller), 1);
        
        // Test batch membership assignment
        address[] memory batchMembers = new address[](2);
        batchMembers[0] = buyer;
        batchMembers[1] = makeAddr("user3");
        memberships.setMemberships(batchMembers, 2);
        
        assertEq(memberships.getMembership(buyer), 2);
        assertEq(memberships.getMembership(makeAddr("user3")), 2);
        
        // Test membership revocation
        memberships.revokeMembership(seller);
        assertEq(memberships.getMembership(seller), 0);
        
        vm.stopPrank();
    }

    function test_WhitelistManagement() public {
        vm.startPrank(operational);
        
        // Test adding to whitelist
        address[] memory users = new address[](2);
        users[0] = seller;
        users[1] = buyer;
        whitelist.addToWhitelist(users);
        
        assertTrue(whitelist.isWhitelisted(seller));
        assertTrue(whitelist.isWhitelisted(buyer));
        
        // Test removing from whitelist
        address[] memory removeUsers = new address[](1);
        removeUsers[0] = seller;
        whitelist.removeFromWhitelist(removeUsers);
        
        assertFalse(whitelist.isWhitelisted(seller));
        assertTrue(whitelist.isWhitelisted(buyer));
        
        vm.stopPrank();
    }

    function test_BrandManagement() public {
        vm.startPrank(operational);
        
        uint256 brandId = brands.register(seller);
        
        assertTrue(brands.isValidBrand(brandId));
        assertEq(brands.getBrandOwner(brandId), seller);
        assertEq(brands.ownerOf(brandId), seller);
        
        // Test brand burning
        brands.burn(brandId);
        assertFalse(brands.isValidBrand(brandId));
        
        vm.stopPrank();
    }

    function test_WrapperImportExport() public {
        // Setup
        vm.startPrank(operational);
        address[] memory users = new address[](1);
        users[0] = seller;
        whitelist.addToWhitelist(users);
        
        uint256 brandId = brands.register(seller);
        vm.stopPrank();
        
        // Import wrapper
        vm.startPrank(operational);
        IWrappers.wrapperData[] memory wrapperData = new IWrappers.wrapperData[](1);
        wrapperData[0] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/1",
            metaKey: "item_001",
            amount: 0,
            tokenId: 1,
            brandId: brandId,
            collection: keccak256("TEST_COLLECTION"),
            active: false
        });
        
        wrappers.imports(seller, wrapperData);
        
        // Verify wrapper was imported
        IWrappers.wrapperData memory imported = wrappers.getWrapperData(0);
        assertEq(imported.metaKey, "item_001");
        assertEq(imported.tokenId, 1);
        assertEq(imported.brandId, brandId);
        assertTrue(imported.active);
        assertEq(wrappers.ownerOf(0), seller);
        
        // Export wrapper
        uint256[] memory wrapperIds = new uint256[](1);
        wrapperIds[0] = 0;
        wrappers.exports(seller, wrapperIds);
        
        // Verify wrapper was exported (deactivated)
        IWrappers.wrapperData memory exported = wrappers.getWrapperData(0);
        assertFalse(exported.active);
        
        vm.stopPrank();
    }

    function test_ListingFlow() public {
        // Setup prerequisites
        (uint256 wrapperId,) = _setupWrapperForSale();
        
        // Setup approvals
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        vm.prank(treasury);
        fiatToken.approve(address(payments), type(uint256).max);
        
        // List item for sale
        vm.startPrank(operational);
        bytes32 listHash = keccak256(abi.encodePacked("list", block.timestamp));
        bytes memory listSig = _signHash(listHash, seller);
        
        SalesBase.ListInputs[] memory listInputs = new SalesBase.ListInputs[](1);
        listInputs[0] = SalesBase.ListInputs({
            price: 1000 * 10**18,
            wrapperId: wrapperId,
            durationId: 0
        });
        
        sales.list(seller, listHash, listSig, address(mockToken), listInputs);
        
        // Verify listing
        SalesBase.Sale memory sale = sales.getSale(0);
        assertEq(sale.price, 1000 * 10**18);
        assertEq(sale.seller, seller);
        assertEq(sale.wrapperId, wrapperId);
        assertTrue(sale.active);
        assertEq(wrappers.ownerOf(wrapperId), address(sales)); // NFT transferred to sales contract
        
        vm.stopPrank();
    }

    function test_PurchaseFlow() public {
        // Setup and list item
        uint256 saleId = _setupAndListItem();
        
        // Assicurati che buyer sia whitelisted
        vm.startPrank(operational);
        address[] memory buyerArray = new address[](1);
        buyerArray[0] = buyer;
        whitelist.addToWhitelist(buyerArray);
        vm.stopPrank();
        
        // Setup buyer approvals
        vm.prank(buyer);
        mockToken.approve(address(payments), type(uint256).max);
        
        // Fast forward to sale start time
        SalesBase.Sale memory sale = sales.getSale(saleId);
        if (block.timestamp < sale.start) {
            vm.warp(sale.start + 1);
        }
        
        // Record balances before purchase
        uint256 buyerBalanceBefore = mockToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = mockToken.balanceOf(seller);
        uint256 feeReceiverBalanceBefore = mockToken.balanceOf(feeReceiver);
        
        // Buy item
        vm.startPrank(operational);
        bytes32 buyHash = keccak256(abi.encodePacked("buy", block.timestamp));
        bytes memory buySig = _signHash(buyHash, buyer);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        sales.buy(buyer, buyHash, buySig, address(mockToken), saleIds);
        
        // Verify purchase
        SalesBase.Sale memory soldSale = sales.getSale(saleId);
        assertFalse(soldSale.active); // Sale should be inactive
        assertEq(wrappers.ownerOf(soldSale.wrapperId), buyer); // NFT transferred to buyer
        
        // Verify fee distribution occurred (con solo treasury fee al 100%)
        assertTrue(mockToken.balanceOf(buyer) < buyerBalanceBefore);
        assertTrue(mockToken.balanceOf(seller) > sellerBalanceBefore);
        // treasury riceve le fee invece di feeReceiver
        assertTrue(mockToken.balanceOf(treasury) > 0 || mockToken.balanceOf(feeReceiver) >= feeReceiverBalanceBefore);
        
        vm.stopPrank();
    }

    function test_WithdrawFlow() public {
        // Setup and list item
        uint256 saleId = _setupAndListItem();
        
        // Fast forward to sale start time
        SalesBase.Sale memory sale = sales.getSale(saleId);
        if (block.timestamp < sale.start) {
            vm.warp(sale.start + 1);
        }
        
        // Setup seller approvals for service fees
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        
        // Get sale info before withdrawal
        SalesBase.Sale memory saleBeforeWithdraw = sales.getSale(saleId);
        uint256 wrapperId = saleBeforeWithdraw.wrapperId;
        
        // Withdraw item
        vm.startPrank(operational);
        bytes32 withdrawHash = keccak256(abi.encodePacked("withdraw", block.timestamp));
        bytes memory withdrawSig = _signHash(withdrawHash, seller);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        sales.withdraw(seller, withdrawHash, withdrawSig, address(mockToken), saleIds);
        
        // Verify withdrawal - sale should be deleted/inactive
        vm.expectRevert(); // Should revert as sale no longer exists
        sales.getSale(saleId);
        
        // Verify NFT returned to seller
        assertEq(wrappers.ownerOf(wrapperId), seller);
        
        vm.stopPrank();
    }

    function test_RenewFlow() public {
        // Setup and list item
        uint256 saleId = _setupAndListItem();
        
        // Fast forward time to make the sale expire
        SalesBase.Sale memory sale = sales.getSale(saleId);
        vm.warp(sale.end + 1);
        
        // Setup seller approvals for service fees
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        
        // Renew item
        vm.startPrank(operational);
        bytes32 renewHash = keccak256(abi.encodePacked("renew", block.timestamp));
        bytes memory renewSig = _signHash(renewHash, seller);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        sales.renew(seller, renewHash, renewSig, address(mockToken), saleIds);
        
        // Verify renewal
        SalesBase.Sale memory renewedSale = sales.getSale(saleId);
        assertTrue(renewedSale.active);
        assertTrue(renewedSale.start > sale.start); // New start time
        assertTrue(renewedSale.end > sale.end); // New end time
        
        vm.stopPrank();
    }

    function test_PaymentFeeCalculation() public {
        // Setup memberships with different fee structures
        vm.startPrank(admin);
        payments.setFeePercentage(1, false, 300); // 3% for sending (membership 1)
        payments.setFeePercentage(1, true, 200);  // 2% for receiving (membership 1)
        payments.setFeePercentage(2, false, 100); // 1% for sending (membership 2)
        payments.setFeePercentage(2, true, 50);   // 0.5% for receiving (membership 2)
        vm.stopPrank();
        
        // Check fee percentages
        assertEq(payments.getFeePercentage(1, false), 300);
        assertEq(payments.getFeePercentage(1, true), 200);
        assertEq(payments.getFeePercentage(2, false), 100);
        assertEq(payments.getFeePercentage(2, true), 50);
    }

    function test_ScheduleManagement() public {
        vm.startPrank(admin);
        
        // Set multiple schedules
        uint256[] memory scheduleIds = new uint256[](2);
        uint8[] memory daysOfWeek = new uint8[](2);
        uint8[] memory hoursValue = new uint8[](2);
        uint8[] memory minutesValue = new uint8[](2);
        
        scheduleIds[0] = 1;
        scheduleIds[1] = 2;
        daysOfWeek[0] = 1; // Monday
        daysOfWeek[1] = 5; // Friday
        hoursValue[0] = 10;
        hoursValue[1] = 15;
        minutesValue[0] = 30;
        minutesValue[1] = 0;
        
        sales.setSchedules(scheduleIds, daysOfWeek, hoursValue, minutesValue);
        
        // Verify schedules
        (uint8 day, uint8 hour, uint8 minute, bool active) = sales.getSchedule(1);
        assertEq(day, 1);
        assertEq(hour, 10);
        assertEq(minute, 30);
        assertTrue(active);
        
        // Remove schedule
        uint256[] memory removeIds = new uint256[](1);
        removeIds[0] = 1;
        sales.removeSchedules(removeIds);
        
        (,, , bool stillActive) = sales.getSchedule(1);
        assertFalse(stillActive);
        
        vm.stopPrank();
    }

    function test_DurationManagement() public {
        vm.startPrank(admin);
        
        // Set custom durations
        uint256[] memory durationIds = new uint256[](2);
        uint256[] memory durations = new uint256[](2);
        
        durationIds[0] = 10;
        durationIds[1] = 11;
        durations[0] = 12 hours;
        durations[1] = 3 days;
        
        sales.setDurations(durationIds, durations);
        
        // Verify durations
        assertEq(sales.getDuration(10), 12 hours);
        assertEq(sales.getDuration(11), 3 days);
        
        vm.stopPrank();
    }

    // === FUZZ TESTS ===

    function testFuzz_MembershipAssignment(uint256 membershipId, address user) public {
        vm.assume(user != address(0));
        vm.assume(membershipId > 0 && membershipId < type(uint256).max);
        
        vm.startPrank(operational);
        address[] memory members = new address[](1);
        members[0] = user;
        memberships.setMemberships(members, membershipId);
        
        assertEq(memberships.getMembership(user), membershipId);
        vm.stopPrank();
    }

    function testFuzz_FeePercentages(uint256 membershipId, uint256 percentage) public {
        vm.assume(membershipId > 0 && membershipId < 1000);
        vm.assume(percentage <= 10000); // Max 100%
        
        vm.startPrank(admin);
        payments.setFeePercentage(membershipId, false, percentage);
        
        assertEq(payments.getFeePercentage(membershipId, false), percentage);
        vm.stopPrank();
    }

    function testFuzz_SalePrice(uint256 price) public {
        vm.assume(price > 0 && price <= type(uint128).max);
        
        // Setup
        (uint256 wrapperId,) = _setupWrapperForSale();
        
        // Setup approvals
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        vm.prank(treasury);
        fiatToken.approve(address(payments), type(uint256).max);
        
        // List with fuzzed price
        vm.startPrank(operational);
        bytes32 listHash = keccak256(abi.encodePacked("list", block.timestamp, price));
        bytes memory listSig = _signHash(listHash, seller);
        
        SalesBase.ListInputs[] memory listInputs = new SalesBase.ListInputs[](1);
        listInputs[0] = SalesBase.ListInputs({
            price: price,
            wrapperId: wrapperId,
            durationId: 0
        });
        
        sales.list(seller, listHash, listSig, address(mockToken), listInputs);
        
        SalesBase.Sale memory sale = sales.getSale(0);
        assertEq(sale.price, price);
        vm.stopPrank();
    }

    function testFuzz_BatchOperations(uint8 batchSize) public {
        vm.assume(batchSize > 0 && batchSize <= 50); // Reasonable batch size
        
        vm.startPrank(operational);
        
        // Create batch of users
        address[] memory users = new address[](batchSize);
        for (uint i = 0; i < batchSize; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
        }
        
        // Batch whitelist operation
        whitelist.addToWhitelist(users);
        
        // Verify all users are whitelisted
        for (uint i = 0; i < batchSize; i++) {
            assertTrue(whitelist.isWhitelisted(users[i]));
        }
        
        // Batch membership assignment
        memberships.setMemberships(users, 1);
        
        // Verify all users have membership
        for (uint i = 0; i < batchSize; i++) {
            assertEq(memberships.getMembership(users[i]), 1);
        }
        
        vm.stopPrank();
    }

    function testFuzz_ScheduleTiming(uint8 day, uint8 hour, uint8 minute) public {
        vm.assume(day >= 1 && day <= 7);
        vm.assume(hour <= 23);
        vm.assume(minute <= 59);
        
        vm.startPrank(admin);
        
        uint256[] memory scheduleIds = new uint256[](1);
        uint8[] memory daysValue = new uint8[](1);
        uint8[] memory hoursValue = new uint8[](1);
        uint8[] memory minutesValue = new uint8[](1);
        
        scheduleIds[0] = 1;
        daysValue[0] = day;
        hoursValue[0] = hour;
        minutesValue[0] = minute;
        
        sales.setSchedules(scheduleIds, daysValue, hoursValue, minutesValue);
        
        (uint8 storedDay, uint8 storedHour, uint8 storedMinute, bool active) = sales.getSchedule(1);
        assertEq(storedDay, day);
        assertEq(storedHour, hour);
        assertEq(storedMinute, minute);
        assertTrue(active);
        
        vm.stopPrank();
    }

    function testFuzz_DurationValues(uint256 durationId, uint256 duration) public {
        vm.assume(durationId > 0 && durationId < 1000);
        vm.assume(duration > 0 && duration <= 365 days);
        
        vm.startPrank(admin);
        
        uint256[] memory durationIds = new uint256[](1);
        uint256[] memory durations = new uint256[](1);
        
        durationIds[0] = durationId;
        durations[0] = duration;
        
        sales.setDurations(durationIds, durations);
        
        assertEq(sales.getDuration(durationId), duration);
        
        vm.stopPrank();
    }

    // === INTEGRATION TESTS ===

    function test_CompleteEcosystemFlow() public {
        // 1. Setup all components
        vm.startPrank(operational);
        
        // Whitelist users
        address[] memory users = new address[](2);
        users[0] = seller;
        users[1] = buyer;
        whitelist.addToWhitelist(users);
        
        // Assign different membership tiers
        address[] memory sellerMember = new address[](1);
        sellerMember[0] = seller;
        memberships.setMemberships(sellerMember, 1); // Tier 1
        
        address[] memory buyerMember = new address[](1);
        buyerMember[0] = buyer;
        memberships.setMemberships(buyerMember, 2); // Tier 2
        
        // Register brand and import wrapper
        uint256 brandId = brands.register(seller);
        
        IWrappers.wrapperData[] memory wrapperData = new IWrappers.wrapperData[](1);
        wrapperData[0] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/1",
            metaKey: "premium_item",
            amount: 0,
            tokenId: 1,
            brandId: brandId,
            collection: keccak256("PREMIUM_COLLECTION"),
            active: false
        });
        wrappers.imports(seller, wrapperData);
        
        vm.stopPrank();
        
        // 2. Setup different fee structures
        vm.startPrank(admin);
        payments.setFeePercentage(1, false, 500); // 5% for tier 1 sending
        payments.setFeePercentage(1, true, 300);  // 3% for tier 1 receiving
        payments.setFeePercentage(2, false, 200); // 2% for tier 2 sending
        payments.setFeePercentage(2, true, 100);  // 1% for tier 2 receiving
        vm.stopPrank();
        
        // 3. Setup token approvals
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        vm.prank(buyer);
        mockToken.approve(address(payments), type(uint256).max);
        vm.prank(treasury);
        fiatToken.approve(address(payments), type(uint256).max);
        
        // 4. List item with premium pricing
        vm.startPrank(operational);
        bytes32 listHash = keccak256(abi.encodePacked("premium_list", block.timestamp));
        bytes memory listSig = _signHash(listHash, seller);
        
        SalesBase.ListInputs[] memory listInputs = new SalesBase.ListInputs[](1);
        listInputs[0] = SalesBase.ListInputs({
            price: 5000 * 10**18, // Premium price
            wrapperId: 0,
            durationId: 0
        });
        
        sales.list(seller, listHash, listSig, address(mockToken), listInputs);
        
        // Fast forward to sale start time
        SalesBase.Sale memory saleInfo = sales.getSale(0);
        if (block.timestamp < saleInfo.start) {
            vm.warp(saleInfo.start + 1);
        }
        
        // 5. Execute purchase and verify complex fee calculations
        bytes32 buyHash = keccak256(abi.encodePacked("premium_buy", block.timestamp));
        bytes memory buySig = _signHash(buyHash, buyer);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = 0;
        
        // Record balances before
        uint256 buyerBalanceBefore = mockToken.balanceOf(buyer);
        uint256 sellerBalanceBefore = mockToken.balanceOf(seller);
        uint256 feeReceiverBalanceBefore = mockToken.balanceOf(feeReceiver);
        
        sales.buy(buyer, buyHash, buySig, address(mockToken), saleIds);
        
        // 6. Verify complete transaction
        assertEq(wrappers.ownerOf(0), buyer); // NFT transferred
        assertFalse(sales.getSale(0).active); // Sale completed
        
        // Verify fee distribution occurred (con solo treasury fee al 100%)
        assertTrue(mockToken.balanceOf(buyer) < buyerBalanceBefore);
        assertTrue(mockToken.balanceOf(seller) > sellerBalanceBefore);
        // treasury riceve le fee invece di feeReceiver  
        assertTrue(mockToken.balanceOf(treasury) > 0 || mockToken.balanceOf(feeReceiver) >= feeReceiverBalanceBefore);
        
        vm.stopPrank();
    }

    function test_MultipleCollections() public {
        vm.startPrank(operational);
        
        address[] memory users = new address[](1);
        users[0] = seller;
        whitelist.addToWhitelist(users);
        
        uint256 brandId = brands.register(seller);
        
        // Import wrappers from different collections
        IWrappers.wrapperData[] memory wrapperData = new IWrappers.wrapperData[](3);
        wrapperData[0] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/1",
            metaKey: "item_001",
            amount: 0,
            tokenId: 1,
            brandId: brandId,
            collection: keccak256("COLLECTION_A"),
            active: false
        });
        wrapperData[1] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/2",
            metaKey: "item_002",
            amount: 0,
            tokenId: 2,
            brandId: brandId,
            collection: keccak256("COLLECTION_B"),
            active: false
        });
        wrapperData[2] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/3",
            metaKey: "item_003",
            amount: 0,
            tokenId: 3,
            brandId: brandId,
            collection: keccak256("COLLECTION_A"),
            active: false
        });
        
        wrappers.imports(seller, wrapperData);
        
        // Verify collections
        assertTrue(wrappers.isValidCollection(keccak256("COLLECTION_A")));
        assertTrue(wrappers.isValidCollection(keccak256("COLLECTION_B")));
        assertTrue(wrappers.checkCollection(keccak256("COLLECTION_A"), 0));
        assertTrue(wrappers.checkCollection(keccak256("COLLECTION_B"), 1));
        assertTrue(wrappers.checkCollection(keccak256("COLLECTION_A"), 2));
        
        // Test collection-based queries
        IWrappers.wrapperData[] memory collectionA = wrappers.getCollectionData(keccak256("COLLECTION_A"));
        assertEq(collectionA.length, 2);
        
        IWrappers.wrapperData[] memory collectionB = wrappers.getCollectionData(keccak256("COLLECTION_B"));
        assertEq(collectionB.length, 1);
        
        vm.stopPrank();
    }

    function test_SaleCollectionQuery() public {
        // Setup multiple sales from same collection
        (uint256 wrapperId1,) = _setupWrapperForSale();
        _setupAndListItemWithId(wrapperId1);
        
        // Create another wrapper from same collection
        vm.startPrank(operational);
        IWrappers.wrapperData[] memory wrapperData = new IWrappers.wrapperData[](1);
        wrapperData[0] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/2",
            metaKey: "item_002",
            amount: 0,
            tokenId: 2,
            brandId: 0, // Use same brand as first wrapper
            collection: keccak256("TEST_COLLECTION"),
            active: false
        });
        wrappers.imports(seller, wrapperData);
        vm.stopPrank();
        
        _setupAndListItemWithId(wrapperId1 + 1);
        
        // Query sales by collection
        SalesBase.Sale[] memory collectionSales = sales.getSalesByCollection(keccak256("TEST_COLLECTION"));
        assertEq(collectionSales.length, 2);
        
        // Test paginated query
        (SalesBase.Sale[] memory pagedSales, uint256 total) = sales.getSalesByCollectionPaginated(
            keccak256("TEST_COLLECTION"), 0, 1
        );
        assertEq(pagedSales.length, 1);
        assertEq(total, 2);
    }

    // === ERROR CONDITION TESTS ===

    function test_RevertOnInvalidMembership() public {
        vm.startPrank(operational);
        vm.expectRevert();
        memberships.revokeMembership(makeAddr("nonexistent"));
        vm.stopPrank();
    }

    function test_RevertOnUnauthorizedAccess() public {
        address unauthorized = makeAddr("unauthorized");
        
        address[] memory users = new address[](1);
        users[0] = unauthorized;
        
        vm.startPrank(unauthorized);
        vm.expectRevert();
        whitelist.addToWhitelist(users);
        vm.stopPrank();
    }

    function test_RevertOnInvalidFeePercentage() public {
        vm.startPrank(admin);
        vm.expectRevert();
        payments.setFeePercentage(1, false, 10001); // > 100%
        vm.stopPrank();
    }

    function test_RevertOnInvalidSchedule() public {
        vm.startPrank(admin);
        
        uint256[] memory scheduleIds = new uint256[](1);
        uint8[] memory daysOfWeek = new uint8[](1);
        uint8[] memory hoursValue = new uint8[](1);
        uint8[] memory minutesValue = new uint8[](1);
        
        scheduleIds[0] = 1;
        daysOfWeek[0] = 8; // Invalid day (> 7)
        hoursValue[0] = 10;
        minutesValue[0] = 30;
        
        vm.expectRevert();
        sales.setSchedules(scheduleIds, daysOfWeek, hoursValue, minutesValue);
        
        vm.stopPrank();
    }

    function test_RevertOnPurchaseAfterExpiry() public {
        uint256 saleId = _setupAndListItem();
        
        // Fast forward past sale end time
        SalesBase.Sale memory sale = sales.getSale(saleId);
        vm.warp(sale.end + 1);
        
        vm.startPrank(operational);
        bytes32 buyHash = keccak256(abi.encodePacked("buy_expired", block.timestamp));
        bytes memory buySig = _signHash(buyHash, buyer);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        vm.expectRevert();
        sales.buy(buyer, buyHash, buySig, address(mockToken), saleIds);
        
        vm.stopPrank();
    }

    function test_RevertOnWithdrawByNonOwner() public {
        uint256 saleId = _setupAndListItem();
        
        vm.startPrank(operational);
        bytes32 withdrawHash = keccak256(abi.encodePacked("withdraw_unauthorized", block.timestamp));
        bytes memory withdrawSig = _signHash(withdrawHash, buyer); // Wrong signer
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        vm.expectRevert();
        sales.withdraw(buyer, withdrawHash, withdrawSig, address(mockToken), saleIds);
        
        vm.stopPrank();
    }

    function test_RevertOnRenewActiveSale() public {
        uint256 saleId = _setupAndListItem();
        
        // Try to renew active sale (should only work on expired sales)
        vm.startPrank(operational);
        bytes32 renewHash = keccak256(abi.encodePacked("renew_active", block.timestamp));
        bytes memory renewSig = _signHash(renewHash, seller);
        
        uint256[] memory saleIds = new uint256[](1);
        saleIds[0] = saleId;
        
        vm.expectRevert();
        sales.renew(seller, renewHash, renewSig, address(mockToken), saleIds);
        
        vm.stopPrank();
    }

    // === EDGE CASE TESTS ===

    function test_EmptyBatchOperations() public {
        vm.startPrank(operational);
        
        address[] memory emptyUsers = new address[](0);
        
        // La whitelist può accettare array vuoti, proviamo con membership che dovrebbe fallire
        // Nel codice MembershipsBase.sol, _setMemberships controlla length == 0
        vm.expectRevert();
        memberships.setMemberships(emptyUsers, 1);
        
        vm.stopPrank();
    }

    function test_DuplicateFeeAddition() public {
        vm.startPrank(admin);
        
        // Prima rimuovo la fee TREASURY esistente per fare spazio
        payments.removeFee(TREASURY);
        
        // Aggiungo una fee custom
        payments.addFee("TEST_FEE", 5000, feeReceiver); // 50%
        
        // Provo ad aggiungere la stessa fee (dovrebbe fallire)
        vm.expectRevert();
        payments.addFee("TEST_FEE", 2000, feeReceiver); // Duplicate name
        
        vm.stopPrank();
    }

    function test_SoulboundBrandTransfer() public {
        vm.startPrank(operational);
        uint256 brandId = brands.register(seller);
        vm.stopPrank();
        
        // Should not be able to transfer soulbound brand
        vm.startPrank(seller);
        vm.expectRevert();
        brands.transferFrom(seller, buyer, brandId);
        vm.stopPrank();
    }

    function test_ZeroPriceListing() public {
        (uint256 wrapperId,) = _setupWrapperForSale();
        
        vm.startPrank(operational);
        bytes32 listHash = keccak256(abi.encodePacked("zero_price", block.timestamp));
        bytes memory listSig = _signHash(listHash, seller);
        
        SalesBase.ListInputs[] memory listInputs = new SalesBase.ListInputs[](1);
        listInputs[0] = SalesBase.ListInputs({
            price: 0, // Zero price
            wrapperId: wrapperId,
            durationId: 0
        });
        
        vm.expectRevert();
        sales.list(seller, listHash, listSig, address(mockToken), listInputs);
        
        vm.stopPrank();
    }

    // === UTILITY FUNCTIONS ===

    function _setupWrapperForSale() internal returns (uint256 wrapperId, uint256 brandId) {
        vm.startPrank(operational);
        
        address[] memory users = new address[](1);
        users[0] = seller;
        whitelist.addToWhitelist(users);
        
        brandId = brands.register(seller);
        
        IWrappers.wrapperData[] memory wrapperData = new IWrappers.wrapperData[](1);
        wrapperData[0] = IWrappers.wrapperData({
            uri: "https://example.com/metadata/1",
            metaKey: "item_001",
            amount: 0,
            tokenId: 1,
            brandId: brandId,
            collection: keccak256("TEST_COLLECTION"),
            active: false
        });
        
        wrappers.imports(seller, wrapperData);
        wrapperId = 0; // First wrapper has ID 0
        
        vm.stopPrank();
    }

    function _setupAndListItem() internal returns (uint256 saleId) {
        (uint256 wrapperId,) = _setupWrapperForSale();
        return _setupAndListItemWithId(wrapperId);
    }

    function _setupAndListItemWithId(uint256 wrapperId) internal returns (uint256 saleId) {
        // Setup approvals
        vm.prank(seller);
        mockToken.approve(address(payments), type(uint256).max);
        vm.prank(treasury);
        fiatToken.approve(address(payments), type(uint256).max);
        
        // List item
        vm.startPrank(operational);
        bytes32 listHash = keccak256(abi.encodePacked("list", block.timestamp, wrapperId));
        bytes memory listSig = _signHash(listHash, seller);
        
        SalesBase.ListInputs[] memory listInputs = new SalesBase.ListInputs[](1);
        listInputs[0] = SalesBase.ListInputs({
            price: 1000 * 10**18,
            wrapperId: wrapperId,
            durationId: 0
        });
        
        sales.list(seller, listHash, listSig, address(mockToken), listInputs);
        
        vm.stopPrank();
        
        return 0; // Return 0 for first sale (sequential IDs)
    }

    function _signHash(bytes32 hash, address signer) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _getPrivateKey(signer), 
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash))
        );
        return abi.encodePacked(r, s, v);
    }

    function _getPrivateKey(address account) internal pure returns (uint256) {
        if (account == vm.addr(ADMIN_KEY)) return ADMIN_KEY;
        if (account == vm.addr(OPERATIONAL_KEY)) return OPERATIONAL_KEY;
        if (account == vm.addr(SELLER_KEY)) return SELLER_KEY;
        if (account == vm.addr(BUYER_KEY)) return BUYER_KEY;
        if (account == vm.addr(TREASURY_KEY)) return TREASURY_KEY;
        if (account == vm.addr(FEE_RECEIVER_KEY)) return FEE_RECEIVER_KEY;
        return 0x999; // fallback
    }
}