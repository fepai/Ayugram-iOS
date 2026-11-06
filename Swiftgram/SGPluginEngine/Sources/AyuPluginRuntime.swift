import Foundation
import JavaScriptCore
import Postbox
import TelegramCore

/// The JavaScriptCore plugin runtime. Mirrors the exteraGram Android engine's
/// architecture (install from file, enable/disable, per-plugin settings,
/// commands, send-message hooks, menu items, safe mode) with an iOS-native
/// JavaScript API. Android Python plugins do not run here.
public final class AyuPluginRuntime {
    public static let shared = AyuPluginRuntime()

    struct LoadedPlugin {
        var record: AyuPluginRecord
        var hooks: [JSValue]
        var commands: [String: JSValue]
        var menuItems: [(title: String, handler: JSValue)]
        var settingsSchema: [AyuPluginSetting]
    }

    private let lock = NSLock()
    private var loaded: [String: LoadedPlugin] = [:]
    private weak var account: Account?
    /// The chat the current outgoing batch belongs to; `plugin.reply` targets it.
    private var currentPeerId: PeerId?

    public func settingValue(_ pluginId: String, key: String) -> String? {
        return UserDefaults.standard.string(forKey: Self.settingsKey(pluginId, key))
    }

    public func setSettingValue(_ pluginId: String, key: String, value: String) {
        UserDefaults.standard.set(value, forKey: Self.settingsKey(pluginId, key))
    }

    public func settingsSchema(_ pluginId: String) -> [AyuPluginSetting] {
        lock.lock()
        defer { lock.unlock() }
        return loaded[pluginId]?.settingsSchema ?? []
    }

    private static func settingsKey(_ pluginId: String, _ settingKey: String) -> String {
        return "swiftgram.ayu.plugin.\(pluginId).\(settingKey)"
    }

    /// Loads every enabled plugin and registers the outgoing-message processor.
    /// Called once from the app delegate when the interface is ready.
    public func activate(account: Account) {
        self.account = account
        lock.lock()
        let hadLoaded = !loaded.isEmpty
        loaded.removeAll()
        lock.unlock()
        let _ = hadLoaded
        for record in AyuPluginStore.shared.plugins where record.enabled && !record.isAndroidPlugin {
            self.load(record)
        }
        _ayuPluginProcessOutgoing = { [weak self] account, peerId, messages in
            return self?.processOutgoing(account: account, peerId: peerId, messages: messages) ?? messages
        }
    }

    public func unload(id: String) {
        lock.lock()
        let _ = loaded.removeValue(forKey: id)
        lock.unlock()
    }

    /// Loads one plugin: builds its JS context, bridges the `plugin` API and
    /// runs the source. Exceptions feed the safe-mode failure counter.
    private func load(_ record: AyuPluginRecord) {
        guard let source = AyuPluginStore.shared.source(for: record) else {
            return
        }
        guard let context = JSContext() else {
            return
        }
        context.name = record.id
        var hooks: [JSValue] = []
        var commands: [String: JSValue] = [:]
        var menuItems: [(title: String, handler: JSValue)] = []
        var settingsSchema: [AyuPluginSetting] = []

        let runtime = self
        let pluginId = record.id
        let pluginObject = JSValue(newObjectIn: context)!

        let undefined: JSValue = JSValue(undefinedIn: context)

        pluginObject[@"log"] = { (a: JSValue, b: JSValue) -> JSValue in
            var parts: [String] = []
            if !a.isUndefined {
                parts.append(a.toString())
            }
            if !b.isUndefined {
                parts.append(b.toString())
            }
            Logger.shared.log("Plugin/\(record.name)", parts.joined(separator: " "))
            return undefined
        }
        pluginObject[@"addOnSendMessageHook"] = { (value: JSValue) -> JSValue in
            hooks.append(value)
            return undefined
        }
        pluginObject[@"addCommand"] = { (prefix: JSValue, handler: JSValue) -> JSValue in
            commands[prefix.toString()] = handler
            return undefined
        }
        pluginObject[@"addMessageMenuItem"] = { (title: JSValue, handler: JSValue) -> JSValue in
            menuItems.append((title.toString(), handler))
            return undefined
        }
        pluginObject[@"createSettings"] = { (value: JSValue) -> JSValue in
            if let array = value.toArray() as? [[String: Any]] {
                for entry in array {
                    let kindString = entry["type"] as? String ?? "text"
                    let kind: AyuPluginSetting.Kind
                    switch kindString {
                    case "switch": kind = .toggle
                    case "selector": kind = .selector
                    default: kind = .text
                    }
                    guard let key = entry["key"] as? String, !key.isEmpty else {
                        continue
                    }
                    let title = entry["title"] as? String ?? key
                    let options = entry["options"] as? [String] ?? []
                    settingsSchema.append(AyuPluginSetting(kind: kind, key: key, title: title, options: options))
                }
            }
            return undefined
        }
        pluginObject[@"reply"] = { (text: JSValue) -> JSValue in
            if let account = runtime.account, let peerId = runtime.currentPeerId {
                let replyText = text.toString()
                if !replyText.isEmpty {
                    let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: replyText, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
                }
            }
            return undefined
        }
        pluginObject[@"httpGet"] = { (url: JSValue, callback: JSValue) -> JSValue in
            guard let urlString = url.toString() as String?, let url = URL(string: urlString) else {
                callback.call(withArguments: ["", "invalid url"])
                return undefined
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 20.0
            URLSession.shared.dataTask(with: request) { data, _, _ in
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                DispatchQueue.main.async {
                    callback.call(withArguments: [body, NSNull()])
                }
            }.resume()
            return undefined
        }

        context.setObject(pluginObject, forKeyedSubscript: "plugin" as NSString)

        let settingsObject = JSValue(newObjectIn: context)!
        settingsObject[@"get"] = { (key: JSValue) -> JSValue in
            if let value = runtime.settingValue(pluginId, key: key.toString()) {
                return JSValue(object: value, in: context)
            }
            return JSValue(undefinedIn: context)
        }
        settingsObject[@"set"] = { (key: JSValue, value: JSValue) -> JSValue in
            runtime.setSettingValue(pluginId, key: key.toString(), value: value.toString())
            return undefined
        }
        pluginObject[@"settings"] = settingsObject

        var loadError: JSValue?
        context.exceptionHandler = { (_, exception) in
            loadError = exception
        }
        context.evaluateScript(source)
        if loadError == nil {
            loadError = context.exception
        }

        if let error = loadError {
            Logger.shared.log("Plugin/\(record.name)", "load failed: \(error)")
            let updated = AyuPluginStore.shared.registerFailure(id: record.id)
            if let updated, updated.failureCount >= 3 {
                Logger.shared.log("Plugin/\(record.name)", "safe mode: disabled after repeated failures")
            }
            return
        }

        if let onload = pluginObject.objectForKeyedSubscript("onload"), !onload.isUndefined {
            onload.call(withArguments: [])
            if let error = context.exception {
                Logger.shared.log("Plugin/\(record.name)", "onload failed: \(error)")
                let _ = AyuPluginStore.shared.registerFailure(id: record.id)
                return
            }
        }

        lock.lock()
        loaded[record.id] = LoadedPlugin(record: record, hooks: hooks, commands: commands, menuItems: menuItems, settingsSchema: settingsSchema)
        lock.unlock()
        Logger.shared.log("Plugin/\(record.name)", "loaded (hooks: \(hooks.count), commands: \(commands.count))")
    }

    /// The outgoing-message processor registered with TelegramCore. Text
    /// messages may be rewritten by send hooks; plugin commands cancel the
    /// original message and enqueue the handler's reply.
    private func processOutgoing(account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)]) -> [(Bool, EnqueueMessage)] {
        self.currentPeerId = peerId

        var result: [(Bool, EnqueueMessage)] = []
        var replies: [String] = []
        var cancelled = false

        loop: for (transformedMedia, message) in messages {
            guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message else {
                result.append((transformedMedia, message))
                continue
            }

            if let command = self.matchingCommand(for: text) {
                if let reply = self.runCommand(command, args: String(text.dropFirst(command.prefix.count)).trimmingCharacters(in: .whitespaces)) {
                    replies.append(reply)
                }
                cancelled = true
                continue
            }

            var currentText = text
            for hook in self.allHooks() {
                guard let hookResult = hook.call(withArguments: [currentText]) else {
                    continue
                }
                if hookResult.isString {
                    let rewritten = hookResult.toString()
                    if rewritten != currentText {
                        currentText = rewritten
                    }
                } else if let object = hookResult.toDictionary() {
                    let strategy = object["strategy"] as? String ?? "keep"
                    if strategy == "cancel" {
                        cancelled = true
                        continue loop
                    }
                    if strategy == "modify", let newText = object["text"] as? String {
                        currentText = newText
                    }
                }
            }

            if currentText != text {
                result.append((transformedMedia, .message(text: currentText, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)))
            } else {
                result.append((transformedMedia, message))
            }
        }

        for reply in replies {
            let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: reply, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
        }
        if cancelled {
            self.currentPeerId = nil
        }

        return result
    }

    private struct MatchedCommand {
        var prefix: String
        var handler: JSValue
    }

    private func matchingCommand(for text: String) -> MatchedCommand? {
        guard text.hasPrefix(".") else {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        for (_, plugin) in loaded {
            for (prefix, handler) in plugin.commands where text.hasPrefix(prefix) {
                return MatchedCommand(prefix: prefix, handler: handler)
            }
        }
        return nil
    }

    private func runCommand(_ command: MatchedCommand, args: String) -> String? {
        let result = command.handler.call(withArguments: [args])
        if let result, result.isString {
            return result.toString()
        }
        return nil
    }

    private func allHooks() -> [JSValue] {
        lock.lock()
        defer { lock.unlock() }
        return loaded.values.flatMap { $0.hooks }
    }

    /// Menu items registered by plugins for a message context menu.
    public func messageMenuItems() -> [(pluginId: String, pluginName: String, title: String, handler: JSValue)] {
        lock.lock()
        defer { lock.unlock() }
        var items: [(String, String, String, JSValue)] = []
        for (_, plugin) in loaded {
            for menuItem in plugin.menuItems {
                items.append((plugin.record.id, plugin.record.name, menuItem.title, menuItem.handler))
            }
        }
        return items
    }

    /// Runs a plugin menu item with a small message context dictionary.
    public func runMessageMenuItem(_ handler: JSValue, message: Message) {
        let context: [String: Any] = [
            "messageId": message.id.id,
            "peerId": message.id.peerId.toInt64(),
            "text": message.text
        ]
        handler.call(withArguments: [context])
    }
}
