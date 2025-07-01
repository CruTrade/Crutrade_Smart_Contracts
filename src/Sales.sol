// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./abstracts/SalesBase.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title Sales
 * @notice Manages sales of wrapped NFTs within the Crutrade ecosystem
 * @dev Provides interface for listing, buying, and managing NFT sales
 * @author Crutrade Team
 * @custom:security-contact security@crutrade.io
 */
contract Sales is SalesBase, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    /* CONSTANTS */

    /// @dev Lister role identifier
    bytes32 internal constant LISTER = keccak256("LISTER");

    /// @dev Buyer role identifier
    bytes32 internal constant BUYER = keccak256("BUYER");

    /// @dev Renewer role identifier
    bytes32 internal constant RENEWER = keccak256("RENEWER");

    /// @dev Withdrawer role identifier
    bytes32 internal constant WITHDRAWER = keccak256("WITHDRAWER");

    /* INITIALIZATION */

    /**
     * @dev Prevents initialization of the implementation contract
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Sales contract
     * @param _roles The address of the roles contract
     */
    function initialize(address _roles) public initializer {
        __SalesBase_init(_roles);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /* SCHEDULE FUNCTIONS */

    /**
     * @notice Gets the next active schedule time
     * @return timestamp The timestamp of the next scheduled activation
     */
    function getNextScheduleTime() public view returns (uint256) {
        return _getNextScheduleTime();
    }

    /**
     * @notice Sets the listing delay for when no active schedules exist
     * @param delay Delay in seconds
     * @dev Can only be called by an account with the OWNER role
     */
    function setListingDelay(uint256 delay) external onlyRole(OWNER) {
        _setListingDelay(delay);
    }

    /**
     * @notice Gets the current listing delay
     * @return Listing delay in seconds
     */
    function getListingDelay() external view returns (uint256) {
        return _getListingDelay();
    }

    /**
     * @notice Sets schedule for sales activation
     * @param scheduleIds Array of schedule IDs
     * @param daysOfWeek Array of days (1-7, Monday-Sunday)
     * @param hourValues Array of hours (0-23)
     * @param minuteValues Array of minutes (0-59)
     */
    function setSchedules(
        uint256[] calldata scheduleIds,
        uint8[] calldata daysOfWeek,
        uint8[] calldata hourValues,
        uint8[] calldata minuteValues
    ) external onlyRole(OWNER) {
        uint256 length = scheduleIds.length;
        if (length == 0) revert InvalidSaleOperation("Empty input array");
        if (
            length != daysOfWeek.length ||
            length != hourValues.length ||
            length != minuteValues.length
        ) revert InvalidSaleOperation("Length mismatch");

        unchecked {
            for (uint256 i; i < length; i++) {
                bool success = _setSchedule(
                    scheduleIds[i],
                    daysOfWeek[i],
                    hourValues[i],
                    minuteValues[i]
                );

                require(success, "Invalid schedule parameters");
            }
        }
    }

    /**
     * @notice Removes schedules
     * @param scheduleIds Array of schedule IDs to remove
     */
    function removeSchedules(uint256[] calldata scheduleIds)
        external
        onlyRole(OWNER)
    {
        uint256 length = scheduleIds.length;
        if (length == 0) revert InvalidSaleOperation("Empty input array");

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                bool success = _deactivateSchedule(scheduleIds[i]);
                require(success, "Invalid schedule ID");
            }
        }
    }

    /**
     * @notice Sets durations for sales
     * @param durationIds Array of duration IDs
     * @param durations Array of durations in seconds
     */
    function setDurations(
        uint256[] calldata durationIds,
        uint256[] calldata durations
    ) external onlyRole(OWNER) {
        uint256 length = durationIds.length;
        if (length == 0) revert InvalidSaleOperation("Empty input array");
        if (length != durations.length)
            revert InvalidSaleOperation("Length mismatch");

        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _setDuration(durationIds[i], durations[i]);
            }
        }
    }

    /* SALE OPERATIONS */

    /**
     * @notice Lists items for sale
     * @param seller The seller's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param wrapperId ID of the wrapped NFT
     * @param directSaleId Direct sale ID
     * @param isFiat Whether this is a fiat payment
     * @param price Sale price
     * @param expireType Duration type for the sale
     * @param erc20 Payment token address
     */
    function list(
        address seller,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 wrapperId,
        uint256 directSaleId,
        bool isFiat,
        uint256 price,
        uint256 expireType,
        address erc20
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(OPERATIONAL)
        onlyWhitelisted(seller)
        checkListSignature(
            seller,
            this.list.selector,
            nonce,
            expiry,
            wrapperId,
            directSaleId,
            isFiat,
            price,
            expireType,
            signature
        )
    {
        // Convert to the internal format
        ListInputs memory saleInputs = ListInputs({
            price: price,
            wrapperId: wrapperId,
            durationId: expireType
        });

        ISales.Date memory date;
        IPayments.ServiceFee memory fee;
        ListOutputs memory output;

        // Get the next scheduled activation time
        uint256 nextScheduleTime = getNextScheduleTime();

        uint256 saleId = _nextSaleId++;
        (
            date,
            fee,
            output
        ) = _processSingleListing(
            seller,
            erc20,
            saleInputs,
            nextScheduleTime,
            saleId
        );

        emit List(seller, saleId, date, fee, output);
    }

    /**
     * @notice Buys items from sales
     * @param buyer The buyer's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param directSaleId Direct sale ID
     * @param saleId Sale ID to buy
     * @param isFiat Whether this is a fiat payment
     * @param erc20 Payment token address
     */
    function buy(
        address buyer,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 directSaleId,
        uint256 saleId,
        bool isFiat,
        address erc20
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(OPERATIONAL)
        onlyWhitelisted(buyer)
        checkBuySignature(
            buyer,
            this.buy.selector,
            nonce,
            expiry,
            directSaleId,
            saleId,
            isFiat,
            signature
        )
    {

        IPayments.TransactionFees memory fees = _processSinglePurchase(buyer, erc20, saleId);

        emit Buy(buyer, saleId, fees);
    }

    /**
     * @notice Withdraws items from sales
     * @param seller The seller's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param directSaleId Direct sale ID
     * @param saleId Sale ID to withdraw
     * @param isFiat Whether this is a fiat payment
     * @param erc20 Payment token address
     */
    function withdraw(
        address seller,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 directSaleId,
        uint256 saleId,
        bool isFiat,
        address erc20
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(OPERATIONAL)
        onlyWhitelisted(seller)
        checkWithdrawSignature(
            seller,
            this.withdraw.selector,
            nonce,
            expiry,
            directSaleId,
            saleId,
            isFiat,
            signature
        )
    {
        IPayments.ServiceFee memory fee = _processSingleWithdraw(seller, erc20, saleId);

        emit Withdraw(seller, saleId, fee);
    }

    /**
     * @notice Renews items in sales
     * @param seller The seller's address
     * @param nonce Nonce to prevent replay attacks
     * @param expiry Timestamp when signature expires
     * @param signature The signature to verify
     * @param directSaleId Direct sale ID
     * @param saleId Sale ID to renew
     * @param isFiat Whether this is a fiat payment
     * @param expireType New duration type for the renewal
     * @param erc20 Payment token address
     */
    function renew(
        address seller,
        uint256 nonce,
        uint256 expiry,
        bytes calldata signature,
        uint256 directSaleId,
        uint256 saleId,
        bool isFiat,
        uint256 expireType,
        address erc20
    )
        external
        whenNotPaused
        nonReentrant
        onlyRole(OPERATIONAL)
        onlyWhitelisted(seller)
        checkRenewSignature(
            seller,
            this.renew.selector,
            nonce,
            expiry,
            directSaleId,
            saleId,
            isFiat,
            expireType,
            signature
        )
    {
        ISales.Date memory date;
        IPayments.ServiceFee memory fee;

        (date, fee) = _processSingleRenewal(seller, erc20, saleId, getNextScheduleTime());

        emit Renew(seller, saleId, date, fee);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Gets a specific sale
     * @param saleId The ID of the sale
     * @return Sale The sale data
     */
    function getSale(uint256 saleId) external view returns (ISales.Sale memory) {
        return _getSale(saleId);
    }

    /**
     * @notice Gets all sales for a collection
     * @param collection The collection identifier
     * @return Sale[] Array of sales for the collection
     */
    function getSalesByCollection(bytes32 collection)
        external
        view
        returns (ISales.Sale[] memory)
    {
        return _getSalesByCollection(collection);
    }

    /**
     * @notice Gets sales for a collection with pagination
     * @param collection The collection identifier
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return sales Array of sales for the collection
     * @return total Total number of sales in the collection
     */
    function getSalesByCollectionPaginated(
        bytes32 collection,
        uint256 offset,
        uint256 limit
    ) external view returns (ISales.Sale[] memory sales, uint256 total) {
        return _getSalesByCollectionPaginated(collection, offset, limit);
    }

    /**
     * @notice Gets sales for a specific seller with pagination
     * @param seller Address of the seller
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return saleIds Array of sale IDs owned by the seller
     * @return total Total number of sales for the seller
     */
    function getSalesBySellerPaginated(
        address seller,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory saleIds, uint256 total) {
        return _getSalesBySellerPaginated(seller, offset, limit);
    }

    /**
     * @notice Gets the schedule for a given ID
     * @param scheduleId The schedule ID
     * @return dayOfWeek The day of the week (1-7)
     * @return hourValue The hour (0-23)
     * @return minuteValue The minute (0-59)
     * @return isActive Whether the schedule is active
     */
    function getSchedule(uint256 scheduleId)
        external
        view
        returns (
            uint8 dayOfWeek,
            uint8 hourValue,
            uint8 minuteValue,
            bool isActive
        )
    {
        return _getSchedule(scheduleId);
    }

    /**
     * @notice Gets the duration for a given ID
     * @param durationId The duration ID
     * @return uint256 The duration in seconds
     */
    function getDuration(uint256 durationId) external view returns (uint256) {
        return _getDuration(durationId);
    }

    /**
     * @notice Gets all durations with pagination
     * @param offset Starting index
     * @param limit Maximum number of items to return
     * @return durationIds IDs of durations
     * @return durationValues Duration values in seconds
     * @return total Total number of durations
     */
    function getAllDurationsPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (
            uint256[] memory durationIds,
            uint256[] memory durationValues,
            uint256 total
        )
    {
        return _getAllDurationsPaginated(offset, limit);
    }

    /**
     * @notice Gets all active schedules
     * @return scheduleIds IDs of active schedules
     * @return dayWeeks Days of week for each schedule
     * @return hourValues Hours for each schedule
     * @return minuteValues Minutes for each schedule
     */
    function getActiveSchedules()
        external
        view
        returns (
            uint256[] memory scheduleIds,
            uint8[] memory dayWeeks,
            uint8[] memory hourValues,
            uint8[] memory minuteValues
        )
    {
        return _getActiveSchedules();
    }

    /* ADMIN FUNCTIONS */

    /**
     * @notice Pauses the contract
     * @dev Can only be called by an account with the PAUSER role
     */
    function pause() external onlyRole(PAUSER) {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev Can only be called by an account with the PAUSER role
     */
    function unpause() external onlyRole(PAUSER) {
        _unpause();
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER)
        checkAddressZero(newImplementation)
    {}
}
