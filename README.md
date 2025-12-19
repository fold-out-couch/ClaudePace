# ClaudePace

<p align="center">
  <img src="ClaudePace/icon.png" width="200" alt="ClaudePace Icon">
</p>

**ClaudePace** is a macOS app that helps you monitor your Claude AI usage throughout the week by comparing actual usage against an ideal pace based on working hours.

Stay on track with your Claude usage limits by seeing if you're ahead or behind your ideal pace in real-time.

## Features

- 🎯 **Real-time Usage Tracking** - Automatically fetches your current Claude usage via CLI
- 📊 **Pace Calculation** - Calculates ideal usage based on working hours (6am-10pm, resets Monday 1pm)
- 🎨 **Color-coded Status** - Visual feedback with green (on pace), orange (under-utilizing), and red (over pace) indicators
- 🌙 **Smart Polling** - Adapts polling frequency: 20min normally, hourly when idle, quiet hours (9pm-6am)
- 🪟 **Clean UI** - Minimal, native macOS interface built with SwiftUI
- 🔄 **Manual Refresh** - Force refresh anytime with the refresh button

## Requirements

- macOS 15.6 or later
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- Xcode 16+ (for building from source)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ClaudePace.git
   cd ClaudePace
   ```

2. Open the project in Xcode:
   ```bash
   open ClaudePace.xcodeproj
   ```

3. Build and run (⌘R)

The app will appear in your Applications folder after building.

## How It Works

ClaudePace uses pseudo-terminal (PTY) automation to interact with the Claude CLI:

1. **Opens Claude CLI** in a virtual terminal
2. **Handles the trust dialog** automatically
3. **Executes `/usage` command** to fetch usage statistics
4. **Parses the output** to extract percentage and reset date
5. **Displays the data** alongside your calculated ideal pace

The pace calculation considers:
- Working hours: 6am - 10pm (16 hours/day)
- Week reset: Monday at 1pm
- Total weekly hours: 112 hours (16 hours × 7 days)

Your actual usage is compared against where you "should" be based on elapsed working hours.

## Usage

1. Launch **ClaudePace**
2. The app will automatically fetch your current usage on startup
3. View two bars:
   - **Actual** - Your current Claude usage (color indicates status)
   - **Pace** - Where you should ideally be based on time elapsed
4. See the reset date and last update time at the bottom
5. Click the refresh icon to manually update

### Status Colors

- **Green** - You're under pace (good!)
- **Orange** - You're significantly under pace (>15% unused capacity)
- **Red** - You're over pace (slow down!)

## Configuration

All user-configurable settings are centralized in [`ClaudePace/Config.swift`](ClaudePace/Config.swift):

- **Working Hours** - Default: 6am-10pm (customize for your schedule)
- **Reset Schedule** - Default: Monday at 1pm (matches Claude's weekly reset)
- **Polling Intervals** - Normal: 20min, Sleep mode: 1hr, Pace update: 1min
- **Quiet Hours** - Default: 9pm-6am (no automatic polling during this time)
- **Sleep Mode Threshold** - Enter sleep mode after 3 unchanged usage checks
- **Color Thresholds** - Orange warning at >15% under-utilization
- **UI Colors** - Customize bar colors for different states

Simply edit the constants in `Config.swift` to personalize the app for your workflow.

## Technical Details

- Built with **SwiftUI** for native macOS UI
- Uses **openpty()** for pseudo-terminal creation
- Implements **POSIX terminal I/O** for CLI automation
- Parses terminal output handling `\r` line breaks correctly
- Smart polling with adaptive intervals based on usage patterns
- Centralized configuration system for easy customization

See [`DEBUG_USAGE_FETCH.md`](DEBUG_USAGE_FETCH.md) for detailed debugging notes on the PTY automation implementation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Known Limitations

- Requires Claude CLI to be installed and authenticated
- First run requires accepting the trust dialog through the app
- Usage data depends on Claude CLI's `/usage` command format
- Currently only tracks "Current week (all models)" metric

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built using [Claude Code](https://claude.com/claude-code)
- Inspired by the need to stay on pace with Claude usage limits

---

**Note:** This app is not affiliated with Anthropic. It's a community tool that automates interaction with the official Claude CLI.
