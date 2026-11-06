import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import SettingsUI
import SGSimpleSettings
import SGStrings

/// Appearance, gestures and effects: exteraGram-inspired customization hub.
/// App icons and the badge reuse the existing pickers and stores.
public func ayuGramAppearanceScreen(context: AccountContext) -> ViewController {
    enum Section: Int32 {
        case general, marks, gestures
    }

    enum Link: Equatable {
        case appIcon, deletedMark, editedMark
    }

    enum Entry: ItemListNodeEntry {
        case header(id: Int, section: Section, text: String)
        case link(id: Int, section: Section, link: Link, symbol: String, title: String)
        case picker(id: Int, section: Section, key: AyuAppearancePicker, title: String, label: String)
        case toggle(id: Int, section: Section, key: AyuAppearanceToggle, title: String, value: Bool)
        case footer(id: Int, section: Section, text: String)

        var section: ItemListSectionId {
            switch self {
            case let .header(_, section, _), let .link(_, section, _, _, _), let .picker(_, section, _, _, _), let .toggle(_, section, _, _, _), let .footer(_, section, _):
                return section.rawValue
            }
        }

        var stableId: Int {
            switch self {
            case let .header(id, _, _), let .link(id, _, _, _, _), let .picker(id, _, _, _, _), let .toggle(id, _, _, _, _), let .footer(id, _, _):
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
            case let .link(_, _, link, symbol, title):
                let color: UIColor
                switch link {
                case .appIcon: color = AyuGramRowColor.teal
                case .deletedMark: color = AyuGramRowColor.orange
                case .editedMark: color = AyuGramRowColor.indigo
                }
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayuGramRowIcon(symbol, color: color), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.open(link)
                })
            case let .picker(_, _, key, title, label):
                let symbol: String
                let color: UIColor
                switch key {
                case .appBadge:
                    symbol = "app.badge.fill"
                    color = AyuGramRowColor.indigo
                case .doubleTap:
                    symbol = "hand.tap.fill"
                    color = AyuGramRowColor.orange
                case .doubleTapEmoji:
                    symbol = "heart.circle.fill"
                    color = AyuGramRowColor.pink
                }
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayuGramRowIcon(symbol, color: color), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.pick(key)
                })
            case let .toggle(_, _, key, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggle(key, value)
                })
            case let .footer(_, _, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            }
        }
    }

    enum AyuAppearancePicker {
        case appBadge, doubleTap, doubleTapEmoji
    }

    enum AyuAppearanceToggle {
        case snow, quickToggle
    }

    final class Arguments {
        let open: (Link) -> Void
        let pick: (AyuAppearancePicker) -> Void
        let toggle: (AyuAppearanceToggle, Bool) -> Void

        init(open: @escaping (Link) -> Void, pick: @escaping (AyuAppearancePicker) -> Void, toggle: @escaping (AyuAppearanceToggle, Bool) -> Void) {
            self.open = open
            self.pick = pick
            self.toggle = toggle
        }
    }

    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?

    let locale = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }

    let arguments = Arguments(open: { link in
        switch link {
        case .appIcon:
            pushController?(themeSettingsController(context: context, focusOnItemTag: .icon))
        case .deletedMark:
            pushController?(ayuGramMarkEditorScreen(context: context, kind: .deleted))
        case .editedMark:
            pushController?(ayuGramMarkEditorScreen(context: context, kind: .edited))
        }
    }, pick: { key in
        let data = context.sharedContext.currentPresentationData.with { $0 }
        let locale = data.strings.baseLanguageCode
        let sheet = ActionSheetController(presentationData: data)
        switch key {
        case .appBadge:
            var items: [ActionSheetItem] = []
            let current = SGSimpleSettings.shared.customAppBadge
            for style in ayuGramAppBadgeStyles {
                let selected = style.name == current
                items.append(ActionSheetButtonItem(title: (selected ? "✓ " : "") + style.title, color: .accent, action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    SGSimpleSettings.shared.customAppBadge = style.name
                }))
            }
            sheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in sheet?.dismissAnimated() })])
            ])
        case .doubleTap:
            var items: [ActionSheetItem] = []
            let current = AyuGramSettings.shared.extra.doubleTapAction
            let options: [(Int32, String)] = [
                (0, s("Ayu.DoubleTapStandard")),
                (1, s("Ayu.DoubleTapReact")),
                (2, s("Ayu.DoubleTapCopy"))
            ]
            for (value, title) in options {
                items.append(ActionSheetButtonItem(title: (value == current ? "✓ " : "") + title, color: .accent, action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    AyuGramSettings.shared.updateExtra { $0.doubleTapAction = value }
                }))
            }
            sheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in sheet?.dismissAnimated() })])
            ])
        case .doubleTapEmoji:
            presentController?(ayuGramSingleValueScreen(context: context, title: s("Ayu.DoubleTapEmojiTitle"), placeholder: "❤️", initial: AyuGramSettings.shared.extra.doubleTapEmoji, maxLength: 8, apply: { value in
                AyuGramSettings.shared.updateExtra { $0.doubleTapEmoji = value }
            }))
        }
        presentController?(sheet)
    }, toggle: { key, value in
        switch key {
        case .snow:
            AyuGramSettings.shared.updateExtra { $0.snowEnabled = value }
        case .quickToggle:
            AyuGramSettings.shared.updateExtra { $0.ghostQuickToggle = value }
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, Arguments)) in
        let extra = AyuGramSettings.shared.extra
        var entries: [Entry] = []

        entries.append(.header(id: 10, section: .general, text: s("Ayu.AppearanceSection")))
        entries.append(.link(id: 20, section: .general, link: .appIcon, symbol: "paintbrush.fill", title: s("Ayu.AppIcon")))
        let badgeStyle = ayuGramAppBadgeStyles.first(where: { $0.name == SGSimpleSettings.shared.customAppBadge })
        entries.append(.picker(id: 30, section: .general, key: .appBadge, title: s("Ayu.AppBadge"), label: badgeStyle?.title ?? ""))
        entries.append(.toggle(id: 40, section: .general, key: .snow, title: s("Ayu.SnowToggle"), value: extra.snowEnabled))
        entries.append(.toggle(id: 50, section: .general, key: .quickToggle, title: s("Ayu.QuickToggle"), value: extra.ghostQuickToggle))

        entries.append(.header(id: 100, section: .marks, text: s("Ayu.MarksSection")))
        entries.append(.link(id: 110, section: .marks, link: .deletedMark, symbol: "eraser.fill", title: s("Ayu.DeletedMark")))
        entries.append(.link(id: 120, section: .marks, link: .editedMark, symbol: "pencil.line", title: s("Ayu.EditedMark")))

        entries.append(.header(id: 200, section: .gestures, text: s("Ayu.GesturesSection")))
        let doubleTapLabels = [s("Ayu.DoubleTapStandard"), s("Ayu.DoubleTapReact"), s("Ayu.DoubleTapCopy")]
        entries.append(.picker(id: 210, section: .gestures, key: .doubleTap, title: s("Ayu.DoubleTapTitle"), label: doubleTapLabels[Int(max(0, min(2, extra.doubleTapAction)))]))
        if extra.doubleTapAction == 1 {
            entries.append(.picker(id: 220, section: .gestures, key: .doubleTapEmoji, title: s("Ayu.DoubleTapReaction"), label: extra.doubleTapEmoji))
        }

        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text(s("Ayu.AppearanceSection")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
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
