//
//  PrayerTimeManager.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  Manages fetching prayer times from the remote API.
//  Provides methods for fetching current month or specific year/month.

import Foundation

/// Singleton manager for fetching Islamic prayer times from the API.
/// Supports fetching both current month and specific year/month combinations.
class PrayerTimeManager {
    
    // MARK: - Singleton
    
    /// Shared singleton instance
    static let shared = PrayerTimeManager()
    
    /// Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Public API
    
    /// Fetches prayer times for the current month and specified region.
    /// This is the backward-compatible method used by AppDelegate.
    /// - Parameters:
    ///   - region: Region name (e.g., "Toshkent", "Samarqand"). Defaults to "Toshkent".
    ///   - completion: Callback with array of prayer times, or nil if failed
    func fetchMonthlyPrayerTimes(for region: String = "Toshkent", completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let currentMonth = dateFormatter.string(from: Date())

        fetchMonthlyPrayerTimes(for: region, yearMonth: currentMonth, completion: completion)
    }
    
    /// Fetches prayer times for a specific year, month, and region.
    /// Used by MonthlyPrayerView to allow users to browse different months.
    /// - Parameters:
    ///   - region: Region name (e.g., "Toshkent", "Samarqand")
    ///   - year: The year (e.g., 2025)
    ///   - month: The month in "MM" format (e.g., "01" for January, "12" for December)
    ///   - completion: Callback with array of prayer times, or nil if failed
    func fetchMonthlyPrayerTimes(for region: String = "Toshkent", year: Int, month: String, completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let yearMonth = "\(year)-\(month)"
        fetchMonthlyPrayerTimes(for: region, yearMonth: yearMonth, completion: completion)
    }
    
    // MARK: - Private Implementation
    
    /// Internal method that performs the actual HTTP request to fetch prayer times.
    /// - Parameters:
    ///   - region: Region name
    ///   - yearMonth: Date string in "yyyy-MM" format (e.g., "2025-11")
    ///   - completion: Callback with prayer times array or nil on failure
    private func fetchMonthlyPrayerTimes(for region: String, yearMonth: String, completion: @escaping ([DailyPrayerTime]?) -> Void) {
        // Construct API URL
        // Example: https://namoz-vaqtlari.more-info.uz:444/api/GetMonthlyPrayTimes/Toshkent/2025-11
        let urlStr = "https://namoz-vaqtlari.more-info.uz:444/api/GetMonthlyPrayTimes/\(region)/\(yearMonth)"
        
        guard let url = URL(string: urlStr) else {
            print("Invalid URL: \(urlStr)")
            completion(nil)
            return
        }

        // Create and start the network request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for network errors
            guard let data = data, error == nil else {
                print("Network error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            // Try to decode the JSON response
            do {
                let decoded = try JSONDecoder().decode(MonthlyPrayerResponse.self, from: data)
                // Return the array of daily prayer times
                completion(decoded.response)
            } catch {
                print("Decode error: \(error)")
                completion(nil)
            }
        }

        task.resume()
    }
}
