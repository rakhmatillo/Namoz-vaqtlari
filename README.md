# Namoz Vaqtlari (Prayer Times)

A lightweight macOS menu bar application that displays Islamic prayer times for Uzbekistan regions with countdown timers and notifications.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

### 🕌 Prayer Times Display
- **Real-time prayer times** for all Uzbekistan regions
- **Smart display modes**:
  - Simple mode: Shows next prayer name and time
  - Countdown mode: Live countdown to next prayer (updates every minute)
- **Automatic updates** at midnight and after system wake

### 📍 Multi-Region Support
Supports all 13 regions of Uzbekistan:
- Toshkent (Tashkent)
- Andijon (Andijan)
- Buxoro (Bukhara)
- Farg'ona (Fergana)
- Jizzax (Jizzakh)
- Xiva (Khiva)
- Namangan
- Navoiy (Navoi)
- Qashqadaryo (Kashkadarya)
- Qoraqalpog'iston (Karakalpakstan)
- Samarqand (Samarkand)
- Sirdaryo (Syrdarya)
- Surxondaryo (Surkhandarya)

### 🔔 Smart Notifications
- **Customizable notification timing**: 0, 5, 10, 15, or 30 minutes before prayer time
- **Automatic scheduling**: Schedules notifications for the next 10 days
- **Intelligent rescheduling**: Updates notifications when settings change

### 📅 Monthly Prayer Times Viewer
- View complete monthly prayer times in a table format
- Filter by region, year, and month
- Shows all five daily prayers plus sunrise time
- Displays weekday names in Uzbek

### ⚡ Battery Efficient
- **Smart caching**: Fetches data once per month, reuses cached data
- **Minimal updates**: Countdown updates only once per minute (synced to clock)
- **Wake detection**: Automatically refreshes after system sleep/wake
- **No polling**: Uses event-driven architecture

### 🌐 Offline Support
- **Graceful degradation**: Works with cached data when offline
- **Automatic retry**: Intelligent retry with exponential backoff (5min → 15min → 30min → 1hr → 2hr → 6hr)
- **Visual feedback**: Shows warning icon when offline

### 🚀 System Integration
- **Launch at login**: Optional automatic startup
- **Menu bar integration**: Minimal, non-intrusive interface
- **System notifications**: Native macOS notification support
- **Sleep/wake handling**: Automatically updates after Mac wakes from sleep

## Screenshots

### Menu Bar Display
```
Simple Mode:     Peshin 12:30
Countdown Mode:  Asr -02:45
```

### Monthly View
| Kun | Hafta kuni | Bomdod | Quyosh | Peshin | Asr   | Shom  | Xufton |
|-----|-----------|--------|--------|--------|-------|-------|--------|
| 1   | Dushanba  | 05:30  | 07:15  | 12:30  | 15:45 | 18:00 | 19:30  |
| ... | ...       | ...    | ...    | ...    | ...   | ...   | ...    |

### Settings Window
- ✅ Launch at login
- ✅ Show notifications
- ✅ Show countdown timer
- 📍 Select region
- ⏰ Notification timing (0-30 minutes before)

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Active internet connection (for initial data fetch)

### From Source
1. Clone the repository:
```bash
git clone https://github.com/yourusername/namoz-vaqtlari.git
cd namoz-vaqtlari
```

2. Open the project in Xcode:
```bash
open "Namoz vaqtlari.xcodeproj"
```

3. Build and run (⌘R)

### From Release
1. Download the latest release from [Releases](https://github.com/yourusername/namoz-vaqtlari/releases)
2. Drag the app to your Applications folder
3. Launch the app
4. Grant notification permissions when prompted

## Usage

### First Launch
1. The app appears in your menu bar with "Yuklanmoqda..." (Loading...)
2. It automatically fetches prayer times for Toshkent
3. Once loaded, it displays the next prayer time

### Keyboard Shortcuts
- `⌘R` - Refresh prayer times
- `⌘M` - Open monthly prayer times view
- `⌘,` - Open settings
- `⌘Q` - Quit application

### Menu Options
- **Yangilash** - Manually refresh prayer times
- **Oylik namoz vaqtlari** - View monthly calendar
- **Sozlamalar** - Open settings
- **Chiqish** - Quit application

## Architecture

### Project Structure
```
Namoz vaqtlari/
├── Namoz_vaqtlariApp.swift       # App entry point
├── AppDelegate.swift              # Main app logic, timers, notifications
├── PrayerTimeManager.swift        # API client for fetching prayer times
├── MonthlyPrayerResponse.swift    # Data models (DailyPrayerTime)
├── Views/
│   ├── SettingsView.swift        # Settings interface
│   ├── MonthlyPrayerView.swift   # Monthly calendar view
│   └── SwiftUIWindowController.swift # Window management
├── Assets.xcassets/               # App icons and assets
├── Namoz_vaqtlari.entitlements   # App permissions
└── Namoz-vaqtlari-Info.plist     # App configuration
```

### Key Components

#### AppDelegate
- **Timer Management**: Handles countdown, midnight refresh, and retry timers
- **Cache Management**: Stores monthly data, checks for staleness
- **System Events**: Responds to sleep/wake, screen unlock
- **Display Logic**: Updates menu bar based on current prayer time

#### PrayerTimeManager
- **API Integration**: Fetches data from `namoz-vaqtlari.more-info.uz`
- **Flexible Queries**: Supports current month or specific year/month
- **Error Handling**: Returns nil on failure for graceful degradation

#### Data Flow
```
API → PrayerTimeManager → AppDelegate.cache → Display
                                           ↓
                                     Notifications
```

### Smart Features

#### Countdown Synchronization
- Countdown updates are synchronized to clock minutes (at :00 seconds)
- Example: App started at 14:23:50 → next update at 14:24:00, then 14:25:00, etc.
- Saves battery by avoiding sub-minute updates

#### Wake Detection
```swift
// Detects Mac wake from sleep
NSWorkspace.didWakeNotification
→ Check if crossed midnight
→ Refresh data or update display
→ Reschedule timers
```

#### Month Transition
- Automatically detects month changes
- Fetches new month data on the 1st at midnight
- Handles year transitions (December → January)

#### Region Changes
- Detects region changes in settings
- Clears old cache immediately
- Fetches new region data
- Updates display without restart

## API

### Endpoint
```
https://namoz-vaqtlari.more-info.uz:444/api/GetMonthlyPrayTimes/{region}/{year-month}
```

### Example Request
```
GET /api/GetMonthlyPrayTimes/Toshkent/2025-11
```

### Response Format
```json
{
  "isSuccess": true,
  "statusCode": 200,
  "response": [
    {
      "bomdod": "05:30:00",
      "quyosh": "07:15:00",
      "peshin": "12:30:00",
      "asr": "15:45:00",
      "shom": "18:00:00",
      "xufton": "19:30:00",
      "region": "Toshkent",
      "date": "2025-11-01"
    }
  ]
}
```

## Configuration

### User Defaults Keys
```swift
@AppStorage("launchAtLogin") var launchAtLogin: Bool = false
@AppStorage("showNotification") var showNotification: Bool = true
@AppStorage("showCountdown") var showCountdown: Bool = false
@AppStorage("selectedRegionForStatus") var selectedRegionForStatus: String = "Toshkent"
@AppStorage("notificationOffset") var notificationOffset: Int = 10
```

### Notification Permissions
The app requests notification permissions on first launch. You can manage permissions in:
```
System Settings → Notifications → Namoz vaqtlari
```

## Troubleshooting

### Prayer times not updating
1. Check internet connection
2. Click "Yangilash" (Refresh) in menu
3. Check Console.app for errors

### Notifications not appearing
1. System Settings → Notifications → Namoz vaqtlari
2. Ensure notifications are enabled
3. Check "Allow Notifications" is ON

### Countdown showing wrong time after sleep
- This should auto-fix on wake
- If not, manually refresh with ⌘R

### App not launching at login
- macOS 13+: Settings → General → Login Items
- Enable "Namoz vaqtlari" in the list

## Performance

### Battery Impact
- **CPU Usage**: < 1% average
- **Memory**: ~30-50 MB
- **Network**: ~1-2 requests per month
- **Battery Impact**: Minimal (classified as "Low Impact" by macOS)

### Optimization Techniques
1. **Caching**: Monthly data cached, reused for 30 days
2. **Timer Efficiency**: Updates every 60 seconds (not 1 second)
3. **Event-Driven**: No continuous polling
4. **Smart Retry**: Exponential backoff prevents network spam
5. **Lazy Loading**: Monthly view fetches only when opened

## Privacy

- **No Analytics**: No user tracking or analytics
- **No Data Collection**: Prayer times are fetched but not logged
- **No Third-Party Services**: Only connects to official prayer times API
- **Local Storage Only**: All settings stored locally via UserDefaults

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Follow Swift naming conventions
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

## Roadmap

### Future Features
- [ ] Widget support for macOS 14+
- [ ] Qibla direction compass
- [ ] Multiple location support
- [ ] Custom notification sounds
- [ ] Dark mode UI enhancements
- [ ] Hijri calendar integration
- [ ] Prayer time history/statistics
- [ ] Export prayer times to calendar

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Prayer times data provided by [namoz-vaqtlari.more-info.uz](https://namoz-vaqtlari.more-info.uz)
- Built with ❤️ for the Muslim community in Uzbekistan

## Contact

- **Developer**: Rakhmatillo Topiboldiyev
- **Email**: rakhmatillo.topiboldiev@gmail.com
- **Telegram**: [@abu_muhammad_umar](https://t.me/abu_muhammad_umar)

## Support

If you find this app useful, please:
- ⭐ Star this repository
- 🐛 Report bugs via [Issues](https://github.com/rakhmatillo/namoz-vaqtlari/issues)
- 💡 Suggest features via [Discussions](https://github.com/rakhmatillo/namoz-vaqtlari/discussions)
- 📢 Share with friends and family

---

**Made with ❤️ in Uzbekistan** 🇺🇿
