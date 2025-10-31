//
//  PrayerTimeManager.swift
//  Namoz vaqtlari
//
//  Created by rakhmatillo on 23/05/25.
//

import Foundation

class PrayerTimeManager {
    static let shared = PrayerTimeManager()
    private init() {}

    // Original method - fetches current month (backward compatible)
    func fetchMonthlyPrayerTimes(for region: String = "Toshkent", completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let currentMonth = dateFormatter.string(from: Date())

        fetchMonthlyPrayerTimes(for: region, yearMonth: currentMonth, completion: completion)
    }
    
    // New method - fetches specific year and month
    func fetchMonthlyPrayerTimes(for region: String = "Toshkent", year: Int, month: String, completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let yearMonth = "\(year)-\(month)"
        fetchMonthlyPrayerTimes(for: region, yearMonth: yearMonth, completion: completion)
    }
    
    // Private helper method that does the actual fetching
    private func fetchMonthlyPrayerTimes(for region: String, yearMonth: String, completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let urlStr = "https://namoz-vaqtlari.more-info.uz:444/api/GetMonthlyPrayTimes/\(region)/\(yearMonth)"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MonthlyPrayerResponse.self, from: data)
                completion(decoded.response)
            } catch {
                print("Decode error:", error)
                completion(nil)
            }
        }

        task.resume()
    }
}
