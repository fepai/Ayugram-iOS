import Foundation

/// One AyuGram regex filter: messages whose text matches are hidden from the chat.
public struct AyuGramMessageFilter: Codable, Equatable {
    public var id: String
    public var pattern: String
    public var enabled: Bool

    public init(id: String = UUID().uuidString, pattern: String, enabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.enabled = enabled
    }
}

/// Regex-based message filters, AyuGram Android parity. Enabled expressions are
/// kept precompiled in memory: `matches` runs on the chat rendering hot path.
public final class AyuGramFilters {
    public static let shared = AyuGramFilters()
    /// Posted next to `AyuGramSettings.didChange` so open screens rebuild their lists.
    public static let didChange = Notification.Name("Swiftgram.AyuGramFilters.didChange")

    private struct Storage: Codable {
        var enabled = false
        var caseInsensitive = true
        var filters: [AyuGramMessageFilter] = []
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let key = "swiftgram.ayuGram.filters.v1"
    private var storage: Storage
    private var compiled: [NSRegularExpression] = []

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storage = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Storage.self, from: $0) } ?? Storage()
        lock.lock()
        rebuildLocked()
        lock.unlock()
    }

    public var enabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.enabled
    }

    public var caseInsensitive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.caseInsensitive
    }

    public var filters: [AyuGramMessageFilter] {
        lock.lock()
        defer { lock.unlock() }
        return storage.filters
    }

    /// Number of active filters, shown as the "N filters" value on the settings row.
    public var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        guard storage.enabled else { return 0 }
        return storage.filters.filter { $0.enabled }.count
    }

    public func update(enabled: Bool? = nil, caseInsensitive: Bool? = nil, filters: [AyuGramMessageFilter]? = nil) {
        lock.lock()
        if let enabled {
            storage.enabled = enabled
        }
        if let caseInsensitive {
            storage.caseInsensitive = caseInsensitive
        }
        if let filters {
            storage.filters = filters
        }
        if let data = try? JSONEncoder().encode(storage) {
            defaults.set(data, forKey: key)
        }
        rebuildLocked()
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChange, object: self)
        NotificationCenter.default.post(name: AyuGramSettings.didChange, object: AyuGramSettings.shared)
    }

    /// Synchronous hot-path check: does the message text match any active filter?
    public func matches(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        lock.lock()
        let expressions = compiled
        lock.unlock()
        if expressions.isEmpty {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        for expression in expressions {
            if expression.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    public static func validate(_ pattern: String, caseInsensitive: Bool) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        return (try? NSRegularExpression(pattern: pattern, options: options)) != nil
    }

    /// Caller holds the lock.
    private func rebuildLocked() {
        compiled = []
        guard storage.enabled else { return }
        let options: NSRegularExpression.Options = storage.caseInsensitive ? [.caseInsensitive] : []
        for filter in storage.filters where filter.enabled {
            if let expression = try? NSRegularExpression(pattern: filter.pattern, options: options) {
                compiled.append(expression)
            }
        }
    }
}
