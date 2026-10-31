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

/// Message Saving Preferences, AyuGram Android parity: choose which chat types
/// keep deleted and edited messages locally.
public func ayuGramSavingPreferencesScreen(context: AccountContext) -> ViewController {
    enum Section: Int32 {
        case media
    }

    enum Toggle: Equatable {
        case privateChats, publicGroups, privateGroups, publicChannels, privateChannels
    }

    enum Entry: ItemListNodeEntry {
        case header(id: Int, section: Section, text: String)
        case toggle(id: Int, section: Section, key: Toggle, title: String, value: Bool)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .header(_, section, _), let .toggle(_, section, _, _, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .header(id, _, _), let .toggle(id, _, _, _, _), let .footer(id, _, _):
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
            case let .toggle(_, _, key, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(key, value)
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    final class Arguments {
        let toggle: (Toggle, Bool) -> Void

        init(toggle: @escaping (Toggle, Bool) -> Void) {
            self.toggle = toggle
        }
    }

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    let arguments = Arguments(toggle: { key, value in
        AyuGramSettings.shared.updateExtra { extra in
            switch key {
            case .privateChats:
                extra.saveInPrivateChats = value
            case .publicGroups:
                extra.saveInPublicGroups = value
            case .privateGroups:
                extra.saveInPrivateGroups = value
            case .publicChannels:
                extra.saveInPublicChannels = value
            case .privateChannels:
                extra.saveInPrivateChannels = value
            }
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        let extra = AyuGramSettings.shared.extra
        let entries: [Entry] = [
            .header(id: 10, section: .media, text: s("Ayu.SavingMediaHeader")),
            .toggle(id: 20, section: .media, key: .privateChats, title: s("Ayu.SavingPrivateChats"), value: extra.saveInPrivateChats),
            .toggle(id: 30, section: .media, key: .publicGroups, title: s("Ayu.SavingPublicGroups"), value: extra.saveInPublicGroups),
            .toggle(id: 40, section: .media, key: .privateGroups, title: s("Ayu.SavingPrivateGroups"), value: extra.saveInPrivateGroups),
            .toggle(id: 50, section: .media, key: .publicChannels, title: s("Ayu.SavingPublicChannels"), value: extra.saveInPublicChannels),
            .toggle(id: 60, section: .media, key: .privateChannels, title: s("Ayu.SavingPrivateChannels"), value: extra.saveInPrivateChannels),
            .footer(id: 70, section: .media, text: s("Ayu.SavingFooter"))
        ]
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(s("Ayu.SavingPreferences")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(data), entries: entries, style: .blocks, animateChanges: true)
        return (state, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
