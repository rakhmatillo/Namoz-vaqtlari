//
//  AppDelegate.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  Main application delegate that manages the menu bar app lifecycle,
//  prayer time display, notifications, and system event handling.

import Cocoa
import SwiftUI
import UserNotifications
import Combine

/// Main application delegate responsible for managing the prayer times menu bar application.
/// Handles timer management, data caching, system wake events, and user notifications.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - UI Components
    
    /// The status bar item that appears in the macOS menu bar
    var statusItem: NSStatusItem!
    
    /// The dropdown menu attached to the status bar item
    let menu = NSMenu()
    
    // MARK: - User Settings (AppStorage)
    
    /// Whether to show countdown timer (e.g., "Asr -02:45") or simple time (e.g., "Asr 15:30")
    @AppStorage("showCountdown") var showCountdown: Bool = false
    
    /// Whether to show system notifications before prayer times
    @AppStorage("showNotification") var showNotification: Bool = true
    
    /// Currently selected region for prayer times (default: Toshkent)
    @AppStorage("selectedRegionForStatus") var selectedRegionForStatus: String = "Toshkent"
    
    // MARK: - Combine & Observers
    
    /// Set of Combine cancellables for observing UserDefaults changes
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Timers
    
    /// Timer for updating the countdown display every minute
    var countdownTimer: Timer?
    
    /// Timer that fires at midnight to refresh prayer times for the new day
    var midnightTimer: Timer?
    
    /// Timer for retrying failed network requests with exponential backoff
    var retryTimer: Timer?
    
    // MARK: - Window Controllers
    
    /// Window controller for the settings view
    var settingsController: NSWindowController?
    
    /// Window controller for the monthly prayer times view
    var monthlyController: NSWindowController?
    
    // MARK: - Data Cache
    
    /// Cached monthly prayer times data (fetched once per month)
    var cachedMonthlyTimes: [DailyPrayerTime]?
    
    /// Timestamp of the last successful data fetch
    var lastFetchDate: Date?
    
    // MARK: - State Management
    
    /// Counter for tracking retry attempts (for exponential backoff)
    var retryCount: Int = 0
    
    /// Last known selected region (used to detect region changes)
    var lastKnownRegion: String = ""
    
    // MARK: - Application Lifecycle
    
    /// Called when the application finishes launching.
    /// Sets up observers, timers, menu items, and fetches initial prayer times.
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Subscribe to UserDefaults changes to detect settings modifications
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
        
        // Listen for Mac wake from sleep to refresh display
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Listen for screen unlock/wake to check for prayer time changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // Create menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Yuklanmoqda..."  // "Loading..."
        }
        
        // Schedule timer to refresh at midnight every day
        scheduleMidnightRefresh()
        
        // Build the dropdown menu
        menu.addItem(NSMenuItem(title: "Yangilash", action: #selector(refreshPrayerTimes), keyEquivalent: "R"))
        menu.addItem(NSMenuItem(title: "Oylik namoz vaqtlari", action: #selector(showMonthlyView), keyEquivalent: "M"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sozlamalar", action: #selector(showSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Chiqish", action: #selector(quitApp), keyEquivalent: "Q"))

        statusItem.menu = menu

        // Request notification permissions from the user
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied: \(String(describing: error))")
            }
        }

        // Fetch initial prayer times
        refreshPrayerTimes()
        
        // Store the initial region for change detection
        lastKnownRegion = selectedRegionForStatus
    }
    
    /// Called when the application is about to terminate.
    /// Cleans up timers and observers.
    func applicationWillTerminate(_ notification: Notification) {
        midnightTimer?.invalidate()
        countdownTimer?.invalidate()
        retryTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    // MARK: - Settings Management
    
    /// Handles changes to user settings (region, notifications, countdown, etc.).
    /// If the region changed, clears cache and fetches new data.
    /// Otherwise, just updates the display or notification scheduling.
    func handleSettingsChange() {
        print("handleSettingsChange called - Region: \(selectedRegionForStatus)")
        
        // Check if region changed
        if lastKnownRegion != selectedRegionForStatus {
            print("Region changed from \(lastKnownRegion) to \(selectedRegionForStatus)")
            lastKnownRegion = selectedRegionForStatus
            
            // Clear cache since it's for a different region
            cachedMonthlyTimes = nil
            lastFetchDate = nil
            
            // Fetch new data for the new region
            refreshPrayerTimes()
        } else {
            // Other settings changed (countdown, notifications, etc.)
            print("Other settings changed, updating display")
            
            // Just update the display without fetching
            updateDisplay()
            
            // If notification setting changed, reschedule
            if showNotification {
                scheduleAllNotifications()
            } else {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
    
    // MARK: - Timer Management
    
    /// Schedules a timer to fire at midnight (00:00:01) to refresh prayer times for the new day.
    /// After firing, it recursively schedules the next midnight.
    func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day! += 1
        components.hour = 0
        components.minute = 0
        components.second = 1
        
        if let nextMidnight = calendar.date(from: components) {
            let timeInterval = nextMidnight.timeIntervalSince(now)
            
            midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.refreshPrayerTimes()
                self?.scheduleMidnightRefresh()  // Schedule next midnight
            }
        }
    }
    
    // MARK: - System Event Handlers
    
    /// Called when the Mac wakes from sleep.
    /// Checks if we crossed midnight while sleeping and refreshes data if needed.
    /// Also reschedules the midnight timer in case it was missed.
    @objc func handleWakeFromSleep() {
        print("Mac woke from sleep, refreshing display...")
        
        // Check if we've crossed into a new day while sleeping
        let calendar = Calendar.current
        if let lastFetch = lastFetchDate,
           !calendar.isDateInToday(lastFetch) {
            // Crossed midnight, need to fetch new data
            refreshPrayerTimes()
        } else {
            // Same day, just update the display
            updateDisplay()
        }
        
        // Reschedule midnight timer in case it was missed
        midnightTimer?.invalidate()
        scheduleMidnightRefresh()
    }
    
    /// Called when the screen wakes or unlocks.
    /// Checks if the current prayer time is still valid or if we need to update.
    @objc func handleScreenUnlock() {
        checkForPrayerTimeChange()
    }
    
    // MARK: - Data Fetching
    
    /// Fetches monthly prayer times from the API.
    /// Uses intelligent caching: only fetches if cache is stale, month changed, or no data exists.
    /// On failure, uses cached data and schedules retry with exponential backoff.
    @objc func refreshPrayerTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        // Determine if we need to fetch new data
        let shouldFetch: Bool = {
            // No cache or no last fetch date? Must fetch
            guard let cachedTimes = cachedMonthlyTimes,
                  let lastFetch = lastFetchDate else {
                return true
            }
            
            // Check if month or year has changed
            let lastMonth = calendar.component(.month, from: lastFetch)
            let currentMonth = calendar.component(.month, from: now)
            let lastYear = calendar.component(.year, from: lastFetch)
            let currentYear = calendar.component(.year, from: now)
            
            if lastYear != currentYear || lastMonth != currentMonth {
                return true
            }
            
            // Check if we have today's data in cache
            let hasTodayData = cachedTimes.contains(where: { $0.isToday() })
            if !hasTodayData {
                return true
            }
            
            return false
        }()
        
        if shouldFetch {
            // Fetch from API
            PrayerTimeManager.shared.fetchMonthlyPrayerTimes(for: self.selectedRegionForStatus) { allTimes in
                guard let allTimes = allTimes else {
                    // Network error occurred
                    DispatchQueue.main.async {
                        if self.cachedMonthlyTimes != nil {
                            // We have old cache, show warning but continue using it
                            self.statusItem.button?.title = "⚠️ Internet yo'q"
                            self.updateDisplay()
                        } else {
                            // No cache at all, show error
                            self.statusItem.button?.title = "Yuklashda xatolik..."
                        }
                        
                        // Schedule retry with exponential backoff
                        self.scheduleRetry()
                    }
                    return
                }
                
                // Success! Clear retry counter and save data
                self.retryCount = 0
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                
                self.cachedMonthlyTimes = allTimes
                self.lastFetchDate = Date()
                self.updateDisplay()
                self.scheduleAllNotifications()
            }
        } else {
            // Cache is fresh, just update display
            updateDisplay()
        }
    }
    
    /// Schedules a retry for failed network requests using exponential backoff.
    /// Retry intervals: 5min → 15min → 30min → 1hr → 2hr → 6hr (then stays at 6hr)
    func scheduleRetry() {
        retryTimer?.invalidate()
        
        retryCount += 1
        
        // Exponential backoff intervals (in seconds)
        let retryIntervals: [TimeInterval] = [300, 900, 1800, 3600, 7200, 21600]
        let retryDelay = retryIntervals[min(retryCount - 1, retryIntervals.count - 1)]
        
        print("Scheduling retry #\(retryCount) in \(retryDelay/60) minutes")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            self?.refreshPrayerTimes()
        }
    }
    
    // MARK: - Display Management
    
    /// Updates the menu bar display with the next prayer time.
    /// Uses cached data to determine what to show.
    /// Handles both countdown mode and simple time display mode.
    func updateDisplay() {
        // Get cached data
        guard let allTimes = cachedMonthlyTimes else {
            DispatchQueue.main.async {
                self.statusItem.button?.title = "Bugungi ma'lumot yo'q"
            }
            return
        }
        
        // Find today's prayer times
        guard let today = allTimes.first(where: { $0.isToday() }) else {
            DispatchQueue.main.async {
                self.statusItem.button?.title = "Bugungi ma'lumot yo'q"
            }
            return
        }
        
        // Get next prayer time (might be tomorrow's Bomdod if all today's prayers passed)
        let next = self.getNextPrayerTime(from: allTimes, today: today)
        
        DispatchQueue.main.async {
            if self.showCountdown {
                // Show countdown mode: "Asr -02:45"
                self.startCountdown(to: next.time, label: next.name)
            } else {
                // Show simple mode: "Asr 15:30"
                self.stopCountdown()
                self.statusItem.button?.title = "\(next.name) \(next.time)"
            }
        }
    }
    
    /// Checks if the current prayer time being displayed has changed.
    /// If it has (e.g., Asr passed and now it's Shom time), updates everything.
    func checkForPrayerTimeChange() {
        guard let allTimes = cachedMonthlyTimes,
              let today = allTimes.first(where: { $0.isToday() }) else {
            return
        }
        
        let next = self.getNextPrayerTime(from: allTimes, today: today)
        let currentTitle = self.statusItem.button?.title ?? ""
        
        // If the prayer name changed, we passed a prayer time
        if !currentTitle.contains(next.name) {
            print("Prayer time changed, updating display and notifications")
            updateDisplay()
            if showNotification {
                scheduleAllNotifications()
            }
        }
    }
    
    // MARK: - Notification Management
    
    /// Schedules system notifications for upcoming prayer times.
    /// Schedules notifications for the next 10 days (or remaining days in month).
    /// Clears old notifications before scheduling new ones.
    func scheduleAllNotifications() {
        guard showNotification, let allTimes = cachedMonthlyTimes else { return }
        
        // Clear all pending notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Schedule for up to 10 days ahead
        let daysToSchedule = min(allTimes.count, 10)
        
        for dayTimes in allTimes.prefix(daysToSchedule) {
            guard let date = formatter.date(from: dayTimes.date) else { continue }
            
            // Skip dates in the past
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: today) { continue }
            
            // Schedule notification for each prayer
            let prayers = [
                ("Bomdod", dayTimes.bomdod),
                ("Peshin", dayTimes.peshin),
                ("Asr", dayTimes.asr),
                ("Shom", dayTimes.shom),
                ("Xufton", dayTimes.xufton)
            ]
            
            for (name, time) in prayers {
                schedulePrayerNotification(
                    title: "\(name) vaqti",
                    body: "\(name) namoz vaqti keldi",
                    at: time,
                    on: date
                )
            }
        }
        
        // Log if we're near end of month
        let currentMonth = calendar.component(.month, from: today)
        if let lastDate = allTimes.last,
           let lastDateParsed = formatter.date(from: lastDate.date) {
            let daysUntilEnd = calendar.dateComponents([.day], from: today, to: lastDateParsed).day ?? 0
            
            if daysUntilEnd < 7 {
                print("Near end of month (\(daysUntilEnd) days left), will fetch next month data at midnight")
            }
        }
    }
    
    /// Schedules a single notification for a specific prayer time.
    /// - Parameters:
    ///   - title: Notification title (e.g., "Bomdod vaqti")
    ///   - body: Notification body (e.g., "Bomdod namoz vaqti keldi")
    ///   - time: Prayer time in "HH:mm:ss" format
    ///   - date: The date for this prayer
    func schedulePrayerNotification(title: String, body: String, at time: String, on date: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        guard let timeOnly = timeFormatter.date(from: time) else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Create trigger for specific date and time
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "prayer_\(title)_\(date.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // MARK: - Countdown Timer
    
    /// Starts the countdown timer for the next prayer.
    /// Synchronizes updates to the top of each minute (at :00 seconds).
    /// - Parameters:
    ///   - time: The target prayer time in "HH:mm" format
    ///   - label: The prayer name (e.g., "Asr")
    func startCountdown(to time: String, label: String) {
        stopCountdown()
        
        // Update immediately
        updateCountdownDisplay(to: time, label: label)
        
        // Calculate seconds until the next minute mark (when seconds = 0)
        let now = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: now)
        let secondsUntilNextMinute = 60 - seconds
        
        // Schedule one-time timer to sync to the minute mark
        Timer.scheduledTimer(withTimeInterval: TimeInterval(secondsUntilNextMinute), repeats: false) { [weak self] _ in
            self?.updateCountdownDisplay(to: time, label: label)
            
            // Now start repeating timer that fires every 60 seconds
            self?.countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateCountdownDisplay(to: time, label: label)
                // Also check if prayer time has changed (in case we missed it due to sleep)
                self?.checkForPrayerTimeChange()
            }
        }
    }
    
    /// Updates the countdown display in the menu bar.
    /// Shows remaining time in HH:MM format (e.g., "Asr -02:45").
    /// - Parameters:
    ///   - time: The target prayer time
    ///   - label: The prayer name
    func updateCountdownDisplay(to time: String, label: String) {
        if let remaining = self.getLiveCountdown(to: time) {
            self.statusItem.button?.title = "\(label) -\(remaining)"
        } else {
            // Time reached!
            self.statusItem.button?.title = "\(label) vaqti kirdi"
            self.stopCountdown()
            self.updateDisplay()
        }
    }
    
    /// Stops and invalidates the countdown timer.
    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    /// Calculates the remaining time until a prayer time.
    /// Handles times that cross midnight (e.g., tomorrow's Bomdod).
    /// - Parameter time: Prayer time in "HH:mm" format
    /// - Returns: Remaining time in "HH:MM" format, or nil if time has passed
    func getLiveCountdown(to time: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let timeOnly = formatter.date(from: time) else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)

        var finalComponents = DateComponents()
        finalComponents.year = todayComponents.year
        finalComponents.month = todayComponents.month
        finalComponents.day = todayComponents.day
        finalComponents.hour = timeComponents.hour
        finalComponents.minute = timeComponents.minute

        guard var target = calendar.date(from: finalComponents) else { return nil }
        
        // If target is in the past, it must be tomorrow
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }

        let interval = Int(target.timeIntervalSince(now))
        if interval <= 0 { return nil }

        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    // MARK: - Prayer Time Calculation
    
    /// Determines the next prayer time to display.
    /// Searches today's prayers first, then returns tomorrow's Bomdod if all passed.
    /// - Parameters:
    ///   - allTimes: Full cached monthly prayer times
    ///   - today: Today's prayer times
    /// - Returns: Tuple containing the prayer name and time
    func getNextPrayerTime(from allTimes: [DailyPrayerTime], today: DailyPrayerTime) -> (name: String, time: String) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"

        // Today's prayer schedule
        let schedule: [(String, String)] = [
            ("Bomdod", today.bomdod),
            ("Peshin", today.peshin),
            ("Asr", today.asr),
            ("Shom", today.shom),
            ("Xufton", today.xufton)
        ]

        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        // Check each prayer time to find the next one
        for (name, timeStr) in schedule {
            guard let timeOnly = formatter.date(from: timeStr) else { continue }

            var components = calendar.dateComponents([.hour, .minute, .second], from: timeOnly)
            components.year = todayComponents.year
            components.month = todayComponents.month
            components.day = todayComponents.day

            if let fullDate = calendar.date(from: components), fullDate > now {
                let displayTime = displayFormatter.string(from: fullDate)
                return (name, displayTime)
            }
        }

        // All today's prayers passed, get tomorrow's Bomdod
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let tomorrowDateStr = dateFormatter.string(from: tomorrow)
            
            // Find tomorrow's data in the full cache
            if let tomorrowTimes = allTimes.first(where: { $0.date == tomorrowDateStr }) {
                let bomdodTime = String(tomorrowTimes.bomdod.prefix(5))
                return ("Bomdod", bomdodTime)
            }
        }
        
        // Fallback: use today's Bomdod (countdown will automatically add 1 day)
        let fallbackTime = String(today.bomdod.prefix(5))
        return ("Bomdod", fallbackTime)
    }
    
    // MARK: - Menu Actions
    
    /// Terminates the application.
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    /// Shows the settings window.
    /// Reuses existing window if already open.
    @objc func showSettingsWindow() {
        if let controller = settingsController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SwiftUIWindowController(title: "Sozlamalar", content: SettingsView(), width: 400, height: 300)
        self.settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Shows the monthly prayer times view.
    /// Reuses existing window if already open.
    /// Fetches data if cache is empty.
    @objc func showMonthlyView() {
        if let controller = monthlyController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Fetch data if we don't have cache
        if cachedMonthlyTimes == nil {
            refreshPrayerTimes()
        }
        
        DispatchQueue.main.async {
            let controller = SwiftUIWindowController(title: "Oylik Namoz Vaqtlari", content: MonthlyPrayerView(), width: 600, height: 600)
            self.monthlyController = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
