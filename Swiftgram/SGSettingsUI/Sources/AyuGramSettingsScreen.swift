import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import Postbox
import ItemListUI
import SGItemListUI
import SGSimpleSettings
import SGStrings

private enum AyuScreenSection: Int32 {
    case hero, ghost, spy, chats, useful, customization, content, transfer, client, support, database
}

private enum AyuScreenToggle: Equatable {
    case ghost, read, online, typing, recording, uploading, stories
    case offlineAfterOnline, offlineAfterSending, readOnSend, confirmRead, scheduleInGhost, quickToggle
    case history, premium
    case ignoreProtection, screenshots
    case disableAds, disableLinkWarning, disableGreeting, dimDeleted, hideBlocked, repeatMessage, confirmStickers, confirmGifs
}

private enum AyuScreenLink: Equatable {
    case history, savingPreferences, filters, deletedMark, editedMark, appearance, update, checkUpdates, channel, developer, bark, importChat, silentSending
}

private enum AyuScreenTint: Equatable {
    case purple, indigo, blue, teal, green, orange, red, pink, gray

    var color: UIColor {
        switch self {
        case .purple: return AyuGramRowColor.purple
        case .indigo: return AyuGramRowColor.indigo
        case .blue: return AyuGramRowColor.blue
        case .teal: return AyuGramRowColor.teal
        case .green: return AyuGramRowColor.green
        case .orange: return AyuGramRowColor.orange
        case .red: return AyuGramRowColor.red
        case .pink: return AyuGramRowColor.pink
        case .gray: return AyuGramRowColor.gray
        }
    }
}

private final class AyuScreenArguments {
    let toggle: (AyuScreenToggle, Bool) -> Void
    let updatePins: (Int32) -> Void
    let open: (AyuScreenLink) -> Void
    let clearDatabase: () -> Void

    init(toggle: @escaping (AyuScreenToggle, Bool) -> Void, updatePins: @escaping (Int32) -> Void, open: @escaping (AyuScreenLink) -> Void, clearDatabase: @escaping () -> Void) {
        self.toggle = toggle
        self.updatePins = updatePins
        self.open = open
        self.clearDatabase = clearDatabase
    }
}

private enum AyuScreenEntry: ItemListNodeEntry {
    case hero(id: Int, title: String, status: String, detail: String, active: Bool)
    case header(id: Int, section: AyuScreenSection, text: String)
    case toggle(id: Int, section: AyuScreenSection, key: AyuScreenToggle, symbol: String, tint: AyuScreenTint, title: String, subtitle: String?, value: Bool, enabled: Bool)
    case link(id: Int, section: AyuScreenSection, link: AyuScreenLink, symbol: String, tint: AyuScreenTint, title: String, label: String)
    case pins(id: Int, section: AyuScreenSection, value: Int32)
    case destructive(id: Int, section: AyuScreenSection, title: String, label: String)
    case footer(id: Int, section: AyuScreenSection, text: String)

    var section: ItemListSectionId {
        switch self {
        case .hero:
            return AyuScreenSection.hero.rawValue
        case let .header(_, section, _), let .footer(_, section, _), let .pins(_, section, _), let .destructive(_, section, _, _):
            return section.rawValue
        case let .toggle(_, section, _, _, _, _, _, _, _):
            return section.rawValue
        case let .link(_, section, _, _, _, _, _):
            return section.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case let .hero(id, _, _, _, _), let .header(id, _, _), let .footer(id, _, _), let .pins(id, _, _), let .destructive(id, _, _, _):
            return id
        case let .toggle(id, _, _, _, _, _, _, _, _):
            return id
        case let .link(id, _, _, _, _, _, _):
            return id
        }
    }

    static func <(lhs: AyuScreenEntry, rhs: AyuScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuScreenArguments
        switch self {
        case let .hero(_, title, status, detail, active):
            return AyuGramSettingsHeroItem(data: presentationData, title: title, status: status, detail: detail, isActive: active, sectionId: self.section)
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, key, symbol, tint, title, subtitle, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayuGramRowIcon(symbol, color: tint.color), title: title, text: subtitle, value: value, enabled: enabled, maximumNumberOfLines: 0, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .link(_, _, link, symbol, tint, title, label):
            let icon = (link == .channel ? ayuGramRowImage("AyuUpdatesChannel") : nil) ?? ayuGramRowIcon(symbol, color: tint.color)
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: icon, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.open(link)
            })
        case let .pins(_, _, value):
            return AyuPinnedCountSliderItem(theme: presentationData.theme, strings: presentationData.strings, value: value, sectionId: self.section, updated: { value in
                arguments.updatePins(value)
            })
        case let .destructive(_, _, title, label):
            // AyuGram Android parity: red text next to the custom red trash icon.
            return AyuGramRedActionItem(presentationData: presentationData, systemStyle: .glass, icon: ayuGramTrashIcon(), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.clearDatabase()
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// Size of the AyuGram message archive, shown as the "Clear Ayu Database" value.
/// Same directory the history engine writes to (`ayu-message-archive` in MediaBox).
private func ayuGramArchiveSize(mediaBox: MediaBox) -> String {
    let directory = URL(fileURLWithPath: mediaBox.basePath, isDirectory: true).appendingPathComponent("ayu-message-archive", isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
        return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
    }
    var total: Int64 = 0
    for case let url as URL in enumerator {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            total += Int64(size)
        }
    }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
}

private func ayuScreenEntries(data: PresentationData, privacy: AyuGramPrivacySettings, extra: AyuGramExtraSettings, client: AyuGramClientSettings, hasAppearance: Bool, update: AyuGramUpdateInfo?, archiveSize: String) -> [AyuScreenEntry] {
    let locale = data.strings.baseLanguageCode
    func s(_ key: String) -> String {
        return i18n(key, locale)
    }
    let ghost = privacy.ghostMode
    var entries: [AyuScreenEntry] = []

    let hidden = [privacy.suppressRead, privacy.suppressOnline, privacy.suppressTyping, privacy.suppressRecording, privacy.suppressUploading, privacy.suppressStoryViews]
    let hiddenCount = hidden.filter { $0 }.count
    entries.append(.hero(id: 0, title: "AyuGram", status: s(ghost ? "Ayu.HeroGhostOn" : "Ayu.HeroGhostOff"), detail: i18n("Ayu.HeroHidden", locale, "\(hiddenCount)", "\(hidden.count)"), active: ghost || hiddenCount > 0))
    if let update {
        entries.append(.link(id: 50, section: .support, link: .update, symbol: "arrow.down.circle.fill", tint: .green, title: s("Ayu.UpdateAvailable") + " · " + update.version, label: ""))
    }

    // Ghost essentials (AyuGram Android: the collapsible Ghost Mode block).
    entries.append(.header(id: 100, section: .ghost, text: s("Ayu.GhostEssentials")))
    entries.append(.toggle(id: 110, section: .ghost, key: .ghost, symbol: "eye.slash.fill", tint: .purple, title: s("Ayu.Ghost"), subtitle: s("Ayu.GhostSubtitle"), value: ghost, enabled: true))
    entries.append(.toggle(id: 115, section: .ghost, key: .read, symbol: "checkmark.circle.fill", tint: .blue, title: s("Ayu.HideRead"), subtitle: nil, value: privacy.suppressRead, enabled: !ghost))
    entries.append(.toggle(id: 120, section: .ghost, key: .online, symbol: "wifi.slash", tint: .green, title: s("Ayu.HideOnline"), subtitle: nil, value: privacy.suppressOnline, enabled: !ghost))
    entries.append(.toggle(id: 125, section: .ghost, key: .typing, symbol: "keyboard", tint: .teal, title: s("Ayu.HideTyping"), subtitle: nil, value: privacy.suppressTyping, enabled: !ghost))
    entries.append(.toggle(id: 130, section: .ghost, key: .recording, symbol: "mic.slash.fill", tint: .red, title: s("Ayu.HideRecording"), subtitle: nil, value: privacy.suppressRecording, enabled: !ghost))
    entries.append(.toggle(id: 135, section: .ghost, key: .uploading, symbol: "icloud.and.arrow.up.fill", tint: .indigo, title: s("Ayu.HideUploading"), subtitle: nil, value: privacy.suppressUploading, enabled: !ghost))
    entries.append(.toggle(id: 140, section: .ghost, key: .stories, symbol: "camera.circle.fill", tint: .pink, title: s("Ayu.HideStories"), subtitle: nil, value: privacy.suppressStoryViews, enabled: !ghost))
    entries.append(.toggle(id: 145, section: .ghost, key: .offlineAfterOnline, symbol: "bolt.badge.clock.fill", tint: .orange, title: s("Ayu.OfflineAfterOnline"), subtitle: s("Ayu.OfflineAfterOnlineInfo"), value: extra.offlineAfterOnline, enabled: true))
    entries.append(.toggle(id: 150, section: .ghost, key: .readOnSend, symbol: "arrowshape.turn.up.left.fill", tint: .blue, title: s("Ayu.ReadOnSend"), subtitle: s("Ayu.ReadOnSendInfo"), value: extra.readOnSend, enabled: true))
    entries.append(.toggle(id: 152, section: .ghost, key: .confirmRead, symbol: "checkmark.bubble.fill", tint: .blue, title: s("Ayu.ConfirmReadReceipt"), subtitle: nil, value: extra.confirmReadReceipt, enabled: true))
    entries.append(.toggle(id: 155, section: .ghost, key: .scheduleInGhost, symbol: "clock.badge.checkmark.fill", tint: .teal, title: s("Ayu.ScheduleInGhost"), subtitle: s("Ayu.ScheduleInGhostInfo"), value: extra.scheduleInGhost, enabled: true))
    let silentLabels = ["Ayu.SilentNever", "Ayu.SilentInGhost", "Ayu.SilentAlways"]
    entries.append(.link(id: 157, section: .ghost, link: .silentSending, symbol: "bell.slash.fill", tint: .gray, title: s("Ayu.SilentSending"), label: s(silentLabels[Int(max(0, min(2, extra.silentSending)))])))
    entries.append(.footer(id: 160, section: .ghost, text: s("Ayu.GhostFooter")))

    // Spy essentials (AyuGram Android: saved deleted and edited messages).
    entries.append(.header(id: 200, section: .spy, text: s("Ayu.SpyEssentials")))
    entries.append(.toggle(id: 210, section: .spy, key: .history, symbol: "trash.fill", tint: .red, title: s("Ayu.SaveDeleted"), subtitle: s("Ayu.SaveDeletedInfo"), value: privacy.messageHistory, enabled: true))
    entries.append(.link(id: 215, section: .spy, link: .history, symbol: "clock.fill", tint: .teal, title: s("Ayu.OpenHistory"), label: ""))
    entries.append(.link(id: 220, section: .spy, link: .savingPreferences, symbol: "tray.full.fill", tint: .indigo, title: s("Ayu.SavingPreferences"), label: ""))
    entries.append(.footer(id: 230, section: .spy, text: s("Ayu.SavingFooterShort")))

    // Chats.
    entries.append(.header(id: 300, section: .chats, text: s("Ayu.ChatsSection")))
    entries.append(.toggle(id: 310, section: .chats, key: .disableAds, symbol: "megaphone.fill", tint: .orange, title: s("Ayu.DisableAds"), subtitle: nil, value: extra.disableAds, enabled: true))
    entries.append(.toggle(id: 315, section: .chats, key: .disableLinkWarning, symbol: "link", tint: .blue, title: s("Ayu.DisableLinkWarning"), subtitle: nil, value: extra.disableLinkWarning, enabled: true))
    entries.append(.toggle(id: 320, section: .chats, key: .disableGreeting, symbol: "hand.wave.fill", tint: .green, title: s("Ayu.DisableGreeting"), subtitle: nil, value: extra.disableGreetingSticker, enabled: true))
    entries.append(.toggle(id: 325, section: .chats, key: .dimDeleted, symbol: "circle.lefthalf.filled", tint: .red, title: s("Ayu.DimDeleted"), subtitle: nil, value: extra.dimDeletedMessages, enabled: true))
    entries.append(.toggle(id: 330, section: .chats, key: .hideBlocked, symbol: "person.slash.fill", tint: .red, title: s("Ayu.HideBlocked"), subtitle: s("Ayu.HideBlockedInfo"), value: extra.hideBlockedMessages, enabled: true))
    entries.append(.toggle(id: 335, section: .chats, key: .repeatMessage, symbol: "arrow.2.squarepath", tint: .indigo, title: s("Ayu.RepeatMessage"), subtitle: nil, value: extra.repeatMessage, enabled: true))
    entries.append(.toggle(id: 340, section: .chats, key: .confirmStickers, symbol: "face.smiling.inverse", tint: .pink, title: s("Ayu.ConfirmStickers"), subtitle: nil, value: extra.confirmStickers, enabled: true))
    entries.append(.toggle(id: 345, section: .chats, key: .confirmGifs, symbol: "play.rectangle.fill", tint: .purple, title: s("Ayu.ConfirmGifs"), subtitle: nil, value: extra.confirmGifs, enabled: true))
    entries.append(.footer(id: 350, section: .chats, text: s("Ayu.LocalOnly")))

    // Useful features (AyuGram Android section).
    entries.append(.header(id: 400, section: .useful, text: s("Ayu.UsefulSection")))
    let filterCount = AyuGramFilters.shared.activeCount
    entries.append(.link(id: 410, section: .useful, link: .filters, symbol: "line.3.horizontal.decrease.circle.fill", tint: .teal, title: s("Ayu.FiltersTitle"), label: filterCount > 0 ? i18n("Ayu.FiltersCount", locale, "\(filterCount)") : s("Ayu.FilterOff")))
    let barkOn = !(AyuGramPushRelay.barkKey ?? "").isEmpty
    entries.append(.link(id: 420, section: .useful, link: .bark, symbol: "bell.badge.fill", tint: .red, title: s(barkOn ? "Ayu.BarkConnected" : "Ayu.BarkSetUp"), label: ""))
    entries.append(.toggle(id: 430, section: .useful, key: .premium, symbol: "star.fill", tint: .purple, title: s("Ayu.LocalPremium"), subtitle: s("Ayu.LocalPremiumInfo"), value: client.localPremium, enabled: true))

    // Customization (AyuGram Android section).
    entries.append(.header(id: 500, section: .customization, text: s("Ayu.CustomizationSection")))
    entries.append(.link(id: 510, section: .customization, link: .deletedMark, symbol: "eraser.fill", tint: .orange, title: s("Ayu.DeletedMark"), label: extra.deletedMark.isEmpty ? "🧹" : extra.deletedMark))
    entries.append(.link(id: 520, section: .customization, link: .editedMark, symbol: "pencil.line", tint: .blue, title: s("Ayu.EditedMark"), label: extra.editedMark.isEmpty ? s("Ayu.EditedMarkNative") : extra.editedMark))
    entries.append(.toggle(id: 530, section: .customization, key: .quickToggle, symbol: "hand.tap.fill", tint: .orange, title: s("Ayu.QuickToggle"), subtitle: s("Ayu.QuickToggleInfo"), value: extra.ghostQuickToggle, enabled: true))

    // Content protection.
    entries.append(.header(id: 600, section: .content, text: s("Ayu.ContentSection")))
    entries.append(.toggle(id: 610, section: .content, key: .ignoreProtection, symbol: "lock.open.fill", tint: .orange, title: s("Ayu.IgnoreProtection"), subtitle: s("Ayu.IgnoreProtectionInfo"), value: extra.ignoreCopyProtection, enabled: true))
    entries.append(.toggle(id: 620, section: .content, key: .screenshots, symbol: "camera.fill", tint: .gray, title: s("Ayu.AllowScreenshots"), subtitle: s("Ayu.AllowScreenshotsInfo"), value: extra.allowScreenshots, enabled: true))
    entries.append(.footer(id: 630, section: .content, text: s("Ayu.ContentFooter")))

    // Chat transfer.
    entries.append(.header(id: 700, section: .transfer, text: s("Ayu.ChatTransferSection")))
    entries.append(.link(id: 710, section: .transfer, link: .importChat, symbol: "square.and.arrow.down.fill", tint: .green, title: s("Ayu.ImportChat"), label: ""))
    entries.append(.footer(id: 720, section: .transfer, text: s("Ayu.ImportChatFooter")))

    // Client.
    entries.append(.header(id: 800, section: .client, text: s("Ayu.ClientSection")))
    entries.append(.pins(id: 810, section: .client, value: client.pinnedChatLimit))
    entries.append(.footer(id: 820, section: .client, text: s("Ayu.PinsFooter")))

    // Support.
    entries.append(.header(id: 900, section: .support, text: s("Ayu.SupportSection")))
    entries.append(.link(id: 910, section: .support, link: .channel, symbol: "paperplane.fill", tint: .blue, title: s("Ayu.SupportChannel"), label: ""))
    entries.append(.link(id: 920, section: .support, link: .developer, symbol: "person.crop.circle.fill", tint: .purple, title: s("Ayu.SupportDeveloper"), label: ""))
    entries.append(.link(id: 930, section: .support, link: .checkUpdates, symbol: "arrow.triangle.2.circlepath", tint: .gray, title: s("Ayu.CheckUpdates"), label: ""))

    // Database (AyuGram Android: the red rows with the trash icon at the bottom).
    entries.append(.destructive(id: 960, section: .database, title: s("Ayu.ClearDatabase"), label: archiveSize))
    return entries
}

/// Redesigned AyuGram settings, section structure follows AyuGram Android
/// (Ghost essentials, Spy essentials, Useful features, Customization, the red
/// "Clear Ayu Database" row with the custom trash icon at the bottom).
public func ayuGramSettingsScreen(context: AccountContext) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?
    let arguments = AyuScreenArguments(toggle: { key, value in
        let settings = AyuGramSettings.shared
        switch key {
        case .ghost: settings.update { $0.ghostMode = value }
        case .read: settings.update { $0.antiRead = value }
        case .online: settings.update { $0.antiOnline = value }
        case .typing: settings.update { $0.antiTyping = value }
        case .recording: settings.update { $0.antiRecording = value }
        case .uploading: settings.update { $0.antiUploading = value }
        case .stories: settings.update { $0.storyPrivacy = value }
        case .history: settings.update { $0.messageHistory = value }
        case .offlineAfterOnline: settings.updateExtra { $0.offlineAfterOnline = value }
        case .offlineAfterSending: settings.updateExtra { $0.offlineAfterSending = value }
        case .readOnSend: settings.updateExtra { $0.readOnSend = value }
        case .quickToggle: settings.updateExtra { $0.ghostQuickToggle = value }
        case .ignoreProtection: settings.updateExtra { $0.ignoreCopyProtection = value }
        case .screenshots: settings.updateExtra { $0.allowScreenshots = value }
        case .premium: settings.updateClient { $0.localPremium = value }
        case .scheduleInGhost: settings.updateExtra { $0.scheduleInGhost = value }
        case .disableAds: settings.updateExtra { $0.disableAds = value }
        case .disableLinkWarning: settings.updateExtra { $0.disableLinkWarning = value }
        case .disableGreeting: settings.updateExtra { $0.disableGreetingSticker = value }
        case .dimDeleted: settings.updateExtra { $0.dimDeletedMessages = value }
        case .hideBlocked: settings.updateExtra { $0.hideBlockedMessages = value }
        case .repeatMessage: settings.updateExtra { $0.repeatMessage = value }
        case .confirmStickers: settings.updateExtra { $0.confirmStickers = value }
        case .confirmGifs: settings.updateExtra { $0.confirmGifs = value }
        case .confirmRead: settings.updateExtra { $0.confirmReadReceipt = value }
        }
    }, updatePins: { value in
        AyuGramSettings.shared.updateClient { $0.maxPinnedChats = value }
    }, open: { link in
        switch link {
        case .history:
            pushController?(ayuGramHistoryController(context: context))
        case .savingPreferences:
            pushController?(ayuGramSavingPreferencesScreen(context: context))
        case .filters:
            pushController?(ayuGramFiltersScreen(context: context))
        case .deletedMark:
            pushController?(ayuGramMarkEditorScreen(context: context, kind: .deleted))
        case .editedMark:
            pushController?(ayuGramMarkEditorScreen(context: context, kind: .edited))
        case .appearance:
            if let controller = ayuGramAppearanceEntryController(context: context) {
                pushController?(controller)
            }
        case .update:
            if let info = AyuGramUpdates.shared.availableUpdate {
                presentController?(ayuGramUpdateAlert(context: context, info: info))
            }
        case .checkUpdates:
            AyuGramUpdates.shared.check { info in
                if let info {
                    presentController?(ayuGramUpdateAlert(context: context, info: info))
                } else {
                    let data = context.sharedContext.currentPresentationData.with { $0 }
                    presentController?(textAlertController(context: context, title: nil, text: i18n("Ayu.UpToDate", data.strings.baseLanguageCode), actions: [TextAlertAction(type: .defaultAction, title: data.strings.Common_OK, action: {})]))
                }
            }
        case .channel:
            ayuGramOpenLink(context: context, url: AyuGramUpdates.channelURL)
        case .developer:
            ayuGramOpenDeveloper(context: context)
        case .bark:
            ayuGramSetUpBark(context: context, present: { controller in
                presentController?(controller)
            })
        case .importChat:
            ayuGramImportChat(context: context)
        case .silentSending:
            let data = context.sharedContext.currentPresentationData.with { $0 }
            let locale = data.strings.baseLanguageCode
            let sheet = ActionSheetController(presentationData: data)
            let current = AyuGramSettings.shared.extra.silentSending
            var items: [ActionSheetItem] = []
            for (index, key) in ["Ayu.SilentNever", "Ayu.SilentInGhost", "Ayu.SilentAlways"].enumerated() {
                let value = Int32(index)
                items.append(ActionSheetButtonItem(title: (value == current ? "✓ " : "") + i18n(key, locale), color: .accent, action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    AyuGramSettings.shared.updateExtra { $0.silentSending = value }
                }))
            }
            sheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: data.strings.Common_Cancel, color: .accent, action: { [weak sheet] in sheet?.dismissAnimated() })])
            ])
            presentController?(sheet)
        }
    }, clearDatabase: {
        let data = context.sharedContext.currentPresentationData.with { $0 }
        let locale = data.strings.baseLanguageCode
        presentController?(textAlertController(context: context, title: i18n("Ayu.ClearDatabase", locale), text: i18n("Ayu.ClearDatabaseInfo", locale), actions: [
            TextAlertAction(type: .genericAction, title: data.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: i18n("Ayu.ClearDatabaseConfirm", locale), action: {
                let _ = (context.engine.ayuGramClearMessageHistory()
                |> deliverOnMainQueue).startStandalone(completed: {
                    let updated = context.sharedContext.currentPresentationData.with { $0 }
                    presentController?(textAlertController(context: context, title: nil, text: i18n("Ayu.DatabaseCleared", updated.strings.baseLanguageCode), actions: [TextAlertAction(type: .defaultAction, title: updated.strings.Common_OK, action: {})]))
                })
            })
        ]))
    })
    let hasAppearance = ayuGramHasAppearanceEntry
    let signal = combineLatest(context.sharedContext.presentationData, ayuSettingsChangeSignal())
    |> deliverOnMainQueue
    |> map { data, _ -> (ItemListControllerState, (ItemListNodeState, AyuScreenArguments)) in
        let settings = AyuGramSettings.shared
        let entries = ayuScreenEntries(data: data, privacy: settings.snapshot, extra: settings.extra, client: settings.client, hasAppearance: hasAppearance, update: AyuGramUpdates.shared.availableUpdate, archiveSize: ayuGramArchiveSize(mediaBox: context.account.postbox.mediaBox))
        let state = ItemListControllerState(presentationData: ItemListPresentationData(data), title: .text("AyuGram"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: data.strings.Common_Back))
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
