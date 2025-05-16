// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ScheduleLib
 * @notice Pure library for time scheduling calculations
 * @dev Contains only pure functions, no state, reusable by any contract
 * @author Crutrade Team - Optimized Version
 */
library ScheduleLib {
  // Time constants
  uint256 internal constant SECONDS_PER_DAY = 86400;
  uint256 internal constant SECONDS_PER_HOUR = 3600;
  uint256 internal constant SECONDS_PER_MINUTE = 60;

  /**
   * @dev Schedule structure
   */
  struct Schedule {
    uint8 dayOfWeek; // 1-7 (Monday-Sunday)
    uint8 hour; // 0-23
    uint8 minute; // 0-59
    bool isActive;
  }

  /**
   * @notice Calculates the day of the week from a timestamp
   * @param timestamp Unix timestamp
   * @return Day of the week (1-7, Monday-Sunday)
   */
  function getDayOfWeek(uint256 timestamp) internal pure returns (uint8) {
    uint256 daysSinceEpoch = timestamp / SECONDS_PER_DAY;
    return uint8(((daysSinceEpoch + 3) % 7) + 1); // Jan 1, 1970 was a Thursday (4)
  }

  /**
   * @notice Calculates the start of the day
   * @param timestamp Unix timestamp
   * @return Timestamp at the beginning of the day (00:00:00)
   */
  function getStartOfDay(uint256 timestamp) internal pure returns (uint256) {
    return timestamp - (timestamp % SECONDS_PER_DAY);
  }

  /**
   * @notice Calculates how many days until the next day of the week
   * @param currentDayOfWeek Current day (1-7)
   * @param targetDayOfWeek Target day (1-7)
   * @return Days until target
   */
  function daysToNextDayOfWeek(
    uint8 currentDayOfWeek,
    uint8 targetDayOfWeek
  ) internal pure returns (uint256) {
    if (currentDayOfWeek <= targetDayOfWeek) {
      return targetDayOfWeek - currentDayOfWeek;
    } else {
      return 7 - (currentDayOfWeek - targetDayOfWeek);
    }
  }

  /**
   * @notice Checks if a timestamp is before a specific time of day
   * @param timestamp Timestamp to check
   * @param hour Target hour (0-23)
   * @param minute Target minute (0-59)
   * @return True if the timestamp is before the specified time
   */
  function isBeforeTimeOfDay(
    uint256 timestamp,
    uint8 hour,
    uint8 minute
  ) internal pure returns (bool) {
    uint256 secondsIntoDay = timestamp % SECONDS_PER_DAY;
    uint256 targetSeconds = (hour * SECONDS_PER_HOUR) +
      (minute * SECONDS_PER_MINUTE);
    return secondsIntoDay < targetSeconds;
  }

  /**
   * @notice Calculates the next occurrence of a given day/time
   * @param timestamp Current timestamp
   * @param targetDayOfWeek Target day of week (1-7, Monday-Sunday)
   * @param hour Target hour (0-23)
   * @param minute Target minute (0-59)
   * @return Next occurrence timestamp
   */
  function getNextOccurrence(
    uint256 timestamp,
    uint8 targetDayOfWeek,
    uint8 hour,
    uint8 minute
  ) internal pure returns (uint256) {
    require(
      targetDayOfWeek >= 1 && targetDayOfWeek <= 7,
      'Invalid day of week'
    );
    require(hour < 24, 'Invalid hour');
    require(minute < 60, 'Invalid minute');

    uint8 currentDayOfWeek = getDayOfWeek(timestamp);
    uint256 daysUntilTarget = daysToNextDayOfWeek(
      currentDayOfWeek,
      targetDayOfWeek
    );

    // If it's the same day, check if the time has already passed
    if (daysUntilTarget == 0) {
      if (!isBeforeTimeOfDay(timestamp, hour, minute)) {
        daysUntilTarget = 7; // Go to next week
      }
    }

    uint256 startOfDay = getStartOfDay(timestamp);
    uint256 targetTimeSeconds = (hour * SECONDS_PER_HOUR) +
      (minute * SECONDS_PER_MINUTE);

    return startOfDay + (daysUntilTarget * SECONDS_PER_DAY) + targetTimeSeconds;
  }

  /**
   * @notice Finds the next active timestamp among schedules
   * @param schedules Mapping of schedules
   * @param scheduleCount Total number of schedules
   * @return Timestamp of the next activation
   */
  function getNextScheduleTime(
    mapping(uint256 => Schedule) storage schedules,
    uint256 scheduleCount
  ) internal view returns (uint256) {
    uint256 nowTime = block.timestamp;
    if (scheduleCount == 0) return nowTime;

    uint256 nextScheduleTime = type(uint256).max;

    // Find the next active schedule
    for (uint256 i = 0; i < scheduleCount; i++) {
      Schedule storage schedule = schedules[i];
      if (!schedule.isActive) continue;

      uint256 nextOccurrence = getNextOccurrence(
        nowTime,
        schedule.dayOfWeek,
        schedule.hour,
        schedule.minute
      );

      if (nextOccurrence < nextScheduleTime) {
        nextScheduleTime = nextOccurrence;
      }
    }

    // Default to one week from now if no active schedules
    if (nextScheduleTime == type(uint256).max) {
      nextScheduleTime = nowTime + 7 days;
    }

    return nextScheduleTime;
  }

  /**
   * @notice Sets a schedule with validation
   * @param schedules Mapping of schedules
   * @param scheduleId ID of the schedule
   * @param dayOfWeek Day of week (1-7, Monday-Sunday)
   * @param hour Hour (0-23)
   * @param minute Minute (0-59)
   * @return Success indicator
   */
  function setSchedule(
    mapping(uint256 => Schedule) storage schedules,
    uint256 scheduleId,
    uint8 dayOfWeek,
    uint8 hour,
    uint8 minute
  ) internal returns (bool) {
    if (dayOfWeek < 1 || dayOfWeek > 7) return false;
    if (hour >= 24) return false;
    if (minute >= 60) return false;

    schedules[scheduleId] = Schedule({
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
      isActive: true
    });

    return true;
  }

  /**
   * @notice Deactivates a schedule
   * @param schedules Mapping of schedules
   * @param scheduleId ID of the schedule
   * @return Success indicator
   */
  function deactivateSchedule(
    mapping(uint256 => Schedule) storage schedules,
    uint256 scheduleId
  ) internal returns (bool) {
    if (schedules[scheduleId].dayOfWeek == 0) return false; // Not existing

    schedules[scheduleId].isActive = false;
    return true;
  }

  /**
   * @notice Counts active schedules
   * @param schedules Mapping of schedules
   * @param scheduleCount Total number of schedules
   * @return count Number of active schedules
   */
  function countActiveSchedules(
    mapping(uint256 => Schedule) storage schedules,
    uint256 scheduleCount
  ) internal view returns (uint256 count) {
    for (uint256 i = 0; i < scheduleCount; i++) {
      if (schedules[i].isActive) {
        count++;
      }
    }
    return count;
  }
}
