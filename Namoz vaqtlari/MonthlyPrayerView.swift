//
//  MonthlyPrayerView.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//

import SwiftUI


struct MonthlyPrayerView: View {
    @State private var monthlyTimes: [DailyPrayerTime] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var selectedRegion: String = UserDefaults.standard.string(forKey: "selectedRegionForStatus") ?? "Toshkent"
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        return monthFormatter.string(from: Date())
    }()

    private let regions = [
        "Toshkent", "Andijon", "Buxoro", "Farg'ona", "Jizzax", "Xorazm",
        "Namangan", "Navoiy", "Qashqadaryo", "Qoraqalpog'iston", "Samarqand",
        "Sirdaryo", "Surxondaryo"
    ]
    private let months = [
        ("Yanvar", "01"), ("Fevral", "02"), ("Mart", "03"),
        ("Aprel", "04"), ("May", "05"), ("Iyun", "06"),
        ("Iyul", "07"), ("Avgust", "08"), ("Sentyabr", "09"),
        ("Oktyabr", "10"), ("Noyabr", "11"), ("Dekabr", "12")
    ]

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 20) {
                Picker("Hudud", selection: $selectedRegion) {
                    ForEach(regions, id: \.self) { region in
                        Text(region)
                    }
                }
                .frame(width: 200)

                Picker("Yil", selection: $selectedYear) {
                    ForEach(2024...2035, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 150)

                Picker("Oy", selection: $selectedMonth) {
                    ForEach(months, id: \.1) { month in
                        Text(month.0).tag(month.1)
                    }
                }
                .frame(width: 150)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.bottom, 10)

            HStack {
                Text("Oylik namoz vaqtlari")
                    .font(.title)
                
                if let error = errorMessage {
                    Text("⚠️ \(error)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.bottom)

            HStack {
                Text("Kun").frame(width: 40, alignment: .leading)
                Text("Hafta kuni").frame(width: 100, alignment: .leading)
                Text("Bomdod").frame(width: 70, alignment: .leading)
                Text("Quyosh").frame(width: 70, alignment: .leading)
                Text("Peshin").frame(width: 70, alignment: .leading)
                Text("Asr").frame(width: 70, alignment: .leading)
                Text("Shom").frame(width: 70, alignment: .leading)
                Text("Xufton").frame(width: 70, alignment: .leading)
            }
            .font(.headline)
            .padding(.bottom, 5)

            if monthlyTimes.isEmpty && !isLoading {
                Text("Ma'lumot yo'q")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(monthlyTimes, id: \.date) { day in
                            PrayerDayRow(day: day)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 700)
        .padding()
        .onAppear {
            fetchMonthlyTimes()
        }
        .onChange(of: selectedRegion) { _ in
            fetchMonthlyTimes()
        }
        .onChange(of: selectedMonth) { _ in
            fetchMonthlyTimes()
        }
        .onChange(of: selectedYear) { _ in
            fetchMonthlyTimes()
        }
    }

    func fetchMonthlyTimes() {
        // First, try to load from AppDelegate cache if it matches current selection
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        let currentMonth = monthFormatter.string(from: now)
        
        // Check if we're viewing current month and region
        let isCurrentMonthAndYear = (selectedYear == currentYear && selectedMonth == currentMonth)
        
        if isCurrentMonthAndYear,
           let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let cachedTimes = appDelegate.cachedMonthlyTimes,
           !cachedTimes.isEmpty,
           cachedTimes.first?.region == selectedRegion {
            
            // Use cache! No need to fetch
            DispatchQueue.main.async {
                self.monthlyTimes = cachedTimes
                self.errorMessage = nil
                self.isLoading = false
            }
            return
        }
        
        // If not in cache, fetch from API
        isLoading = true
        errorMessage = nil
        
        PrayerTimeManager.shared.fetchMonthlyPrayerTimes(
            for: selectedRegion,
            year: selectedYear,
            month: selectedMonth
        ) { times in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let times = times {
                    self.monthlyTimes = times
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Internet yo'q"
                    // Keep showing old data if available
                }
            }
        }
    }

    static func getDayOfMonth(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let day = Calendar.current.component(.day, from: date)
            return "\(day)"
        }
        return ""
    }

    static func getWeekdayName(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let uzbekWeekdays = [
            "Yakshanba", "Dushanba", "Seshanba", "Chorshanba",
            "Payshanba", "Juma", "Shanba"
        ]
        if let date = formatter.date(from: dateString) {
            let weekday = Calendar.current.component(.weekday, from: date)
            return uzbekWeekdays[(weekday - 1) % 7]
        }
        return ""
    }
}

struct PrayerDayRow: View {
    let day: DailyPrayerTime

    var body: some View {
        HStack {
            Text(MonthlyPrayerView.getDayOfMonth(from: day.date)).frame(width: 40, alignment: .leading)
            Text(MonthlyPrayerView.getWeekdayName(from: day.date)).frame(width: 100, alignment: .leading)
            Text(String(day.bomdod.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.quyosh.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.peshin.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.asr.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.shom.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.xufton.prefix(5))).frame(width: 70, alignment: .leading)
        }
    }
}
