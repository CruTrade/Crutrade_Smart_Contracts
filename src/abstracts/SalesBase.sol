// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./ModifiersBase.sol";
import "./ScheduleBase.sol";
import "../interfaces/ISales.sol";
import "../interfaces/IPayments.sol";
import "../interfaces/IWrappers.sol";
import "../interfaces/IWhitelist.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title SalesBase
 * @notice Base abstract contract for sales operations
 * @dev Contains core business logic for marketplace sales
 * @author Crutrade Team
 */
abstract contract SalesBase is
    Initializable,
    PausableUpgradeable,
    ModifiersBase,
    ScheduleBase
{
    using EnumerableSet for EnumerableSet.UintSet;

    /* CONSTANTS */

    /// @dev List operation identifier
    bytes32 internal constant LIST = keccak256("LIST");

    /// @dev Buy operation identifier
    bytes32 internal constant BUY = keccak256("BUY");

    /// @dev Renew operation identifier
    bytes32 internal constant RENEW = keccak256("RENEW");

    /// @dev Withdraw operation identifier
    bytes32 internal constant WITHDRAW = keccak256("WITHDRAW");

    /// @dev Payments operation identifier
    bytes32 internal constant PAYMENTS = keccak256("PAYMENTS");

    /* TYPES */

    /**
     * @dev List outputs struct definition
     * @param wrapperId ID of the wrapped NFT
     * @param price Sale price
     * @param erc20 Address of the payment token
     */
    struct ListOutputs {
        uint256 wrapperId;
        uint256 price;
        address erc20;
    }

    /**
     * @dev List inputs struct definition
     * @param price Sale price
     * @param wrapperId ID of the wrapped NFT
     * @param durationId Duration ID for the sale
     */
    struct ListInputs {
        uint256 price;
        uint256 wrapperId;
        uint256 durationId;
    }

    /* STORAGE */

    /// @dev Maps duration IDs to their duration in seconds
    mapping(uint256 => uint256) internal _durations;

    /// @dev Maps sale IDs to their sale data
    mapping(uint256 => ISales.Sale) internal _salesById;

    /// @dev Maps collections to their sale IDs
    mapping(bytes32 => EnumerableSet.UintSet) internal _saleIdsByCollection;

    /// @dev Maps sellers to their sale IDs
    mapping(address => EnumerableSet.UintSet) internal _saleIdsBySeller;

    /// @dev Maximum duration ID
    uint256 internal _maxDurationId;

    /// @dev Next sale ID counter
    uint256 internal _nextSaleId;

    /* EVENTS */

    /**
     * @notice Emitted when items are listed for sale
     * @param wallet Seller address
     * @param salesId ID of the sale
     * @param date Date information for the sale
     * @param fee Service fee for the sale
     * @param output Output data for the sale
     */
    event List(
        address wallet,
        uint256 salesId,
        ISales.Date date,
        IPayments.ServiceFee fee,
        ListOutputs output
    );

    /**
     * @notice Emitted when items are purchased
     * @param wallet Buyer address
     * @param salesId ID of the sale
     * @param fees Transaction fees for the sale
     */
    event Buy(address wallet, uint256 salesId, IPayments.TransactionFees fees);

    /**
     * @notice Emitted when sales are renewed
     * @param wallet Seller address
     * @param salesId ID of the sale
     * @param date New date information for the sale
     * @param fee Service fee for the renewal
     */
    event Renew(
        address wallet,
        uint256 salesId,
        ISales.Date date,
        IPayments.ServiceFee fee
    );

    /**
     * @notice Emitted when sales are withdrawn
     * @param wallet Seller address
     * @param salesId ID of the sale
     * @param fee Service fee for the withdrawal
     */
    event Withdraw(
        address wallet,
        uint256 salesId,
        IPayments.ServiceFee fee
    );

    /**
     * @notice Emitted when a listing is cancelled
     * @param salesId ID of the sale
     * @param seller Seller address
     * @param operator Address that performed the cancellation
     */
    event ListingCancelled(
        uint256 salesId,
        address indexed seller,
        address indexed operator
    );

    /**
     * @notice Emitted when a renewal is cancelled
     * @param salesId ID of the sale
     * @param seller Seller address
     * @param operator Address that performed the cancellation
     */
    event RenewCancelled(
        uint256 salesId,
        address indexed seller,
        address indexed operator
    );

    /**
     * @dev Emitted when a duration is set
     * @param durationId ID of the duration
     * @param duration Duration value in seconds
     */
    event DurationSet(uint256 indexed durationId, uint256 duration);

    /* ERRORS */

    /// @dev Thrown when an invalid sale operation is attempted
    error InvalidSaleOperation(string reason);

    /// @dev Thrown when a sale is not found
    error SaleNotFound(uint256 saleId);

    /// @dev Thrown when a sale is not active
    error SaleNotActive(uint256 saleId);

    /// @dev Thrown when a sale has not started yet
    error SaleNotStarted(uint256 startTime);

    /// @dev Thrown when a sale has not expired yet
    error SaleNotExpired(uint256 saleId);

    /// @dev Thrown when an invalid sale price is provided
    error InvalidSalePrice(uint256 price);

    /// @dev Thrown when a sale has expired
    error SaleExpired(uint256 endTime);

    /// @dev Thrown when an invalid sale duration is provided
    error InvalidSaleDuration(uint256 duration);

    /// @dev Thrown when an invalid duration ID is provided
    error InvalidDurationId(uint256 durationId);

    /// @dev Thrown when a future timestamp is required
    error InvalidTimestamp(uint256 timestamp);

    /**
     * @dev Initializes the SalesBase contract
     * @param _roles Address of the roles contract
     */
    function __SalesBase_init(address _roles) internal onlyInitializing {
        __Pausable_init();
        __ModifiersBase_init(_roles, SALES_DOMAIN_NAME, DEFAULT_DOMAIN_VERSION);
        __ScheduleBase_init();

        _durations[0] = 56 days; // Default duration
        _nextSaleId = 1; // Start from 1 to avoid confusion with default value
    }

    /* DURATION MANAGEMENT */

    /**
     * @notice Sets durations for sales
     * @param durationId Duration ID
     * @param duration Duration in seconds
     */
    function _setDuration(uint256 durationId, uint256 duration) internal {
        require(duration > 0, "Duration must be positive");
        require(duration <= 365 days, "Duration exceeds maximum allowed");

        _durations[durationId] = duration;

        if (durationId > _maxDurationId) {
            _maxDurationId = durationId;
        }

        emit DurationSet(durationId, duration);
    }

    /**
     * @notice Gets the duration for a given ID
     * @param durationId The duration ID
     * @return duration The duration in seconds
     */
    function _getDuration(uint256 durationId) internal view returns (uint256) {
        if (durationId > _maxDurationId) revert InvalidDurationId(durationId);
        return _durations[durationId];
    }

    /**
     * @notice Gets all durations with pagination
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return durationIds IDs of durations
     * @return durationValues Duration values in seconds
     * @return total Total number of durations
     */
    function _getAllDurationsPaginated(uint256 offset, uint256 limit)
        internal
        view
        returns (
            uint256[] memory durationIds,
            uint256[] memory durationValues,
            uint256 total
        )
    {
        total = _maxDurationId + 1;

        if (offset >= total || limit == 0) {
            return (new uint256[](0), new uint256[](0), total);
        }

        uint256 size = (offset + limit > total) ? (total - offset) : limit;
        durationIds = new uint256[](size);
        durationValues = new uint256[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 durationId = offset + i;
            durationIds[i] = durationId;
            durationValues[i] = _durations[durationId];
        }

        return (durationIds, durationValues, total);
    }

    /* SALE VIEW FUNCTIONS */

    /**
     * @notice Gets a specific sale
     * @param saleId The ID of the sale
     * @return Sale The sale data
     */
    function _getSale(uint256 saleId) internal view returns (ISales.Sale memory) {
        ISales.Sale memory sale = _salesById[saleId];
        if (sale.seller == address(0)) revert SaleNotFound(saleId);
        return sale;
    }

    /**
     * @notice Gets all sales for a collection
     * @param collection The collection identifier
     * @return Sales for the collection
     */
    function _getSalesByCollection(bytes32 collection)
        internal
        view
        returns (ISales.Sale[] memory)
    {
        uint256[] memory saleIds = _saleIdsByCollection[collection].values();
        uint256 length = saleIds.length;
        ISales.Sale[] memory sales = new ISales.Sale[](length);

        for (uint256 i = 0; i < length; i++) {
            sales[i] = _salesById[saleIds[i]];
        }

        return sales;
    }

    /**
     * @notice Gets sales for a collection with pagination
     * @param collection The collection identifier
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return sales Array of sales
     * @return total Total number of sales
     */
    function _getSalesByCollectionPaginated(
        bytes32 collection,
        uint256 offset,
        uint256 limit
    ) internal view returns (ISales.Sale[] memory sales, uint256 total) {
        uint256[] memory saleIds = _saleIdsByCollection[collection].values();
        total = saleIds.length;

        if (offset >= total || limit == 0) {
            return (new ISales.Sale[](0), total);
        }

        uint256 size = (offset + limit > total) ? (total - offset) : limit;
        sales = new ISales.Sale[](size);

        for (uint256 i = 0; i < size; i++) {
            sales[i] = _salesById[saleIds[offset + i]];
        }

        return (sales, total);
    }

    /**
     * @notice Gets sales for a specific seller with pagination
     * @param seller Address of the seller
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return saleIds Array of sale IDs
     * @return total Total number of sales for the seller
     */
    function _getSalesBySellerPaginated(
        address seller,
        uint256 offset,
        uint256 limit
    ) internal view returns (uint256[] memory saleIds, uint256 total) {
        require(seller != address(0), "Invalid seller address");

        uint256[] memory allSaleIds = _saleIdsBySeller[seller].values();
        total = allSaleIds.length;

        if (offset >= total || limit == 0) {
            return (new uint256[](0), total);
        }

        uint256 size = (offset + limit > total) ? (total - offset) : limit;
        saleIds = new uint256[](size);

        for (uint256 i = 0; i < size; i++) {
            saleIds[i] = allSaleIds[offset + i];
        }

        return (saleIds, total);
    }

    /* SALE OPERATIONS */

    /**
     * @notice Processes a single listing operation
     * @param seller Address of the seller
     * @param erc20 Token address for payment
     * @param input Listing input data
     * @param nextScheduleTime Next scheduled activation time
     * @param saleId ID assigned to the sale
     * @return date Date information
     * @return fee Service fee information
     * @return output Output data
     */
    function _processSingleListing(
        address seller,
        address erc20,
        ListInputs memory input,
        uint256 nextScheduleTime,
        uint256 saleId
    )
        internal
        returns (
            ISales.Date memory,
            IPayments.ServiceFee memory,
            ListOutputs memory
        )
    {
        // Validate input
        if (input.price == 0) revert InvalidSalePrice(input.price);
        if (input.durationId > _maxDurationId)
            revert InvalidDurationId(input.durationId);
        if (_durations[input.durationId] == 0)
            revert InvalidDurationId(input.durationId);

        // Get dependent contracts
        address wrappersAddr = roles.getRoleAddress(WRAPPERS);
        IWrappers wrappers = IWrappers(wrappersAddr);
        address paymentsAddr = roles.getRoleAddress(PAYMENTS);

        uint256 wrapperId = input.wrapperId;
        bytes32 collection = wrappers.getWrapperData(wrapperId).collection;

        // Verify ownership
        address currentOwner = IERC721(wrappersAddr).ownerOf(wrapperId);
        if (currentOwner != seller) revert NotOwner(seller, currentOwner);

        // Calculate dates
        uint256 start = nextScheduleTime;
        uint256 end = start + _durations[input.durationId];

        // Create sale - follow checks-effects-interactions pattern
        ISales.Sale memory sale = ISales.Sale({
            wrapperId: wrapperId,
            price: input.price,
            seller: seller,
            end: end,
            start: start,
            active: true
        });

        // Update storage
        _salesById[saleId] = sale;
        _saleIdsByCollection[collection].add(saleId);
        _saleIdsBySeller[seller].add(saleId);

        // Calculate service fees
        IPayments.ServiceFee memory serviceFee = IPayments(paymentsAddr).splitServiceFee(
            LIST,
            seller,
            erc20
        );

        // Transfer wrapper
        wrappers.marketplaceTransfer(seller, address(this), wrapperId);

        // Prepare output
        ListOutputs memory output = ListOutputs({
            wrapperId: wrapperId,
            price: input.price,
            erc20: erc20
        });

        // Prepare date
        ISales.Date memory date = ISales.Date({expireListDate: end, expireUpcomeDate: start});

        return (date, serviceFee, output);
    }

    /**
     * @notice Processes a single purchase operation
     * @param buyer Address of the buyer
     * @param erc20 Token address for payment
     * @param saleId ID of the sale to purchase
     * @return fees Transaction fees information
     */
    function _processSinglePurchase(
        address buyer,
        address erc20,
        uint256 saleId
    ) internal returns (IPayments.TransactionFees memory fees) {
        IWrappers wrappers = IWrappers(roles.getRoleAddress(WRAPPERS));
        ISales.Sale storage sale = _salesById[saleId];

        // Validate
        if (sale.seller == address(0)) revert SaleNotFound(saleId);
        if (!sale.active) revert SaleNotActive(saleId);
        if (block.timestamp < sale.start) revert SaleNotStarted(sale.start);
        if (block.timestamp > sale.end) revert SaleExpired(sale.end);

        // Verify seller is whitelisted
        require(
            IWhitelist(roles.getRoleAddress(WHITELIST)).isWhitelisted(
                sale.seller
            ),
            "Seller not whitelisted"
        );

        // Cache values to minimize SLOADs
        address seller = sale.seller;
        uint256 price = sale.price;
        uint256 wrapperId = sale.wrapperId;
        bytes32 collection = wrappers.getWrapperData(wrapperId).collection;

        // Update state before external calls (following checks-effects-interactions pattern)
        sale.active = false;
        _saleIdsByCollection[collection].remove(saleId);
        _saleIdsBySeller[seller].remove(saleId);

        // Then calculate and process transaction fees
        IPayments payments = IPayments(roles.getRoleAddress(PAYMENTS));
        IPayments.ServiceFee memory serviceFee = payments.splitServiceFee(
            BUY,
            buyer,
            erc20
        );
        fees = payments.splitFees(erc20, saleId, buyer, seller, price);
        fees.serviceFee = serviceFee;

        // Transfer asset
        wrappers.marketplaceTransfer(address(this), buyer, wrapperId);

        return fees;
    }

    /**
     * @notice Processes a single withdraw operation
     * @param seller Address of the seller
     * @param erc20 Token address for payment
     * @param saleId ID of the sale to withdraw
     * @return fee Service fee information
     */
    function _processSingleWithdraw(
        address seller,
        address erc20,
        uint256 saleId
    ) internal returns (IPayments.ServiceFee memory fee) {
        IWrappers wrappers = IWrappers(roles.getRoleAddress(WRAPPERS));
        ISales.Sale storage sale = _salesById[saleId];

        // Validate
        if (sale.seller == address(0)) revert SaleNotFound(saleId);
        if (!sale.active) revert SaleNotActive(saleId);
        if (block.timestamp < sale.start) revert SaleNotStarted(sale.start);
        if (block.timestamp > sale.end) revert SaleExpired(sale.end);
        if (sale.seller != seller) revert NotOwner(seller, sale.seller);

        // Cache values to minimize SLOADs
        uint256 wrapperId = sale.wrapperId;
        bytes32 collection = wrappers.getWrapperData(wrapperId).collection;

        // Update state before external calls
        sale.active = false;
        _saleIdsByCollection[collection].remove(saleId);
        _saleIdsBySeller[seller].remove(saleId);
        delete _salesById[saleId];

        // Calculate fees
        fee = IPayments(roles.getRoleAddress(PAYMENTS)).splitServiceFee(
            WITHDRAW,
            seller,
            erc20
        );

        // Transfer asset
        wrappers.marketplaceTransfer(address(this), seller, wrapperId);

        return fee;
    }

    /**
     * @notice Processes a single renewal operation
     * @param seller Address of the seller
     * @param erc20 Token address for payment
     * @param saleId ID of the sale to renew
     * @param nextScheduleTime Next scheduled activation time
     * @return date New date information for the sale
     * @return fee Service fee information
     */
    function _processSingleRenewal(
        address seller,
        address erc20,
        uint256 saleId,
        uint256 nextScheduleTime
    ) internal returns (ISales.Date memory date, IPayments.ServiceFee memory fee) {
        ISales.Sale storage sale = _salesById[saleId];

        // Validate
        if (sale.seller == address(0)) revert SaleNotFound(saleId);
        if (!sale.active) revert SaleNotActive(saleId);
        if (block.timestamp < sale.end) revert SaleNotExpired(saleId);
        if (sale.seller != seller) revert NotOwner(seller, sale.seller);
        if (nextScheduleTime <= block.timestamp)
            revert InvalidTimestamp(nextScheduleTime);

        // Calculate fees
        fee = IPayments(roles.getRoleAddress(PAYMENTS)).splitServiceFee(
            RENEW,
            seller,
            erc20
        );

        // Calculate new dates
        uint256 start = nextScheduleTime;
        uint256 duration = sale.end - sale.start;
        uint256 end = start + duration;

        // Update state
        sale.start = start;
        sale.end = end;

        // Prepare date
        date = ISales.Date({expireListDate: end, expireUpcomeDate: start});

        return (date, fee);
    }
}
