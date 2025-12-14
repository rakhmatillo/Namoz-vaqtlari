//
//  MonthlyPrayerResponse.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//
//  Data models for API responses containing prayer times.

import Foundation

/// Root API response structure containing the full month's prayer times.
/// Example JSON:
/// ```json
/// {
///   "isSuccess": true,
///   "statusCode": 200,
///   "response": [...]
/// }
/// ```
struct MonthlyPrayerResponse: Codable {
    /// Indicates if the API request was successful
    let isSuccess: Bool
    
    /// HTTP status code from the API
    let statusCode: Int
    
    /// Array of daily prayer times for the entire month
    let response: [DailyPrayerTime]
}

/// Represents prayer times for a single day.
/// Contains times for all five daily prayers plus sunrise (quyosh).
/// Example JSON:
/// ```json
/// {
///   "bomdod": "05:30:00",
///   "quyosh": "07:15:00",
///   "peshin": "12:30:00",
///   "asr": "15:45:00",
///   "shom": "18:00:00",
///   "xufton": "19:30:00",
///   "region": "Toshkent",
///   "date": "2025-11-15"
/// }
/// ```
struct DailyPrayerTime: Codable {
    /// Fajr prayer time in "HH:mm:ss" format (e.g., "05:30:00")
    let bomdod: String
    
    /// Sunrise time in "HH:mm:ss" format (e.g., "07:15:00")
    /// Note: Sunrise is not a prayer time, but marks the end of Fajr time
    let quyosh: String
    
    /// Dhuhr (noon) prayer time in "HH:mm:ss" format (e.g., "12:30:00")
    let peshin: String
    
    /// Asr (afternoon) prayer time in "HH:mm:ss" format (e.g., "15:45:00")
    let asr: String
    
    /// Maghrib (sunset) prayer time in "HH:mm:ss" format (e.g., "18:00:00")
    let shom: String
    
    /// Isha (night) prayer time in "HH:mm:ss" format (e.g., "19:30:00")
    let xufton: String
    
    /// Region name (e.g., "Toshkent", "Samarqand")
    let region: String
    
    /// Date in ISO format "yyyy-MM-dd" (e.g., "2025-11-15")
    let date: String

    /// Checks if this prayer time entry is for today's date.
    /// Used to quickly find today's times in the cached monthly data.
    /// - Returns: true if the date matches today's date, false otherwise
    func isToday() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date()) == date
    }
}
