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

    func fetchMonthlyPrayerTimes(for region: String = "Toshkent", completion: @escaping ([DailyPrayerTime]?) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let currentMonth = dateFormatter.string(from: Date())

        let urlStr = "https://namoz-vaqtlari.more-info.uz:444/api/GetMonthlyPrayTimes/\(region)/\(currentMonth)"
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
