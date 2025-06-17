// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/* TYPES */

/**
 * @dev Schedule struct definition
 * @param dayOfWeek Day of week (1-7, Monday-Sunday)
 * @param hour Hour (0-23)
 * @param minute Minute (0-59)
 * @param isActive Whether the schedule is active
 */
struct Schedule {
    uint8 dayOfWeek;
    uint8 hour;
    uint8 minute;
    bool isActive;
}

/**
 * @title ScheduleBase
 * @notice Base abstract contract for schedule management
 * @dev Provides functionality for managing and calculating scheduled time slots
 * @author Crutrade Team
 */
abstract contract ScheduleBase is Initializable {
    /* CONSTANTS */

    /// @dev Number of seconds in a day
    uint256 internal constant SECONDS_PER_DAY = 86400;

    /// @dev Number of seconds in an hour
    uint256 internal constant SECONDS_PER_HOUR = 3600;

    /// @dev Number of seconds in a minute
    uint256 internal constant SECONDS_PER_MINUTE = 60;

    /* STORAGE */

    /// @dev Maps schedule IDs to schedule objects
    mapping(uint256 => Schedule) internal _schedules;

    /// @dev Counter for number of schedules
    uint256 internal _scheduleCount;

    /// @dev Default listing delay when no active schedules (in seconds)
    uint256 internal _listingDelay;

    /* EVENTS */

    /**
     * @dev Event emitted when a schedule is set
     * @param scheduleId ID of the schedule
     * @param dayOfWeek Day of week (1-7, Monday-Sunday)
     * @param hour Hour (0-23)
     * @param minute Minute (0-59)
     */
    event ScheduleSet(
        uint256 indexed scheduleId,
        uint8 dayOfWeek,
        uint8 hour,
        uint8 minute
    );

    /**
     * @dev Event emitted when a schedule is removed
     * @param scheduleId ID of the removed schedule
     */
    event ScheduleRemoved(uint256 indexed scheduleId);

    /**
     * @dev Event emitted when listing delay is updated
     * @param oldDelay Previous delay value
     * @param newDelay New delay value
     */
    event ListingDelayUpdated(uint256 oldDelay, uint256 newDelay);

    /* ERRORS */

    /// @dev Thrown when an invalid listing delay is provided
    error InvalidListingDelay(uint256 delay);

    /**
     * @dev Initializes the schedule contract
     */
    function __ScheduleBase_init() internal onlyInitializing {
        // Set initial schedule for Saturday at 15:30
        _schedules[1] = Schedule({
            dayOfWeek: 6, // Saturday (1=Monday, 6=Saturday)
            hour: 15,
            minute: 30,
            isActive: true
        });

        _scheduleCount = 2; // One initial schedule
        _listingDelay = 7 * SECONDS_PER_DAY; // Default to 7 days
    }

    /* SCHEDULE MANAGEMENT */

    /**
     * @notice Sets the listing delay for when no active schedules exist
     * @param delay Delay in seconds
     */
    function _setListingDelay(uint256 delay) internal {
        if (delay > 365 * SECONDS_PER_DAY) {
            revert InvalidListingDelay(delay);
        }

        uint256 oldDelay = _listingDelay;
        _listingDelay = delay;

        emit ListingDelayUpdated(oldDelay, delay);
    }

    /**
     * @notice Sets a schedule
     * @param scheduleId ID of the schedule
     * @param dayOfWeek Day of week (1-7, Monday-Sunday)
     * @param hourValue Hour (0-23)
     * @param minuteValue Minute (0-59)
     * @return Success indicator
     */
    function _setSchedule(
        uint256 scheduleId,
        uint8 dayOfWeek,
        uint8 hourValue,
        uint8 minuteValue
    ) internal returns (bool) {
        // Validation
        if (dayOfWeek < 1 || dayOfWeek > 7) return false;
        if (hourValue >= 24) return false;
        if (minuteValue >= 60) return false;

        _schedules[scheduleId] = Schedule({
            dayOfWeek: dayOfWeek,
            hour: hourValue,
            minute: minuteValue,
            isActive: true
        });

        if (scheduleId >= _scheduleCount) {
            _scheduleCount = scheduleId + 1;
        }

        emit ScheduleSet(scheduleId, dayOfWeek, hourValue, minuteValue);
        return true;
    }

    /**
     * @notice Deactivates a schedule
     * @param scheduleId ID of the schedule
     * @return Success indicator
     */
    function _deactivateSchedule(uint256 scheduleId) internal returns (bool) {
        if (scheduleId >= _scheduleCount) return false;

        _schedules[scheduleId].isActive = false;
        emit ScheduleRemoved(scheduleId);
        return true;
    }

    /* SCHEDULE CALCULATIONS */

    /**
     * @notice Gets the next active schedule time
     * @return Next scheduled activation time
     */
    function _getNextScheduleTime() internal view returns (uint256) {
        uint256 nowTime = block.timestamp;
        if (_scheduleCount == 0) return nowTime + _listingDelay;

        uint256 nextScheduleTime = type(uint256).max;

        // Find the earliest upcoming schedule
        for (uint256 i; i < _scheduleCount; i++) {
            Schedule memory schedule = _schedules[i];
            if (!schedule.isActive) continue;

            uint256 nextOccurrence = _getNextOccurrence(
                nowTime,
                schedule.dayOfWeek,
                schedule.hour,
                schedule.minute
            );

            if (nextOccurrence < nextScheduleTime) {
                nextScheduleTime = nextOccurrence;
            }
        }

        // Use configurable listing delay if no active schedules
        if (nextScheduleTime == type(uint256).max) {
            nextScheduleTime = nowTime + _listingDelay;
        }

        return nextScheduleTime;
    }

    /**
     * @notice Calculates the next occurrence of a schedule
     * @param timestamp Current timestamp
     * @param targetDayOfWeek Target day of week (1-7, Monday-Sunday)
     * @param targetHour Target hour (0-23)
     * @param targetMinute Target minute (0-59)
     * @return Next occurrence timestamp
     */
    function _getNextOccurrence(
        uint256 timestamp,
        uint8 targetDayOfWeek,
        uint8 targetHour,
        uint8 targetMinute
    ) internal pure returns (uint256) {
        // Get current day of week using BokkyPooBah's formula (1-7, Monday-Sunday)
        uint256 _days = timestamp / SECONDS_PER_DAY;
        uint8 currentDayOfWeek = uint8(((_days + 3) % 7) + 1);

        // Calculate days until target day
        uint256 daysUntilTarget;
        if (currentDayOfWeek <= targetDayOfWeek) {
            daysUntilTarget = targetDayOfWeek - currentDayOfWeek;
        } else {
            daysUntilTarget = 7 - (currentDayOfWeek - targetDayOfWeek);
        }

        // Get start of today (midnight UTC)
        uint256 startOfToday = (timestamp / SECONDS_PER_DAY) * SECONDS_PER_DAY;

        // Calculate target time today
        uint256 targetTimeToday = startOfToday +
            (targetHour * SECONDS_PER_HOUR) +
            (targetMinute * SECONDS_PER_MINUTE);

        // If same day but target time already passed, go to next week
        if (daysUntilTarget == 0 && timestamp >= targetTimeToday) {
            daysUntilTarget = 7;
        }

        // Return target time + days until target
        return targetTimeToday + (daysUntilTarget * SECONDS_PER_DAY);
    }

    /* VIEW FUNCTIONS */

    /**
     * @notice Gets the current listing delay
     * @return Listing delay in seconds
     */
    function _getListingDelay() internal view returns (uint256) {
        return _listingDelay;
    }

    /**
     * @notice Gets the schedule for a given ID
     * @param scheduleId The schedule ID
     * @return dayOfWeek The day of the week (1-7)
     * @return hourValue The hour (0-23)
     * @return minuteValue The minute (0-59)
     * @return isActive Whether the schedule is active
     */
    function _getSchedule(
        uint256 scheduleId
    )
        internal
        view
        returns (
            uint8 dayOfWeek,
            uint8 hourValue,
            uint8 minuteValue,
            bool isActive
        )
    {
        require(scheduleId < _scheduleCount, "Invalid schedule ID");

        Schedule memory schedule = _schedules[scheduleId];
        return (
            schedule.dayOfWeek,
            schedule.hour,
            schedule.minute,
            schedule.isActive
        );
    }

    /**
     * @notice Gets all active schedules
     * @return scheduleIds IDs of active schedules
     * @return dayWeeks Days of week for each schedule
     * @return hourValues Hours for each schedule
     * @return minuteValues Minutes for each schedule
     */
    function _getActiveSchedules()
        internal
        view
        returns (
            uint256[] memory scheduleIds,
            uint8[] memory dayWeeks,
            uint8[] memory hourValues,
            uint8[] memory minuteValues
        )
    {
        // Count active schedules first
        uint256 activeCount = _countActiveSchedules();

        // Initialize arrays
        scheduleIds = new uint256[](activeCount);
        dayWeeks = new uint8[](activeCount);
        hourValues = new uint8[](activeCount);
        minuteValues = new uint8[](activeCount);

        // Fill arrays with active schedules
        uint256 index = 0;
        for (uint256 i; i < _scheduleCount; i++) {
            Schedule memory schedule = _schedules[i];
            if (schedule.isActive) {
                scheduleIds[index] = i;
                dayWeeks[index] = schedule.dayOfWeek;
                hourValues[index] = schedule.hour;
                minuteValues[index] = schedule.minute;
                index++;
            }
        }

        return (scheduleIds, dayWeeks, hourValues, minuteValues);
    }

    /**
     * @notice Counts active schedules
     * @return count Number of active schedules
     */
    function _countActiveSchedules() internal view returns (uint256 count) {
        for (uint256 i; i < _scheduleCount; i++) {
            if (_schedules[i].isActive) {
                count++;
            }
        }
        return count;
    }
}
