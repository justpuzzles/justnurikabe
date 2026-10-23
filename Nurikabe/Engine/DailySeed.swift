//
//  DailySeed.swift
//  Nurikabe
//
//  One board per calendar day, the same for everyone: the seed is a hash of
//  the date, never of the device or the clock time. Size and tier follow the
//  weekday so the week climbs from gentle to severe.
//

import Foundation

nonisolated struct DayKey: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Gregorian in the device's time zone. The daily still turns over at the
    /// player's midnight, but year, month and day are always Gregorian, so a
    /// phone set to the Japanese or Buddhist calendar gets the same board and
    /// weekday as everyone else.
    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// The day `date` falls on in `calendar` (local time by default: a
    /// player's daily changes at their midnight).
    init(_ date: Date, calendar: Calendar = DayKey.localCalendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 2026
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    static func today(calendar: Calendar = DayKey.localCalendar) -> DayKey { DayKey(Date(), calendar: calendar) }

    static func < (a: DayKey, b: DayKey) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// Gregorian weekday, 1 = Sunday … 7 = Saturday.
    var weekday: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        return calendar.component(.weekday, from: date)
    }

    /// The previous calendar day.
    var previous: DayKey {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        let before = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return DayKey(before, calendar: calendar)
    }
}

nonisolated enum DailySeed {

    /// FNV-1a over the date string, salted with the game's name so the
    /// family's dailies never share a seed.
    static func seed(for day: DayKey) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "nurikabe-daily-\(day)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Mon gentle → Sun severe, all on 7×7 (free size, so the daily is for
    /// everyone).
    static func tier(for day: DayKey) -> Difficulty {
        switch day.weekday {
        case 2: .gentle      // Monday
        case 3: .steady
        case 4: .steady
        case 5: .sharp
        case 6: .sharp
        case 7: .deep        // Saturday
        default: .severe     // Sunday
        }
    }

    static let size: BoardSize = .seven

    static func generate(for day: DayKey, isCancelled: () -> Bool = { false }) -> GenerationResult {
        NurikabeGenerator.generate(size: size, tier: tier(for: day), seed: seed(for: day),
                                   isCancelled: isCancelled)
    }
}
