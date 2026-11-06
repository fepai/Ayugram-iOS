import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import SGStrings

/// A one-field text editor used for small customizable values (the double-tap
/// reaction emoji and similar). Changes apply immediately, like every other
/// AyuGram option.
public func ayuGramSingleValueScreen(context: AccountContext, title: String, placeholder: String, initial: String, maxLength: Int, apply: @escaping (String) -> Void) -> ViewController {
    enum Section: Int32 {
        case input, footer
    }

    enum Entry: ItemListNodeEntry {
        case input(id: Int, section: Section, text: String)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .input(_, section, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .input(id, _, _), let .footer(id, _, _):
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
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), maxLength: maxLength, sectionId: self.section, textUpdated: { value in
                    arguments.textChanged(value)
                }, action: {})
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let textChanged: (String) -> Void

        init(textChanged: @escaping (String) -> Void) {
            self.textChanged = textChanged
        }
    }

    let textPromise = ValuePromise<String>(initial, ignoreRepeated: false)

    let arguments = Arguments(textChanged: { value in
        textPromise.set(value)
        apply(String(value.prefix(maxLength)))
    })

    let signal = combineLatest(context.sharedContext.presentationData, textPromise.get())
    |> deliverOnMainQueue
    |> map { data, text -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        let entries: [Entry] = [
            .input(id: 10, section: .input, text: text),
            .footer(id: 20, section: .footer, text: placeholder)
        ]
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
