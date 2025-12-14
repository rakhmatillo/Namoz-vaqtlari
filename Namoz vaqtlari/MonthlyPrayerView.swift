//
//  MonthlyPrayerView.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  Displays a monthly calendar view of prayer times in a table format.
//  Users can filter by region, year, and month. Uses cache when viewing
//  current month to avoid unnecessary network requests.

import SwiftUI

/// A view that displays prayer times for an entire month in a table format.
/// Supports filtering by region, year, and month with dropdown pickers.
/// Intelligently uses cached data when viewing the current month and region.
struct MonthlyPrayerView: View {
    
    // MARK: - State
    
    /// Array of prayer times for the selected month (fetched from API or cache)
    @State private var monthlyTimes: [DailyPrayerTime] = []
    
    /// Loading indicator state (true while fetching data)
    @State private var isLoading = false
    
    /// Error message to display when network fails (e.g., "Internet yo'q")
    @State private var errorMessage: String?
    
    // MARK: - User Selections
    
    /// Currently selected region (defaults to saved preference or "Toshkent")
    @State private var selectedRegion: String = UserDefaults.standard.string(forKey: "selectedRegionForStatus") ?? "Toshkent"
    
    /// Currently selected year (defaults to current year)
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    /// Currently selected month in "MM" format (defaults to current month)
    @State private var selectedMonth = {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        return monthFormatter.string(from: Date())
    }()

    // MARK: - Constants
    
    /// List of all supported regions in Uzbekistan
    private let regions = [
        "Toshkent", "Andijon", "Buxoro", "Farg'ona", "Jizzax", "Xorazm",
        "Namangan", "Navoiy", "Qashqadaryo", "Qoraqalpog'iston", "Samarqand",
        "Sirdaryo", "Surxondaryo"
    ]
    
    /// Month names in Uzbek with their numeric values
    private let months = [
        ("Yanvar", "01"), ("Fevral", "02"), ("Mart", "03"),
        ("Aprel", "04"), ("May", "05"), ("Iyun", "06"),
        ("Iyul", "07"), ("Avgust", "08"), ("Sentyabr", "09"),
        ("Oktyabr", "10"), ("Noyabr", "11"), ("Dekabr", "12")
    ]

    // MARK: - UI
    
    var body: some View {
        VStack(alignment: .leading) {
            // MARK: Filter Controls
            HStack(spacing: 20) {
                // Region picker
                Picker("Hudud", selection: $selectedRegion) {  // "Region"
                    ForEach(regions, id: \.self) { region in
                        Text(region)
                    }
                }
                .frame(width: 200)

                // Year picker
                Picker("Yil", selection: $selectedYear) {  // "Year"
                    ForEach(2024...2035, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 150)

                // Month picker
                Picker("Oy", selection: $selectedMonth) {  // "Month"
                    ForEach(months, id: \.1) { month in
                        Text(month.0).tag(month.1)
                    }
                }
                .frame(width: 150)
                
                // Loading spinner
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.bottom, 10)

            // MARK: Title and Error Message
            HStack {
                Text("Oylik namoz vaqtlari")  // "Monthly Prayer Times"
                    .font(.title)
                
                // Show warning if there's an error (e.g., no internet)
                if let error = errorMessage {
                    Text("⚠️ \(error)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.bottom)

            // MARK: Table Header
            HStack {
                Text("Kun").frame(width: 40, alignment: .leading)  // "Day"
                Text("Hafta kuni").frame(width: 100, alignment: .leading)  // "Weekday"
                Text("Bomdod").frame(width: 70, alignment: .leading)  // "Fajr"
                Text("Quyosh").frame(width: 70, alignment: .leading)  // "Sunrise"
                Text("Peshin").frame(width: 70, alignment: .leading)  // "Dhuhr"
                Text("Asr").frame(width: 70, alignment: .leading)  // "Asr"
                Text("Shom").frame(width: 70, alignment: .leading)  // "Maghrib"
                Text("Xufton").frame(width: 70, alignment: .leading)  // "Isha"
            }
            .font(.headline)
            .padding(.bottom, 5)

            // MARK: Table Content
            if monthlyTimes.isEmpty && !isLoading {
                // Show placeholder when no data
                Text("Ma'lumot yo'q")  // "No data"
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // Show prayer times table
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

    // MARK: - Data Fetching
    
    /// Fetches monthly prayer times from cache or API.
    /// Smart caching: uses AppDelegate's cache if viewing current month/region,
    /// otherwise fetches from API.
    func fetchMonthlyTimes() {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        let currentMonth = monthFormatter.string(from: now)
        
        // Check if we're viewing the current month and year
        let isCurrentMonthAndYear = (selectedYear == currentYear && selectedMonth == currentMonth)
        
        // Try to use cache if viewing current month/year/region
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
        
        // Not in cache, fetch from API
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
                    // Successfully fetched
                    self.monthlyTimes = times
                    self.errorMessage = nil
                } else {
                    // Network error
                    self.errorMessage = "Internet yo'q"  // "No internet"
                    // Keep showing old data if available
                }
            }
        }
    }

    // MARK: - Helper Methods
    
    /// Extracts the day number from a date string.
    /// - Parameter dateString: Date in "yyyy-MM-dd" format
    /// - Returns: Day number as string (e.g., "15")
    static func getDayOfMonth(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let day = Calendar.current.component(.day, from: date)
            return "\(day)"
        }
        return ""
    }

    /// Gets the weekday name in Uzbek from a date string.
    /// - Parameter dateString: Date in "yyyy-MM-dd" format
    /// - Returns: Weekday name in Uzbek (e.g., "Dushanba" for Monday)
    static func getWeekdayName(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Uzbek weekday names
        let uzbekWeekdays = [
            "Yakshanba",   // Sunday
            "Dushanba",    // Monday
            "Seshanba",    // Tuesday
            "Chorshanba",  // Wednesday
            "Payshanba",   // Thursday
            "Juma",        // Friday
            "Shanba"       // Saturday
        ]
        
        if let date = formatter.date(from: dateString) {
            let weekday = Calendar.current.component(.weekday, from: date)
            return uzbekWeekdays[(weekday - 1) % 7]
        }
        return ""
    }
}

/// A row in the monthly prayer times table showing one day's prayer times.
struct PrayerDayRow: View {
    /// The prayer times data for this day
    let day: DailyPrayerTime

    var body: some View {
        HStack {
            // Day number
            Text(MonthlyPrayerView.getDayOfMonth(from: day.date))
                .frame(width: 40, alignment: .leading)
            
            // Weekday name
            Text(MonthlyPrayerView.getWeekdayName(from: day.date))
                .frame(width: 100, alignment: .leading)
            
            // Prayer times (HH:mm format only, removing seconds)
            Text(String(day.bomdod.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.quyosh.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.peshin.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.asr.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.shom.prefix(5))).frame(width: 70, alignment: .leading)
            Text(String(day.xufton.prefix(5))).frame(width: 70, alignment: .leading)
        }
    }
}
