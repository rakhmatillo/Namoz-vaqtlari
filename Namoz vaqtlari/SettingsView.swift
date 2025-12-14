//
//  SettingsView.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  User interface for configuring app settings including region selection,
//  notification preferences, countdown display, and launch at login.

import SwiftUI
import ServiceManagement

/// Settings view that allows users to configure the app's behavior.
/// All settings are persisted using @AppStorage (UserDefaults).
struct SettingsView: View {
    
    // MARK: - App Settings (Persisted)
    
    /// Whether the app should launch automatically when the user logs in
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    /// Whether to show system notifications before prayer times
    @AppStorage("showNotification") private var showNotification = true
    
    /// Whether to show countdown timer (e.g., "Asr -02:45") or simple time (e.g., "Asr 15:30")
    @AppStorage("showCountdown") private var showCountdown = false
    
    /// Currently selected region for prayer times (e.g., "Toshkent")
    @AppStorage("selectedRegionForStatus") private var selectedRegionForStatus = "Toshkent"
    
    /// Minutes before prayer time to show notification (0, 5, 10, 15, or 30)
    @AppStorage("notificationOffset") private var notificationOffset = 10

    // MARK: - Constants
    
    /// List of all supported regions in Uzbekistan
    private let regions = [
        "Toshkent", "Andijon", "Buxoro", "Farg'ona", "Jizzax", "Xiva",
        "Namangan", "Navoiy", "Qashqadaryo", "Qoraqalpog'iston", "Samarqand",
        "Sirdaryo", "Surxondaryo"
    ]
    
    /// Available notification timing options (in minutes before prayer)
    private let offsetOptions = [0, 5, 10, 15, 30]

    // MARK: - UI
    
    var body: some View {
        Form {
            // MARK: Region Selection
            Section(header: Text("Hudud")) {  // "Region"
                Picker("Hudud", selection: $selectedRegionForStatus) {
                    ForEach(regions, id: \.self) { region in
                        Text(region)
                    }
                }
            }
            
            // MARK: App Settings
            Section(header: Text("Dastur sozlamalari")) {  // "Application Settings"
                // Launch at login toggle
                Toggle("Dasturni avtomatik ishga tushirish", isOn: $launchAtLogin)  // "Launch app automatically"
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                
                // Notification toggle
                Toggle("Namoz vaqti kelganda bildirishnoma chiqarilsin", isOn: $showNotification)  // "Show notification when prayer time arrives"
                
                // Countdown toggle
                Toggle("Qolgan vaqtni ko'rsatish", isOn: $showCountdown)  // "Show remaining time"
            }

            // MARK: Notification Settings
            Section(header: Text("Bildirishnoma sozlamalari")) {  // "Notification Settings"
                Picker("Bildirishnoma (daqiqa oldin)", selection: $notificationOffset) {  // "Notification (minutes before)"
                    ForEach(offsetOptions, id: \.self) { offset in
                        Text("\(offset) daqiqa oldin")  // "X minutes before"
                    }
                }
            }

            // MARK: Reset Settings
            Section {
                Button("Sozlamalarni tiklash") {  // "Reset Settings"
                    // Reset all settings to defaults
                    launchAtLogin = true
                    showNotification = true
                    showCountdown = false
                    selectedRegionForStatus = "Toshkent"
                    notificationOffset = 10
                }
                .foregroundColor(.red)
            }
            
            // MARK: Contact Information
            Section(header: Text("Aloqa")) {  // "Contact"
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fikr-mulohaza yoki xatolik haqida xabar berish uchun quyidagi havolani bosing:")
                    // "To provide feedback or report a bug, click the links below:"
                    
                    Link("Telegram orqali bogʻlanish", destination: URL(string: "https://t.me/abu_muhammad_umar")!)
                    // "Contact via Telegram"
                    
                    Link("Elektron manzil orqali bogʻlanish", destination: URL(string: "mailto:rakhmatillo.topiboldiev@gmail.com")!)
                    // "Contact via Email"
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 500, minHeight: 400, idealHeight: 450)
    }

    // MARK: - Helper Methods
    
    /// Enables or disables launch at login using macOS ServiceManagement framework.
    /// Only works on macOS 13.0+.
    /// - Parameter enable: true to enable launch at login, false to disable
    private func toggleLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    // Register the app to launch at login
                    try SMAppService.mainApp.register()
                } else {
                    // Unregister the app from launching at login
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login toggle failed: \(error)")
            }
        }
    }
}
