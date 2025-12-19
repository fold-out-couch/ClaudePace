//
//  ContentView.swift
//  ClaudePace
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var targetPercentage: Double = 0.0
    @State private var actualUsage: Double?
    @State private var isFetching: Bool = false
    @State private var lastFetchTime: Date?
    @State private var debugExpanded: Bool = false
    @State private var debugLog: [String] = []
    @State private var rawOutput: String = ""
    @State private var unchangedCycles: Int = 0
    @State private var lastUsageValue: Double?
    @State private var isInSleepMode: Bool = false
    @State private var resetDateString: String?

    // Timers configured from Config
    let paceTimer = Timer.publish(every: Config.paceUpdateInterval, on: .main, in: .common).autoconnect()
    let usageTimer = Timer.publish(every: Config.normalPollingInterval, on: .main, in: .common).autoconnect()
    let sleepModeTimer = Timer.publish(every: Config.sleepModePollingInterval, on: .main, in: .common).autoconnect()

    var actualBarColor: Color {
        guard let usage = actualUsage else { return Config.onTrackColor }
        return Config.actualBarColor(usage: usage, pace: targetPercentage)
    }

    var isQuietHours: Bool {
        Config.isQuietHours()
    }

    var formattedLastUpdate: String {
        guard let lastFetch = lastFetchTime else { return "Never" }
        let elapsed = Date().timeIntervalSince(lastFetch)
        let minutes = Int(elapsed / 60)
        let hours = Int(elapsed / 3600)

        if hours >= 1 {
            return "\(hours)h ago"
        } else if minutes >= 1 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Claude Pace")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            // Bar graphs
            VStack(spacing: 16) {
                // Actual bar (top)
                UsageBar(
                    label: "Actual",
                    percentage: actualUsage ?? 0,
                    color: actualBarColor,
                    isLoading: isFetching && actualUsage == nil
                )

                // Pace bar (bottom)
                UsageBar(
                    label: "Pace",
                    percentage: targetPercentage,
                    color: Config.paceColor
                )
            }
            .padding(.horizontal)

            // Status info - evenly spaced
            HStack {
                // Left: Update status
                HStack(spacing: 4) {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Updating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Updated \(formattedLastUpdate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isInSleepMode {
                            Text("(sleep)")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        if isQuietHours {
                            Text("(quiet hrs)")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center: Reset date
                if let resetDate = resetDateString {
                    Text("Resets \(resetDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Right: Refresh button
                Button(action: {
                    if !isFetching {
                        fetchUsage(force: true)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isFetching)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            // Debug panel
            DisclosureGroup("Debug Info", isExpanded: $debugExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pace: \(String(format: "%.2f%%", targetPercentage))")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Actual: \(actualUsage.map { String(format: "%.2f%%", $0) } ?? "nil")")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Difference: \(actualUsage.map { String(format: "%.2f%%", $0 - targetPercentage) } ?? "N/A")")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Fetching: \(isFetching ? "Yes" : "No")")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Last fetch: \(lastFetchTime?.formatted() ?? "Never")")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Unchanged cycles: \(unchangedCycles)")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Sleep mode: \(isInSleepMode ? "Yes" : "No")")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Quiet hours: \(isQuietHours ? "Yes" : "No")")
                        .font(.system(size: 11, design: .monospaced))

                    Divider()

                    Text("Log:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(debugLog.suffix(20), id: \.self) { log in
                                Text(log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)

                    if !rawOutput.isEmpty {
                        Divider()
                        Text("Raw Output (last 500 chars):")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        ScrollView {
                            Text(String(rawOutput.suffix(500)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: 100)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .font(.caption)
        }
        .padding()
        .frame(minWidth: 350, minHeight: 250)
        .onAppear {
            targetPercentage = calculateTargetPercentage()
            addDebugLog("App appeared, pace: \(String(format: "%.2f%%", targetPercentage))")
            fetchUsage(force: true)
        }
        .onReceive(paceTimer) { _ in
            targetPercentage = calculateTargetPercentage()
        }
        .onReceive(usageTimer) { _ in
            // 20-min timer - only fetch if not in sleep mode
            if !isInSleepMode {
                addDebugLog("20-min timer fired")
                fetchUsage(force: false)
            } else {
                addDebugLog("20-min timer fired but in sleep mode, skipping")
            }
        }
        .onReceive(sleepModeTimer) { _ in
            // Hourly timer - fetch if in sleep mode
            if isInSleepMode {
                addDebugLog("Hourly sleep timer fired")
                fetchUsage(force: false)
            }
        }
    }

    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(timestamp)] \(message)")
        if debugLog.count > Config.maxDebugLogEntries {
            debugLog.removeFirst()
        }
    }

    private func fetchUsage(force: Bool = false) {
        // Check quiet hours - don't poll unless forced
        if isQuietHours && !force {
            addDebugLog("Skipping fetch - quiet hours (\(Config.quietHoursStart)-\(Config.quietHoursEnd))")
            return
        }

        guard !isFetching else {
            addDebugLog("Fetch skipped - already fetching")
            return
        }

        isFetching = true
        addDebugLog("Starting fetch\(force ? " (forced)" : "")...")

        ClaudeUsageFetcher.fetchUsage { result in
            self.rawOutput = result.rawOutput
            self.lastFetchTime = Date()

            // Update reset date if available
            if let resetDate = result.resetDateString {
                self.resetDateString = resetDate
                self.addDebugLog("Reset date: \(resetDate)")
            }

            if let percent = result.percentUsed {
                self.addDebugLog("Parsed: \(percent)%")

                // Check if usage changed
                if let lastValue = self.lastUsageValue, lastValue == percent {
                    self.unchangedCycles += 1
                    self.addDebugLog("Usage unchanged, cycle \(self.unchangedCycles)")

                    // Enter sleep mode after threshold of unchanged cycles
                    if self.unchangedCycles >= Config.sleepModeThreshold && !self.isInSleepMode {
                        self.isInSleepMode = true
                        self.addDebugLog("Entering sleep mode (hourly polling)")
                    }
                } else {
                    // Usage changed - reset counters and exit sleep mode
                    self.unchangedCycles = 0
                    if self.isInSleepMode {
                        self.isInSleepMode = false
                        self.addDebugLog("Exiting sleep mode (usage changed)")
                    }
                }

                self.lastUsageValue = percent
                self.actualUsage = percent
            } else {
                self.addDebugLog("Failed to parse percentage")
            }

            self.isFetching = false
        }
    }

    private func calculateTargetPercentage() -> Double {
        let calendar = Calendar.current
        let now = Date()

        // Find the most recent reset time (configured weekday/hour)
        let resetTime = mostRecentResetTime(from: now, calendar: calendar)

        // Count working hours from reset time to now
        var workingHours = 0.0
        var current = resetTime

        while current < now {
            let hour = calendar.component(.hour, from: current)

            // Only count hours between configured work start/end hours
            if hour >= Config.workStartHour && hour < Config.workEndHour {
                // Add the fraction of this hour that's within our range
                let nextHour = calendar.date(byAdding: .hour, value: 1, to: current)!
                let endOfThisHour = min(nextHour, now)
                let hoursToAdd = endOfThisHour.timeIntervalSince(current) / 3600.0
                workingHours += hoursToAdd
            }

            // Move to the next hour
            current = calendar.date(byAdding: .hour, value: 1, to: current)!
        }

        let percentage = (workingHours / Config.totalWeeklyHours) * 100.0
        return min(percentage, 100.0)
    }

    private func mostRecentResetTime(from date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = Config.resetWeekday
        components.hour = Config.resetHour
        components.minute = 0
        components.second = 0

        guard let resetDateTime = calendar.date(from: components) else {
            return date
        }

        // If we're before the reset time this week, go back to last week's reset
        if date < resetDateTime {
            return calendar.date(byAdding: .day, value: -7, to: resetDateTime) ?? resetDateTime
        }

        return resetDateTime
    }
}

struct UsageBar: View {
    let label: String
    let percentage: Double
    let color: Color
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    Text("---%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(format: "%.1f%%", percentage))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 24)

                    // Filled portion
                    if !isLoading {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .frame(width: geometry.size.width * min(percentage / 100.0, 1.0), height: 24)
                            .animation(.easeInOut(duration: 0.5), value: percentage)
                    }
                }
            }
            .frame(height: 24)
        }
    }
}

#Preview {
    ContentView()
}
