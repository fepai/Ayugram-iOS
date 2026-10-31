import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import SGSimpleSettings
import SGStrings

/// Message Filters, AyuGram Android parity: regex rules that hide matching
/// messages from chats completely.
public func ayuGramFiltersScreen(context: AccountContext) -> ViewController {
    enum Section: Int32 {
        case general, filters
    }

    enum Option {
        case enable, caseInsensitive
    }

    enum Entry: ItemListNodeEntry {
        case toggle(id: Int, section: Section, option: Option, title: String, value: Bool)
        case action(id: Int, section: Section, title: String)
        case filter(id: Int, section: Section, filter: AyuGramMessageFilter)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .toggle(_, section, _, _, _), let .action(_, section, _), let .filter(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .toggle(id, _, _, _, _), let .action(id, _, _), let .filter(id, _, _), let .footer(id, _, _):
                return id
            }
        }

        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.stableId < rhs.stableId
        }

        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            let arguments = arguments as! Arguments
            switch self {
            case let .toggle(_, _, option, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(option, value)
                })
            case let .action(_, _, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.addFilter()
                })
            case let .filter(_, _, filter):
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: filter.pattern, label: filter.enabled ? arguments.onTitle : arguments.offTitle, sectionId: self.section, style: .blocks, action: {
                    arguments.editFilter(filter)
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let toggle: (Option, Bool) -> Void
        let addFilter: () -> Void
        let editFilter: (AyuGramMessageFilter) -> Void
        let onTitle: String
        let offTitle: String

        init(toggle: @escaping (Option, Bool) -> Void, addFilter: @escaping () -> Void, editFilter: @escaping (AyuGramMessageFilter) -> Void, onTitle: String, offTitle: String) {
            self.toggle = toggle
            self.addFilter = addFilter
            self.editFilter = editFilter
            self.onTitle = onTitle
            self.offTitle = offTitle
        }
    }

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    var pushController: ((ViewController) -> Void)?

    let arguments = Arguments(toggle: { option, value in
        switch option {
        case .enable:
            AyuGramFilters.shared.update(enabled: value)
        case .caseInsensitive:
            AyuGramFilters.shared.update(caseInsensitive: value)
        }
    }, addFilter: {
        pushController?(ayuGramFilterEditorScreen(context: context, filter: nil))
    }, editFilter: { filter in
        pushController?(ayuGramFilterEditorScreen(context: context, filter: filter))
    }, onTitle: s("Ayu.FilterOn"), offTitle: s("Ayu.FilterOff"))

    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        let filters = AyuGramFilters.shared
        var entries: [Entry] = []
        entries.append(.toggle(id: 10, section: .general, option: .enable, title: s("Ayu.FiltersEnable"), value: filters.enabled))
        entries.append(.toggle(id: 20, section: .general, option: .caseInsensitive, title: s("Ayu.FiltersCaseInsensitive"), value: filters.caseInsensitive))
        entries.append(.action(id: 30, section: .filters, title: s("Ayu.FilterAdd")))
        for (index, filter) in filters.filters.enumerated() {
            entries.append(.filter(id: 100 + index, section: .filters, filter: filter))
        }
        entries.append(.footer(id: 900, section: .filters, text: s("Ayu.FiltersFooter")))

        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(s("Ayu.FiltersTitle")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushController = { [weak controller] next in
        (controller?.navigationController as? NavigationController)?.pushViewController(next)
    }
    return controller
}

/// Add or edit one regex filter. Pass `nil` to create a new one. `saved` receives
/// the stored filter, or `nil` when it was deleted. Invalid patterns cannot be saved.
public func ayuGramFilterEditorScreen(context: AccountContext, filter: AyuGramMessageFilter?) -> ViewController {
    enum Section: Int32 {
        case pattern, options, actions
    }

    enum Entry: ItemListNodeEntry {
        case input(id: Int, section: Section, text: String)
        case toggle(id: Int, section: Section, title: String, value: Bool)
        case delete(id: Int, section: Section, title: String)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .input(_, section, _), let .toggle(_, section, _, _), let .delete(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .input(id, _, _), let .toggle(id, _, _, _), let .delete(id, _, _), let .footer(id, _, _):
                return id
            }
        }

        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.stableId < rhs.stableId
        }

        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            let arguments = arguments as! Arguments
            switch self {
            case let .input(_, _, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: arguments.placeholder, type: .regular(capitalization: false, autocorrection: false), maxLength: 256, sectionId: self.section, textUpdated: { value in
                    arguments.patternChanged(value)
                }, action: {})
            case let .toggle(_, _, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.enabledChanged(value)
                })
            case let .delete(_, _, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.deleteSelected()
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let patternChanged: (String) -> Void
        let enabledChanged: (Bool) -> Void
        let deleteSelected: () -> Void
        let placeholder: String

        init(patternChanged: @escaping (String) -> Void, enabledChanged: @escaping (Bool) -> Void, deleteSelected: @escaping () -> Void, placeholder: String) {
            self.patternChanged = patternChanged
            self.enabledChanged = enabledChanged
            self.deleteSelected = deleteSelected
            self.placeholder = placeholder
        }
    }

    var popController: (() -> Void)?

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    let patternPromise = ValuePromise<String>(filter?.pattern ?? "", ignoreRepeated: false)
    let enabledPromise = ValuePromise<Bool>(filter?.enabled ?? true, ignoreRepeated: false)
    var currentPattern = filter?.pattern ?? ""
    var currentEnabled = filter?.enabled ?? true

    let arguments = Arguments(patternChanged: { value in
        currentPattern = value
        patternPromise.set(value)
    }, enabledChanged: { value in
        currentEnabled = value
        enabledPromise.set(value)
    }, deleteSelected: {
        var remaining = AyuGramFilters.shared.filters
        if let filter {
            remaining.removeAll(where: { $0.id == filter.id })
            AyuGramFilters.shared.update(filters: remaining)
        }
        popController?()
    }, placeholder: s("Ayu.FilterPlaceholder"))

    let caseInsensitive = AyuGramFilters.shared.caseInsensitive

    var hasSaved = false
    let apply: () -> Void = {
        guard !hasSaved else { return }
        hasSaved = true
        let pattern = currentPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty, AyuGramFilters.validate(pattern, caseInsensitive: caseInsensitive) else { return }
        var filters = AyuGramFilters.shared.filters
        if var existing = filter {
            existing.pattern = pattern
            existing.enabled = currentEnabled
            if let index = filters.firstIndex(where: { $0.id == existing.id }) {
                filters[index] = existing
            } else {
                filters.append(existing)
            }
        } else {
            filters.append(AyuGramMessageFilter(pattern: pattern, enabled: currentEnabled))
        }
        AyuGramFilters.shared.update(enabled: true, filters: filters)
    }

    let signal = combineLatest(context.sharedContext.presentationData, patternPromise, enabledPromise)
    |> deliverOnMainQueue
    |> map { data, pattern, enabled -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        var entries: [Entry] = []
        entries.append(.input(id: 10, section: .pattern, text: pattern))

        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        let valid = !trimmed.isEmpty && AyuGramFilters.validate(trimmed, caseInsensitive: caseInsensitive)
        if trimmed.isEmpty {
            entries.append(.footer(id: 20, section: .pattern, text: s("Ayu.FilterHint")))
        } else if valid {
            entries.append(.footer(id: 20, section: .pattern, text: s("Ayu.FilterValid")))
        } else {
            entries.append(.footer(id: 20, section: .pattern, text: s("Ayu.FilterInvalid")))
        }

        if filter != nil {
            entries.append(.toggle(id: 30, section: .options, title: s("Ayu.FilterEnabled"), value: enabled))
            entries.append(.delete(id: 40, section: .actions, title: s("Ayu.FilterDelete")))
        } else {
            entries.append(.footer(id: 45, section: .options, text: s("Ayu.FiltersFooter")))
        }

        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(filter == nil ? s("Ayu.FilterAdd") : s("Ayu.FilterEdit")), leftNavigationButton: nil, rightNavigationButton: ItemListNavigationButton(content: .text(data.strings.Common_Done), style: .bold, enabled: true, action: {
            apply()
            popController?()
        }), backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    popController = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    controller.didDisappear = { _ in
        apply()
    }
    return controller
}
