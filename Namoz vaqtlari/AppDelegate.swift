//
//  AppDelegate.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//


import Cocoa
import SwiftUI
import UserNotifications
import Combine
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    @AppStorage("showCountdown") var showCountdown: Bool = false
    @AppStorage("showNotification") var showNotification: Bool = true
    @AppStorage("selectedRegionForStatus") var selectedRegionForStatus: String = "Toshkent"
    var cancellables = Set<AnyCancellable>()
    var countdownTimer: Timer?
    var settingsController: NSWindowController?
    var monthlyController: NSWindowController?
    
    var midnightTimer: Timer?
    var cachedMonthlyTimes: [DailyPrayerTime]?
    var lastFetchDate: Date?
    var retryTimer: Timer?
    var retryCount: Int = 0
    var lastKnownRegion: String = ""
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
        
        // Listen for wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeFromSleep),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Listen for screen unlock/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Yuklanmoqda..."
        }
        
        scheduleMidnightRefresh()
        
        menu.addItem(NSMenuItem(title: "Yangilash", action: #selector(refreshPrayerTimes), keyEquivalent: "R"))
        menu.addItem(NSMenuItem(title: "Oylik namoz vaqtlari", action: #selector(showMonthlyView), keyEquivalent: "M"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sozlamalar", action: #selector(showSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Chiqish", action: #selector(quitApp), keyEquivalent: "Q"))

        statusItem.menu = menu

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied: \(String(describing: error))")
            }
        }

        refreshPrayerTimes()
        lastKnownRegion = selectedRegionForStatus
    }
    
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
    
    func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day! += 1
        components.hour = 0
        components.minute = 0
        components.second = 1
        
        if let nextMidnight = calendar.date(from: components) {
            let timeInterval = nextMidnight.timeIntervalSince(now)
            
            midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.refreshPrayerTimes()
                self?.scheduleMidnightRefresh()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        midnightTimer?.invalidate()
        countdownTimer?.invalidate()
        retryTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
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
    
    @objc func handleScreenUnlock() {
        // When screen wakes, check if we need to update
        checkForPrayerTimeChange()
    }
    
    @objc func refreshPrayerTimes() {
        let calendar = Calendar.current
        let now = Date()
        
        let shouldFetch: Bool = {
            guard let cachedTimes = cachedMonthlyTimes,
                  let lastFetch = lastFetchDate else {
                return true
            }
            
            let lastMonth = calendar.component(.month, from: lastFetch)
            let currentMonth = calendar.component(.month, from: now)
            let lastYear = calendar.component(.year, from: lastFetch)
            let currentYear = calendar.component(.year, from: now)
            
            if lastYear != currentYear || lastMonth != currentMonth {
                return true
            }
            
            let hasTodayData = cachedTimes.contains(where: { $0.isToday() })
            if !hasTodayData {
                return true
            }
            
            return false
        }()
        
        if shouldFetch {
            PrayerTimeManager.shared.fetchMonthlyPrayerTimes(for: self.selectedRegionForStatus) { allTimes in
                guard let allTimes = allTimes else {
                    DispatchQueue.main.async {
                        // If we have old cache, continue using it with a warning
                        if self.cachedMonthlyTimes != nil {
                            self.statusItem.button?.title = "⚠️ Internet yo'q"
                            self.updateDisplay() // Still show old data
                        } else {
                            self.statusItem.button?.title = "Yuklashda xatolik..."
                        }
                        
                        // Retry with exponential backoff
                        self.scheduleRetry()
                    }
                    return
                }
                
                // Success! Clear retry counter
                self.retryCount = 0
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                
                self.cachedMonthlyTimes = allTimes
                self.lastFetchDate = Date()
                self.updateDisplay()
                self.scheduleAllNotifications()
            }
        } else {
            updateDisplay()
        }
    }
    
    func scheduleRetry() {
        retryTimer?.invalidate()
        
        retryCount += 1
        
        // Exponential backoff: 5min, 15min, 30min, 1hr, 2hr, then every 6 hours
        let retryIntervals: [TimeInterval] = [300, 900, 1800, 3600, 7200, 21600]
        let retryDelay = retryIntervals[min(retryCount - 1, retryIntervals.count - 1)]
        
        print("Scheduling retry #\(retryCount) in \(retryDelay/60) minutes")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            self?.refreshPrayerTimes()
        }
    }
    
    func updateDisplay() {
        guard let allTimes = cachedMonthlyTimes,
              let today = allTimes.first(where: { $0.isToday() }) else {
            DispatchQueue.main.async {
                self.statusItem.button?.title = "Bugungi ma'lumot yo'q"
            }
            return
        }
        
        let next = self.getNextPrayerTime(from: today)
        DispatchQueue.main.async {
            if self.showCountdown {
                self.startCountdown(to: next.time, label: next.name)
            } else {
                self.stopCountdown()
                self.statusItem.button?.title = "\(next.name) \(next.time)"
            }
        }
    }
    
    func checkForPrayerTimeChange() {
        guard let allTimes = cachedMonthlyTimes,
              let today = allTimes.first(where: { $0.isToday() }) else {
            return
        }
        
        let next = self.getNextPrayerTime(from: today)
        let currentTitle = self.statusItem.button?.title ?? ""
        
        // If the next prayer has changed (time passed), update everything
        if !currentTitle.contains(next.name) {
            print("Prayer time changed, updating display and notifications")
            updateDisplay()
            if showNotification {
                scheduleAllNotifications()
            }
        }
    }
    
    func scheduleAllNotifications() {
        guard showNotification, let allTimes = cachedMonthlyTimes else { return }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Schedule for remaining days in current month + try to get next month's first week
        let daysToSchedule = min(allTimes.count, 10) // Schedule up to 10 days
        
        for dayTimes in allTimes.prefix(daysToSchedule) {
            guard let date = formatter.date(from: dayTimes.date) else { continue }
            
            // Skip past dates
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: today) { continue }
            
            let prayers = [
                ("Bomdod", dayTimes.bomdod),
                ("Peshin", dayTimes.peshin),
                ("Asr", dayTimes.asr),
                ("Shom", dayTimes.shom),
                ("Xufton", dayTimes.xufton)
            ]
            
            for (name, time) in prayers {
                schedulePrayerNotification(title: "\(name) vaqti", body: "\(name) namoz vaqti keldi", at: time, on: date)
            }
        }
        
        // If we're near end of month and have less than 7 days scheduled,
        // try to fetch next month's data proactively
        let currentMonth = calendar.component(.month, from: today)
        if let lastDate = allTimes.last,
           let lastDateParsed = formatter.date(from: lastDate.date) {
            let daysUntilEnd = calendar.dateComponents([.day], from: today, to: lastDateParsed).day ?? 0
            
            if daysUntilEnd < 7 {
                print("Near end of month (\(daysUntilEnd) days left), will fetch next month data at midnight")
            }
        }
    }
    
    func startCountdown(to time: String, label: String) {
        stopCountdown()
        
        updateCountdownDisplay(to: time, label: label)
        
        let now = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: now)
        let secondsUntilNextMinute = 60 - seconds
        
        Timer.scheduledTimer(withTimeInterval: TimeInterval(secondsUntilNextMinute), repeats: false) { [weak self] _ in
            self?.updateCountdownDisplay(to: time, label: label)
            
            self?.countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateCountdownDisplay(to: time, label: label)
                // Also check if prayer time has changed (in case we missed it due to sleep)
                self?.checkForPrayerTimeChange()
            }
        }
    }
    
    func updateCountdownDisplay(to time: String, label: String) {
        if let remaining = self.getLiveCountdown(to: time) {
            self.statusItem.button?.title = "\(label) -\(remaining)"
        } else {
            self.statusItem.button?.title = "\(label) vaqti kirdi"
            self.stopCountdown()
            self.updateDisplay()
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
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
        
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        }

        let interval = Int(target.timeIntervalSince(now))
        if interval <= 0 { return nil }

        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    func getNextPrayerTime(from times: DailyPrayerTime) -> (name: String, time: String) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "HH:mm"

        let schedule: [(String, String)] = [
            ("Bomdod", times.bomdod),
            ("Peshin", times.peshin),
            ("Asr", times.asr),
            ("Shom", times.shom),
            ("Xufton", times.xufton)
        ]

        let calendar = Calendar.current
        let today = calendar.dateComponents([.year, .month, .day], from: now)

        for (name, timeStr) in schedule {
            guard let timeOnly = formatter.date(from: timeStr) else { continue }

            var components = calendar.dateComponents([.hour, .minute, .second], from: timeOnly)
            components.year = today.year
            components.month = today.month
            components.day = today.day

            if let fullDate = calendar.date(from: components), fullDate > now {
                let displayTime = displayFormatter.string(from: fullDate)
                return (name, displayTime)
            }
        }

        // All today's prayers passed, return tomorrow's Bomdod
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            let tomorrowDateStr = dateFormatter.string(from: tomorrow)
            
            // Try to find tomorrow's data in cache
            if let tomorrowTimes = cachedMonthlyTimes?.first(where: { $0.date == tomorrowDateStr }) {
                let fallbackTime = String(tomorrowTimes.bomdod.prefix(5))
                return ("Bomdod", fallbackTime)
            }
        }
        
        // Fallback: use today's Bomdod time (countdown will add 1 day automatically)
        let fallbackTime = String(times.bomdod.prefix(5))
        return ("Bomdod", fallbackTime)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
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

    @objc func showMonthlyView() {
        if let controller = monthlyController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
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

    func schedulePrayerNotification(title: String, body: String, at time: String, on date: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        guard let timeOnly = timeFormatter.date(from: time) else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "prayer_\(title)_\(date.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
