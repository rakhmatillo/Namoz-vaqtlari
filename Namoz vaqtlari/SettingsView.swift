//
//  SettingsView.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//


import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotification") private var showNotification = true
    @AppStorage("showCountdown") private var showCountdown = false
    @AppStorage("selectedRegionForStatus") private var selectedRegionForStatus = "Toshkent"
    @AppStorage("notificationOffset") private var notificationOffset = 10

    private let regions = [
        "Toshkent", "Andijon", "Buxoro", "Farg'ona", "Jizzax", "Xiva",
        "Namangan", "Navoiy", "Qashqadaryo", "Qoraqalpog'iston", "Samarqand",
        "Sirdaryo", "Surxandaryo"
    ]
    private let languages = ["Oʻzbekcha", "Русский", "English"]
    private let offsetOptions = [0, 5, 10, 15, 30]

    var body: some View {
        Form {
            Section(header: Text("Hudud")) {
                Picker("Hudud", selection: $selectedRegionForStatus) {
                    ForEach(regions, id: \.self) { region in
                        Text(region)
                    }
                }
            }
            
            Section(header: Text("Dastur sozlamalari")) {
                Toggle("Dasturni avtomatik ishga tushirish", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                Toggle("Namoz vaqti kelganda bildirishnoma chiqarilsin", isOn: $showNotification)
                Toggle("Qolgan vaqtni ko‘rsatish", isOn: $showCountdown)
            }

            Section(header: Text("Bildirishnoma sozlamalari")) {
                Picker("Bildirishnoma (daqiqa oldin)", selection: $notificationOffset) {
                    ForEach(offsetOptions, id: \.self) { offset in
                        Text("\(offset) daqiqa oldin")
                    }
                }
            }




            Section {
                Button("Sozlamalarni tiklash") {
                    launchAtLogin = true
                    showNotification = true
                    showCountdown = false
                    selectedRegionForStatus = "Toshkent"
                    notificationOffset = 10
                    
                }
                .foregroundColor(.red)
            }
            Section(header: Text("Aloqa")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fikr-mulohaza yoki xatolik haqida xabar berish uchun quyidagi havolani bosing:")
                    Link("Telegram orqali bogʻlanish", destination: URL(string: "https://t.me/abu_muhammad_umar")!)
                    Link("Elektron manzil orqali bogʻlanish", destination: URL(string: "mailto:rakhmatillo.topiboldiev@gmail.com")!)
                    
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .formStyle(.grouped)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 500, minHeight: 400, idealHeight: 450)
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login toggle failed: \(error)")
            }
        }
    }
}
