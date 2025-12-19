//
//  ClaudeUsageFetcher.swift
//  ClaudePace
//

import Foundation

class ClaudeUsageFetcher {

    struct UsageData {
        var percentUsed: Double?
        var resetDateString: String?
        var rawOutput: String
    }

    static func fetchUsage(completion: @escaping (UsageData) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = runClaudeStepByStep()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func runClaudeStepByStep() -> UsageData {
        print("\n========================================")
        print("STARTING CLAUDE TUI TEST")
        print("========================================\n")

        // Create pseudo-terminal
        var master: Int32 = 0
        var slave: Int32 = 0
        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)

        guard openpty(&master, &slave, nil, nil, &winSize) == 0 else {
            return UsageData(percentUsed: nil, resetDateString: nil, rawOutput: "Failed to create PTY")
        }

        // Start Claude
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
        process.arguments = []
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        do {
            try process.run()
            print("✓ Claude process started (PID: \(process.processIdentifier))")
        } catch {
            close(master)
            close(slave)
            return UsageData(percentUsed: nil, resetDateString: nil, rawOutput: "Failed to start: \(error)")
        }

        // Close slave in parent
        close(slave)

        // Set master to non-blocking
        let flags = fcntl(master, F_GETFL)
        _ = fcntl(master, F_SETFL, flags | O_NONBLOCK)

        // Helper to read all available data
        func readAll() -> String {
            var output = ""
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let bytesRead = read(master, &buffer, buffer.count)
                if bytesRead <= 0 { break }
                if let str = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    output += str
                }
            }
            return output
        }

        // Helper to send text
        func send(_ text: String) {
            if let data = text.data(using: .utf8) {
                data.withUnsafeBytes { ptr in
                    _ = write(master, ptr.baseAddress, data.count)
                }
            }
        }

        var fullOutput = ""

        // STEP 1: Open Claude, wait until trust dialog is COMPLETE
        print("\n--- STEP 1: Waiting for trust dialog to fully load ---")
        var step1Output = ""
        var lastReadTime = Date()

        // Keep reading until no new data for 2 seconds
        while Date().timeIntervalSince(lastReadTime) < 2.0 {
            Thread.sleep(forTimeInterval: 0.5)
            let chunk = readAll()
            if !chunk.isEmpty {
                step1Output += chunk
                lastReadTime = Date()
                print("  Got \(chunk.count) more chars, total now: \(step1Output.count)")
            }
        }
        fullOutput += step1Output

        print("\n========== STEP 1: FULL CLI CONTENTS ==========")
        print("Length: \(step1Output.count) characters")
        print("---BEGIN---")
        print(step1Output)
        print("---END---")
        print("===============================================\n")

        // STEP 2: Send Enter, then read continuously
        print("\n--- STEP 2: Sending Enter ---")
        send("\r")

        print("Reading output for 5 seconds in polling loop...")
        var step2Output = ""
        for i in 1...10 {
            Thread.sleep(forTimeInterval: 0.5)
            let chunk = readAll()
            if !chunk.isEmpty {
                print("  Poll \(i): got \(chunk.count) chars")
                step2Output += chunk
            }
        }
        fullOutput += step2Output

        print("\n========== STEP 2: FULL CLI CONTENTS ==========")
        print("Length: \(step2Output.count) characters")
        print("---BEGIN---")
        print(step2Output)
        print("---END---")
        print("===============================================\n")

        // STEP 3: Type "/usage" at human pace, then Enter
        print("\n--- STEP 3: Typing /usage at human pace ---")
        let command = "/usage"
        for (index, char) in command.enumerated() {
            let charStr = String(char)
            print("  Sending char \(index + 1)/\(command.count): '\(charStr)'")
            send(charStr)
            Thread.sleep(forTimeInterval: 0.1) // 100ms between characters

            // Read any echo/response after each char
            let echo = readAll()
            if !echo.isEmpty {
                print("    Got response: \(echo.count) chars")
            }
        }
        print("Waiting 1 second before Enter...")
        Thread.sleep(forTimeInterval: 1.0)
        print("Sending Enter (\\r)...")
        send("\r")

        print("Reading output for 5 seconds in polling loop...")
        var step3Output = ""
        for i in 1...10 {
            Thread.sleep(forTimeInterval: 0.5)
            let chunk = readAll()
            if !chunk.isEmpty {
                print("  Poll \(i): got \(chunk.count) chars")
                step3Output += chunk
            }
        }
        fullOutput += step3Output

        print("\n========== STEP 3: FULL CLI CONTENTS ==========")
        print("Length: \(step3Output.count) characters")
        print("---BEGIN---")
        print(step3Output)
        print("---END---")
        print("===============================================\n")

        // STEP 4: Search for timezone to confirm we have full data
//        print("\n--- STEP 4: Searching for '(America/Chicago)' in captured data ---")
//        if step3Output.contains("(America/Chicago)") {
//            print("✅ SUCCESS! Found '(America/Chicago)' in the data!")
//            print("This confirms we captured the full usage screen with percentages and reset dates.")
//        } else {
//            print("❌ NOT FOUND: '(America/Chicago)' is missing from captured data")
//            print("This means we only got the 'Loading...' screen, not the actual usage data")
//        }
//        print("===============================================\n")

        // STEP 5: Parse the usage data
        print("\n--- STEP 5: Parsing usage data ---")
        let percentUsed = parseWeeklyUsagePercentage(from: step3Output)
        let resetDate = parseResetDate(from: step3Output)

        print("Parsed percentage: \(percentUsed.map { String($0) } ?? "nil")")
        print("Parsed reset date: \(resetDate ?? "nil")")
        print("===============================================\n")

        // Cleanup
        print("\n--- Cleaning up ---")
        process.terminate()
        close(master)

        print("\n========================================")
        print("TEST COMPLETE")
        print("========================================\n")

        return UsageData(
            percentUsed: percentUsed,
            resetDateString: resetDate,
            rawOutput: fullOutput
        )
    }

    private static func parseWeeklyUsagePercentage(from output: String) -> Double? {
        // Look for "Current week (all models)" followed by "XX% used"
        // Terminal uses \r for line breaks, not \n
        let lines = output.components(separatedBy: CharacterSet(charactersIn: "\r\n")).filter { !$0.isEmpty }

        print("  [PARSE] Searching through \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            if line.contains("Current week (all models)") {
                print("  [PARSE] Found 'Current week (all models)' at line \(index)")
                // Check next few lines for "% used"
                for i in 1...3 {
                    guard index + i < lines.count else { break }
                    let nextLine = String(lines[index + i])
                    print("  [PARSE] Checking line \(index + i): '\(nextLine)'")

                    // Look for pattern like "45% used"
                    if let regex = try? NSRegularExpression(pattern: "(\\d+)%\\s+used", options: .caseInsensitive) {
                        let range = NSRange(nextLine.startIndex..., in: nextLine)
                        if let match = regex.firstMatch(in: nextLine, options: [], range: range) {
                            if let percentRange = Range(match.range(at: 1), in: nextLine) {
                                let percentStr = String(nextLine[percentRange])
                                if let percent = Double(percentStr) {
                                    print("  [PARSE] ✅ Matched percentage: \(percent)")
                                    return percent
                                }
                            }
                        } else {
                            print("  [PARSE] ❌ No regex match on this line")
                        }
                    }
                }
            }
        }
        print("  [PARSE] ❌ Never found percentage")
        return nil
    }

    private static func parseResetDate(from output: String) -> String? {
        // Look for "Resets Dec 22, 1pm" pattern after "Current week (all models)"
        // Terminal uses \r for line breaks, not \n
        let lines = output.components(separatedBy: CharacterSet(charactersIn: "\r\n")).filter { !$0.isEmpty }

        print("  [PARSE-DATE] Searching through \(lines.count) lines")

        for (index, line) in lines.enumerated() {
            if line.contains("Current week (all models)") {
                print("  [PARSE-DATE] Found 'Current week (all models)' at line \(index)")
                // Check next few lines for "Resets"
                for i in 1...5 {
                    guard index + i < lines.count else { break }
                    let nextLine = String(lines[index + i])
                    print("  [PARSE-DATE] Checking line \(index + i): '\(nextLine)'")

                    if nextLine.contains("Resets") {
                        print("  [PARSE-DATE] Found 'Resets' in line")
                        // Extract date between "Resets" and "(America/Chicago)"
                        if let regex = try? NSRegularExpression(pattern: "Resets\\s+([^(]+?)\\s*\\(", options: []) {
                            let range = NSRange(nextLine.startIndex..., in: nextLine)
                            if let match = regex.firstMatch(in: nextLine, options: [], range: range) {
                                if let dateRange = Range(match.range(at: 1), in: nextLine) {
                                    let dateStr = String(nextLine[dateRange]).trimmingCharacters(in: .whitespaces)
                                    print("  [PARSE-DATE] ✅ Matched date: '\(dateStr)'")
                                    return dateStr
                                }
                            } else {
                                print("  [PARSE-DATE] ❌ Regex didn't match")
                            }
                        }
                    }
                }
            }
        }
        print("  [PARSE-DATE] ❌ Never found reset date")
        return nil
    }
}
