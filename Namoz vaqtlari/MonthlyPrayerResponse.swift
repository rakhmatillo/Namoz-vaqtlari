//
//  MonthlyPrayerResponse.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//


import Foundation

struct MonthlyPrayerResponse: Codable {
    let isSuccess: Bool
    let statusCode: Int
    let response: [DailyPrayerTime]
}

struct DailyPrayerTime: Codable {
    let bomdod: String
    let quyosh: String
    let peshin: String
    let asr: String
    let shom: String
    let xufton: String
    let region: String
    let date: String  // Format: "2025-05-01"

    func isToday() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date()) == date
    }
}