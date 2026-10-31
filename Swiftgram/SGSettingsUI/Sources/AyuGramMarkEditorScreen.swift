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

public enum AyuMarkKind {
    case deleted
    case edited
}

/// Editor for the customizable message marks: the deleted mark (Android default
/// 🧹) and the "edited" label. Empty input restores the default; changes apply
/// immediately, like every other AyuGram toggle.
public func ayuGramMarkEditorScreen(context: AccountContext, kind: AyuMarkKind) -> ViewController {
    enum Section: Int32 {
        case input, presets, actions
    }

    enum Entry: ItemListNodeEntry {
        case input(id: Int, section: Section, text: String)
        case preset(id: Int, section: Section, emoji: String)
        case reset(id: Int, section: Section, title: String)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .input(_, section, _), let .preset(_, section, _), let .reset(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .input(id, _, _), let .preset(id, _, _), let .reset(id, _, _), let .footer(id, _, _):
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
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: "", type: .regular(capitalization: false, autocorrection: false), maxLength: 24, sectionId: self.section, textUpdated: { value in
                    arguments.textChanged(value)
                }, action: {})
            case let .preset(_, _, emoji):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: emoji, kind: .neutral, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.presetSelected(emoji)
                })
            case let .reset(_, _, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.resetSelected()
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let textChanged: (String) -> Void
        let presetSelected: (String) -> Void
        let resetSelected: () -> Void

        init(textChanged: @escaping (String) -> Void, presetSelected: @escaping (String) -> Void, resetSelected: @escaping () -> Void) {
            self.textChanged = textChanged
            self.presetSelected = presetSelected
            self.resetSelected = resetSelected
        }
    }

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    let presets = ["🧹", "🗑️", "👻", "❌", "🚫", "💀", "🫥"]
    let defaultValue: String
    let title: String
    let footer: String
    switch kind {
    case .deleted:
        defaultValue = "🧹"
        title = s("Ayu.DeletedMark")
        footer = s("Ayu.DeletedMarkInfo")
    case .edited:
        defaultValue = ""
        title = s("Ayu.EditedMark")
        footer = s("Ayu.EditedMarkInfo")
    }
    let currentValue: String
    switch kind {
    case .deleted:
        currentValue = AyuGramSettings.shared.extra.deletedMark
    case .edited:
        currentValue = AyuGramSettings.shared.extra.editedMark
    }

    let textPromise = ValuePromise<String>(currentValue, ignoreRepeated: false)

    func store(_ raw: String) {
        textPromise.set(raw)
        switch kind {
        case .deleted:
            AyuGramSettings.shared.updateExtra { $0.deletedMark = String(raw.prefix(24)) }
        case .edited:
            AyuGramSettings.shared.updateExtra { $0.editedMark = String(raw.prefix(24)) }
        }
    }

    let arguments = Arguments(textChanged: { value in
        store(value)
    }, presetSelected: { emoji in
        store(emoji)
    }, resetSelected: {
        store(defaultValue)
    })

    let signal = combineLatest(context.sharedContext.presentationData, textPromise)
    |> deliverOnMainQueue
    |> map { data, text -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        var entries: [Entry] = []
        entries.append(.input(id: 10, section: .input, text: text))
        for (index, emoji) in presets.enumerated() {
            entries.append(.preset(id: 100 + index, section: .presets, emoji: emoji))
        }
        entries.append(.reset(id: 200, section: .actions, title: s("Ayu.MarkReset")))
        entries.append(.footer(id: 300, section: .actions, text: footer))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
