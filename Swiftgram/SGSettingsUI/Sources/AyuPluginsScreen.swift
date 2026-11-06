import Foundation
import UIKit
import UniformTypeIdentifiers
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import SGSimpleSettings
import SGPluginEngine
import SGStrings

/// The plugin manager: install JavaScript plugins from files, toggle them,
/// open per-plugin settings, delete. The exteraGram Android flow, on iOS.
public func ayuGramPluginsScreen(context: AccountContext) -> ViewController {
    enum Section: Int32 {
        case plugins, add
    }

    enum Entry: ItemListNodeEntry {
        case header(id: Int, section: Section, text: String)
        case plugin(id: Int, section: Section, record: AyuPluginRecord)
        case action(id: Int, section: Section, title: String)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .header(_, section, _), let .plugin(_, section, _), let .action(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .header(id, _, _), let .plugin(id, _, _), let .action(id, _, _), let .footer(id, _, _):
                return id
            }
        }

        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.stableId < rhs.stableId
        }

        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            let arguments = arguments as! Arguments
            switch self {
            case let .header(_, _, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .plugin(_, _, record):
                let title = record.isAndroidPlugin ? "\(record.name) · Android" : record.name
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: record.isAndroidPlugin ? arguments.androidNote : "\(arguments.versionTitle) \(record.version)", value: record.enabled, enabled: !record.isAndroidPlugin, maximumNumberOfLines: 0, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.setEnabled(record, value)
                }, action: {
                    arguments.open(record)
                })
            case let .action(_, _, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.addFromFile()
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let setEnabled: (AyuPluginRecord, Bool) -> Void
        let open: (AyuPluginRecord) -> Void
        let addFromFile: () -> Void
        let androidNote: String
        let versionTitle: String

        init(setEnabled: @escaping (AyuPluginRecord, Bool) -> Void, open: @escaping (AyuPluginRecord) -> Void, addFromFile: @escaping () -> Void, androidNote: String, versionTitle: String) {
            self.setEnabled = setEnabled
            self.open = open
            self.addFromFile = addFromFile
            self.androidNote = androidNote
            self.versionTitle = versionTitle
        }
    }

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?

    func reloadRuntime() {
        AyuPluginRuntime.shared.activate(account: context.account)
    }

    var pickerSheet: AyuPluginDocumentPicker?

    let arguments = Arguments(setEnabled: { record, value in
        AyuPluginStore.shared.setEnabled(id: record.id, value)
        reloadRuntime()
    }, open: { record in
        pushController?(ayuGramPluginDetailScreen(context: context, record: record))
    }, addFromFile: {
        let types: [UTType] = [
            UTType(filenameExtension: "js") ?? .data,
            UTType(filenameExtension: "plugin") ?? .data,
            UTType(filenameExtension: "py") ?? .data
        ]
        let picker = AyuPluginDocumentPicker(forOpeningContentTypes: types, asCopy: true)
        if context.sharedContext.currentPresentationData.with({ $0 }).theme.overallDarkAppearance {
            picker.overrideUserInterfaceStyle = .dark
        }
        picker.picked = { url in
            do {
                let record = try AyuPluginStore.shared.install(from: url)
                reloadRuntime()
                let data = context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                if record.isAndroidPlugin {
                    text = i18n("Ayu.PluginInstalledAndroid", data.strings.baseLanguageCode)
                } else {
                    text = i18n("Ayu.PluginInstalled", data.strings.baseLanguageCode).replacingOccurrences(of: "%@", with: record.name)
                }
                presentController?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]))
            } catch {
                let data = context.sharedContext.currentPresentationData.with { $0 }
                let message = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? "Error"
                presentController?(textAlertController(context: context, title: i18n("Ayu.PluginInstallFailed", data.strings.baseLanguageCode), text: message, actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]))
            }
        }
        pickerSheet = picker
        presentController?(picker)
    }, androidNote: s("Ayu.PluginAndroidNote"), versionTitle: s("Ayu.PluginVersion"))

    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        var entries: [Entry] = []
        entries.append(.header(id: 10, section: .plugins, text: s("Ayu.PluginsSection")))
        for (index, record) in AyuPluginStore.shared.plugins.enumerated() {
            entries.append(.plugin(id: 100 + index, section: .plugins, record: record))
        }
        entries.append(.action(id: 500, section: .add, title: s("Ayu.PluginAdd")))
        entries.append(.footer(id: 510, section: .add, text: s("Ayu.PluginsFooter")))

        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(s("Ayu.PluginsSection")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushController = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    presentController = { [weak controller] next in
        controller?.present(next, in: .window(.root))
    }
    return controller
}

/// Picks a plugin file. The picker is its own delegate, like the chat importer.
private final class AyuPluginDocumentPicker: UIDocumentPickerViewController, UIDocumentPickerDelegate {
    var picked: ((URL) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let picked = self.picked
        self.picked = nil
        if let url = urls.first {
            picked?(url)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.picked = nil
    }
}

/// Info, per-plugin settings (declared by the plugin's createSettings schema)
/// and deletion for one installed plugin.
public func ayuGramPluginDetailScreen(context: AccountContext, record: AyuPluginRecord) -> ViewController {
    enum Section: Int32 {
        case info, settings, actions
    }

    enum Entry: ItemListNodeEntry {
        case header(id: Int, section: Section, text: String)
        case text(id: Int, section: Section, text: String)
        case toggle(id: Int, section: Section, setting: AyuPluginSetting, title: String, value: Bool)
        case picker(id: Int, section: Section, setting: AyuPluginSetting, title: String, label: String)
        case input(id: Int, section: Section, setting: AyuPluginSetting, title: String, value: String)
        case action(id: Int, section: Section, title: String)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .header(_, section, _), let .text(_, section, _), let .toggle(_, section, _, _, _), let .picker(_, section, _, _, _), let .input(_, section, _, _, _), let .action(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .header(id, _, _), let .text(id, _, _), let .toggle(id, _, _, _, _), let .picker(id, _, _, _, _), let .input(id, _, _, _, _), let .action(id, _, _), let .footer(id, _, _):
                return id
            }
        }

        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.stableId < rhs.stableId
        }

        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            let arguments = arguments as! Arguments
            switch self {
            case let .header(_, _, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .text(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .toggle(_, _, setting, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.setSetting(setting, value ? "1" : "0")
                })
            case let .picker(_, _, setting, title, label):
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.pickSetting(setting)
                })
            case let .input(_, _, setting, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.editSetting(setting)
                })
            case let .action(_, _, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.delete()
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let setSetting: (AyuPluginSetting, String) -> Void
        let pickSetting: (AyuPluginSetting) -> Void
        let editSetting: (AyuPluginSetting) -> Void
        let delete: () -> Void

        init(setSetting: @escaping (AyuPluginSetting, String) -> Void, pickSetting: @escaping (AyuPluginSetting) -> Void, editSetting: @escaping (AyuPluginSetting) -> Void, delete: @escaping () -> Void) {
            self.setSetting = setSetting
            self.pickSetting = pickSetting
            self.editSetting = editSetting
            self.delete = delete
        }
    }

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?
    var popController: (() -> Void)?

    let arguments = Arguments(setSetting: { setting, value in
        AyuPluginRuntime.shared.setSettingValue(record.id, key: setting.key, value: value)
    }, pickSetting: { setting in
        let data = context.sharedContext.currentPresentationData.with { $0 }
        let sheet = ActionSheetController(presentationData: data)
        var items: [ActionSheetItem] = []
        let current = AyuPluginRuntime.shared.settingValue(record.id, key: setting.key)
        for option in setting.options {
            let selected = option == current
            items.append(ActionSheetButtonItem(title: (selected ? "✓ " : "") + option, color: .accent, action: { [weak sheet] in
                sheet?.dismissAnimated()
                AyuPluginRuntime.shared.setSettingValue(record.id, key: setting.key, value: option)
            }))
        }
        sheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in sheet?.dismissAnimated() })])
        ])
        presentController?(sheet)
    }, editSetting: { setting in
        pushController?(ayuGramSingleValueScreen(context: context, title: setting.title, placeholder: "", initial: AyuPluginRuntime.shared.settingValue(record.id, key: setting.key) ?? "", maxLength: 256, apply: { value in
            AyuPluginRuntime.shared.setSettingValue(record.id, key: setting.key, value: value)
        }))
    }, delete: {
        let data = context.sharedContext.currentPresentationData.with { $0 }
        presentController?(textAlertController(context: context, title: i18n("Ayu.PluginDelete", data.strings.baseLanguageCode), text: i18n("Ayu.PluginDeleteInfo", data.strings.baseLanguageCode), actions: [
            TextAlertAction(type: .genericAction, title: data.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: data.strings.Common_Delete, action: {
                AyuPluginRuntime.shared.unload(id: record.id)
                AyuPluginStore.shared.remove(id: record.id)
                popController?()
            })
        ]))
    })

    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        var entries: [Entry] = []

        entries.append(.header(id: 10, section: .info, text: s("Ayu.PluginInfoHeader")))
        var info = s("Ayu.PluginVersion") + " \(record.version)"
        if !record.author.isEmpty {
            info += "\n" + s("Ayu.PluginAuthor") + " \(record.author)"
        }
        if !record.descriptionText.isEmpty {
            info += "\n\n" + record.descriptionText
        }
        if record.isAndroidPlugin {
            info += "\n\n" + s("Ayu.PluginAndroidNote")
        }
        entries.append(.text(id: 20, section: .info, text: info))

        let schema = AyuPluginRuntime.shared.settingsSchema(record.id)
        if !schema.isEmpty {
            entries.append(.header(id: 100, section: .settings, text: s("Ayu.PluginSettingsHeader")))
            for (index, setting) in schema.enumerated() {
                switch setting.kind {
                case .toggle:
                    let value = AyuPluginRuntime.shared.settingValue(record.id, key: setting.key) == "1"
                    entries.append(.toggle(id: 200 + index, section: .settings, setting: setting, title: setting.title, value: value))
                case .selector:
                    let value = AyuPluginRuntime.shared.settingValue(record.id, key: setting.key) ?? setting.options.first ?? ""
                    entries.append(.picker(id: 200 + index, section: .settings, setting: setting, title: setting.title, label: value))
                case .text:
                    let value = AyuPluginRuntime.shared.settingValue(record.id, key: setting.key) ?? ""
                    entries.append(.input(id: 200 + index, section: .settings, setting: setting, title: setting.title, value: value))
                }
            }
        }

        entries.append(.action(id: 900, section: .actions, title: s("Ayu.PluginDelete")))

        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(record.name), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushController = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    presentController = { [weak controller] next in
        controller?.present(next, in: .window(.root))
    }
    popController = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    return controller
}
