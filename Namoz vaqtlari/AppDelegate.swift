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
    
    var refreshTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.refreshPrayerTimes()
            }
            .store(in: &cancellables)
        
        // Create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Yuklanmoqda..."
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshPrayerTimes()
        }
        // Set up the menu
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
    }
    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }
    @objc func refreshPrayerTimes() {

        PrayerTimeManager.shared.fetchMonthlyPrayerTimes(for: self.selectedRegionForStatus) { allTimes in
            guard let allTimes = allTimes else {
                DispatchQueue.main.async {
                    self.statusItem.button?.title = "Yuklashda xatolik..."
                }
                return
            }

            if let today = allTimes.first(where: { $0.isToday() }) {
                let next = self.getNextPrayerTime(from: today)
                DispatchQueue.main.async {
                    if self.showCountdown {
                        self.startCountdown(to: next.time, label: next.name)
                    } else {
                        self.stopCountdown()
                        self.statusItem.button?.title = "\(next.name) \(next.time)"
                    }
                    if self.showNotification {
                        self.schedulePrayerNotification(title: "\(next.name) vaqti", body: "\(next.name) namoz vaqti keldi", at: next.time)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.statusItem.button?.title = "Bugungi ma'lumot yo'q"
                }
            }
        }
    }
    func startCountdown(to time: String, label: String) {
        stopCountdown() // Stop if already running

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let remaining = self.getLiveCountdown(to: time) {
                self.statusItem.button?.title = "\(label) -\(remaining)"
            } else {
                self.statusItem.button?.title = "\(label) vaqti kirdi"
                self.stopCountdown()
                refreshPrayerTimes()
            }
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

        guard let target = calendar.date(from: finalComponents) else { return nil }

        let interval = Int(target.timeIntervalSince(now))
        if interval <= 0 { return nil }

        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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

        // If all times passed, return tomorrow's Bomdod as fallback
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
        PrayerTimeManager.shared.fetchMonthlyPrayerTimes { allTimes in
            guard allTimes != nil else { return }
            DispatchQueue.main.async {
                let controller = SwiftUIWindowController(title: "Oylik Namoz Vaqtlari", content: MonthlyPrayerView(), width: 600, height: 600)
                self.monthlyController = controller
                controller.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    func getTimeLeft(to time: String) -> String? {
        let now = Date()
        let calendar = Calendar.current

        // Combine today's date with the provided prayer time string
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        guard let timeOnly = formatter.date(from: time) else { return nil }

        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)

        var finalComponents = DateComponents()
        finalComponents.year = nowComponents.year
        finalComponents.month = nowComponents.month
        finalComponents.day = nowComponents.day
        finalComponents.hour = timeComponents.hour
        finalComponents.minute = timeComponents.minute

        guard let targetDate = calendar.date(from: finalComponents) else { return nil }

        if targetDate < now {
            return nil // Already passed
        }

        let diff = calendar.dateComponents([.hour, .minute], from: now, to: targetDate)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0

        if hours > 0 {
            return "\(hours) soat \(minutes) daqiqa"
        } else {
            return "\(minutes) daqiqa"
        }
    }

    func schedulePrayerNotification(title: String, body: String, at time: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let date = formatter.date(from: time) else { return }

        var components = Calendar.current.dateComponents([.hour, .minute], from: date)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "prayer_\(title)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}
