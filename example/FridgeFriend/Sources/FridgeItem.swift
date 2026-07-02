import Foundation
import SwiftData

/// Where an item physically lives. Persisted as its raw string (see
/// `FridgeItem.locationRaw`) so schema migrations stay trivial and the value
/// remains sortable/filterable in predicates.
enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case fridge
    case freezer
    case pantry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        case .pantry: "Pantry"
        }
    }

    var icon: String {
        switch self {
        case .fridge: "refrigerator"
        case .freezer: "snowflake"
        case .pantry: "cabinet"
        }
    }
}

/// Derived, never persisted. Case order defines section order in the list:
/// act-on-it-now first, dead-weight last.
enum ExpiryStatus: CaseIterable, Hashable {
    case expiringSoon
    case fresh
    case expired
}

@Model
final class FridgeItem {
    var name: String = ""
    var quantity: Int = 1
    var locationRaw: String = StorageLocation.fridge.rawValue
    var expiryDate: Date = Date.now
    var addedDate: Date = Date.now
    var notes: String = ""

    init(
        name: String,
        quantity: Int = 1,
        location: StorageLocation = .fridge,
        expiryDate: Date,
        notes: String = ""
    ) {
        self.name = name
        self.quantity = quantity
        self.locationRaw = location.rawValue
        self.expiryDate = expiryDate
        self.addedDate = .now
        self.notes = notes
    }

    /// Typed facade over the raw stored string. An unknown raw value (from a
    /// future schema version) degrades to `.fridge` instead of crashing.
    var location: StorageLocation {
        get { StorageLocation(rawValue: locationRaw) ?? .fridge }
        set { locationRaw = newValue.rawValue }
    }
}

// MARK: - Expiry math

extension FridgeItem {
    /// Items expiring within this many days (inclusive of today) count as
    /// "expiring soon". Three days covers a normal shopping cadence.
    static let soonWindowDays = 3

    /// Whole-day difference between the reference date and the expiry date,
    /// computed on day boundaries so the result never shifts within a day.
    /// 0 = expires today, negative = already expired.
    func daysUntilExpiry(asOf reference: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// An item is good through the end of its expiry day; "expires today"
    /// is a call to action, not a write-off, so it lands in `.expiringSoon`.
    func expiryStatus(asOf reference: Date = .now, calendar: Calendar = .current) -> ExpiryStatus {
        let days = daysUntilExpiry(asOf: reference, calendar: calendar)
        if days < 0 { return .expired }
        if days <= Self.soonWindowDays { return .expiringSoon }
        return .fresh
    }

    /// Short badge text: "3d ago", "Yesterday", "Today", "Tomorrow", "5d left".
    func expiryBadgeText(asOf reference: Date = .now, calendar: Calendar = .current) -> String {
        let days = daysUntilExpiry(asOf: reference, calendar: calendar)
        switch days {
        case ..<(-1): return "\(-days)d ago"
        case -1: return "Yesterday"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "\(days)d left"
        }
    }
}
