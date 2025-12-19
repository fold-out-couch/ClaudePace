//
//  Config.swift
//  ClaudePace
//

import SwiftUI

struct Config {
    // MARK: - Working Hours
    /// Start of working hours (24-hour format)
    static let workStartHour: Int = 6  // 6am

    /// End of working hours (24-hour format)
    static let workEndHour: Int = 22   // 10pm

    /// Hours per working day
    static var hoursPerDay: Double {
        Double(workEndHour - workStartHour)
    }

    /// Total working hours per week
    static var totalWeeklyHours: Double {
        hoursPerDay * 7.0
    }

    // MARK: - Reset Schedule
    /// Day of week for usage reset (1 = Sunday, 2 = Monday, etc.)
    static let resetWeekday: Int = 2  // Monday

    /// Hour of day for usage reset (24-hour format)
    static let resetHour: Int = 13     // 1pm

    // MARK: - Polling Intervals (in seconds)
    /// How often to update the pace calculation
    static let paceUpdateInterval: TimeInterval = 60  // 1 minute

    /// How often to check usage in normal mode
    static let normalPollingInterval: TimeInterval = 1200  // 20 minutes

    /// How often to check usage in sleep mode
    static let sleepModePollingInterval: TimeInterval = 3600  // 1 hour

    // MARK: - Quiet Hours
    /// Start of quiet hours (24-hour format) - no automatic polling
    static let quietHoursStart: Int = 21  // 9pm

    /// End of quiet hours (24-hour format)
    static let quietHoursEnd: Int = 6     // 6am

    // MARK: - Sleep Mode
    /// Number of unchanged usage cycles before entering sleep mode
    static let sleepModeThreshold: Int = 3

    // MARK: - Color Thresholds
    /// Percentage difference threshold for orange warning (under-utilizing)
    /// Negative value means under pace by this amount
    static let underUtilizationThreshold: Double = -15.0

    // MARK: - UI Colors
    /// Color for the pace bar
    static let paceColor = Color(red: 0.55, green: 0.61, blue: 1.0)  // #8D9CFF - blue

    /// Color for actual usage when on track (under pace)
    static let onTrackColor = Color(red: 0.16, green: 0.65, blue: 0.27)  // Bootstrap green

    /// Color for actual usage when over pace
    static let overPaceColor = Color.red

    /// Color for actual usage when significantly under-utilizing
    static let underUtilizingColor = Color(red: 1.0, green: 0.75, blue: 0.32)  // #FFBF52 - orange

    // MARK: - Debug
    /// Maximum number of debug log entries to keep
    static let maxDebugLogEntries: Int = 100

    // MARK: - Helper Functions
    /// Check if current time is within quiet hours
    static func isQuietHours(at date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    /// Calculate actual bar color based on usage difference
    static func actualBarColor(usage: Double, pace: Double) -> Color {
        let difference = usage - pace
        if difference > 0 {
            return overPaceColor  // Over pace
        } else if difference < underUtilizationThreshold {
            return underUtilizingColor  // Under by more than threshold
        } else {
            return onTrackColor  // Under pace (good)
        }
    }
}
