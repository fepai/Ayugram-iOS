import Foundation

/// One installed plugin. Mirrors the exteraGram Android metadata surface:
/// id, name, version, author, description. Android `.plugin` files are Python
/// and cannot run on iOS — they are imported with `isAndroidPlugin` set and
/// stay disabled.
public struct AyuPluginRecord: Codable, Equatable {
    public var id: String
    public var name: String
    public var version: String
    public var author: String
    public var descriptionText: String
    public var fileName: String
    public var enabled: Bool
    public var failureCount: Int
    public var isAndroidPlugin: Bool

    public init(id: String, name: String, version: String, author: String, descriptionText: String, fileName: String, enabled: Bool, failureCount: Int = 0, isAndroidPlugin: Bool = false) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.descriptionText = descriptionText
        self.fileName = fileName
        self.enabled = enabled
        self.failureCount = failureCount
        self.isAndroidPlugin = isAndroidPlugin
    }
}

/// One entry of a plugin's declared settings schema, read back from the
/// runtime for the per-plugin settings screen.
public struct AyuPluginSetting: Codable, Equatable {
    public enum Kind: String, Codable {
        case toggle
        case text
        case selector
    }

    public var kind: Kind
    public var key: String
    public var title: String
    public var options: [String]

    public init(kind: Kind, key: String, title: String, options: [String] = []) {
        self.kind = kind
        self.key = key
        self.title = title
        self.options = options
    }
}

/// Persistent plugin registry and file storage. Plugin sources live in
/// Application Support/AyuPlugins; the registry itself is a JSON blob in
/// UserDefaults so enabled/failure state survives reinstalls of the source.
public final class AyuPluginStore {
    public static let shared = AyuPluginStore()

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let key = "swiftgram.ayu.plugins.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var plugins: [AyuPluginRecord] {
        lock.lock()
        defer { lock.unlock() }
        return defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([AyuPluginRecord].self, from: $0) } ?? []
    }

    private func write(_ plugins: [AyuPluginRecord]) {
        lock.lock()
        if let data = try? JSONEncoder().encode(plugins) {
            defaults.set(data, forKey: key)
        }
        lock.unlock()
    }

    public func record(id: String) -> AyuPluginRecord? {
        return plugins.first(where: { $0.id == id })
    }

    public func setEnabled(id: String, _ enabled: Bool) {
        var plugins = plugins
        if let index = plugins.firstIndex(where: { $0.id == id }) {
            plugins[index].enabled = enabled
            if enabled {
                plugins[index].failureCount = 0
            }
        }
        write(plugins)
    }

    public func registerFailure(id: String) -> AyuPluginRecord? {
        var plugins = plugins
        guard let index = plugins.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        plugins[index].failureCount += 1
        if plugins[index].failureCount >= 3 {
            // Safe mode: a plugin that crashes three loads in a row is disabled.
            plugins[index].enabled = false
        }
        write(plugins)
        return plugins[index]
    }

    public func remove(id: String) {
        var plugins = plugins
        if let index = plugins.firstIndex(where: { $0.id == id }) {
            let fileName = plugins[index].fileName
            plugins.remove(at: index)
            write(plugins)
            try? FileManager.default.removeItem(at: Self.pluginsDirectory().appendingPathComponent(fileName))
        }
    }

    public static func pluginsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("AyuPlugins", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Copies a picked file into the plugins directory and parses its metadata.
    /// Two formats are recognized: the fork's own JavaScript plugins with a
    /// `// ayu-plugin {…}` JSON header, and exteraGram Android `.plugin` files
    /// (Python) whose `__id__`-style constants are read for display only.
    public func install(from sourceURL: URL) throws -> AyuPluginRecord {
        let data = try Data(contentsOf: sourceURL)
        guard let source = String(data: data, encoding: .utf8), !source.isEmpty else {
            throw NSError(domain: "AyuPlugins", code: 1, userInfo: [NSLocalizedDescriptionKey: "The file is not a text plugin"])
        }
        guard source.count <= 2 * 1024 * 1024 else {
            throw NSError(domain: "AyuPlugins", code: 2, userInfo: [NSLocalizedDescriptionKey: "The plugin file is too large"])
        }

        var id = ""
        var name = ""
        var version = ""
        var author = ""
        var descriptionText = ""
        var isAndroid = false

        if let range = source.range(of: "// ayu-plugin "),
           let jsonData = source[range.upperBound...].prefix(while: { $0 != "\n" }).data(using: .utf8),
           let meta = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            id = meta["id"] as? String ?? ""
            name = meta["name"] as? String ?? ""
            version = meta["version"] as? String ?? "1.0"
            author = meta["author"] as? String ?? ""
            descriptionText = meta["description"] as? String ?? ""
        } else {
            // exteraGram Android metadata: top-level Python string constants.
            isAndroid = true
            id = Self.pythonConstant(source, name: "__id__") ?? ""
            name = Self.pythonConstant(source, name: "__name__") ?? ""
            version = Self.pythonConstant(source, name: "__version__") ?? "1.0"
            author = Self.pythonConstant(source, name: "__author__") ?? ""
            descriptionText = Self.pythonConstant(source, name: "__description__") ?? ""
        }

        guard !id.isEmpty, !name.isEmpty else {
            throw NSError(domain: "AyuPlugins", code: 3, userInfo: [NSLocalizedDescriptionKey: "The plugin metadata (id, name) is missing"])
        }

        var plugins = plugins
        if let existingIndex = plugins.firstIndex(where: { $0.id == id }) {
            // Reinstall replaces the source and keeps the enable state.
            let fileName = plugins[existingIndex].fileName
            let destination = Self.pluginsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destination)
            try data.write(to: destination)
            plugins[existingIndex].name = name
            plugins[existingIndex].version = version
            plugins[existingIndex].author = author
            plugins[existingIndex].descriptionText = descriptionText
            plugins[existingIndex].isAndroidPlugin = isAndroid
            plugins[existingIndex].failureCount = 0
            write(plugins)
            return plugins[existingIndex]
        }

        let fileName = "\(id).js"
        let destination = Self.pluginsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: destination)
        try data.write(to: destination)

        let record = AyuPluginRecord(id: id, name: name, version: version, author: author, descriptionText: descriptionText, fileName: fileName, enabled: !isAndroid, isAndroidPlugin: isAndroid)
        plugins.append(record)
        write(plugins)
        return record
    }

    public func source(for record: AyuPluginRecord) -> String? {
        let url = Self.pluginsDirectory().appendingPathComponent(record.fileName)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Reads a top-level `__name__ = "value"` string constant from a Python
    /// plugin file, for display of Android plugins that cannot run here.
    private static func pythonConstant(_ source: String, name: String) -> String? {
        guard let lineRange = source.range(of: "^\\s*\\(name)\\s*=", options: .regularExpression | .anchorsMatchLines) else {
            return nil
        }
        let line = String(source[lineRange.lowerBound...].prefix(while: { $0 != "\n" })).trimmingCharacters(in: .whitespaces)
        guard let start = line.firstIndex(where: { $0 == "\"" || $0 == "'" }),
              let end = line.lastIndex(where: { $0 == "\"" || $0 == "'" }),
              start < end else {
            return nil
        }
        return String(line[line.index(after: start)..<end])
    }
}
