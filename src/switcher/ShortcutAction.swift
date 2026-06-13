import Cocoa

struct ShortcutAction {
    let id: String
    let perform: () -> Void
}

enum ShortcutActions {
    static let all: [ShortcutAction] = [
        ShortcutAction(id: "focusWindowShortcut", perform: { App.focusTarget() }),
        ShortcutAction(id: "previousWindowShortcut", perform: { App.previousWindowShortcutWithRepeatingKey() }),
        ShortcutAction(id: "→", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "←", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "↑", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "↓", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "vimCycleRight", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "vimCycleLeft", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "vimCycleUp", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "vimCycleDown", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "cancelShortcut", perform: {
            guard let session = SwitcherSession.current else { return }
            let entry: SearchEntryStyle = Preferences.effectiveShortcutStyle(session.shortcutIndex) == .searchOnRelease ? .startedInSearch : .toggledMidSession
            switch SearchModeResolver.escape(mode: TilesView.searchMode, entry: entry) {
                case .exitSearch: TilesView.disableSearchMode()
                case .closeSwitcher: App.hideUi()
            }
        }),
        ShortcutAction(id: "closeWindowShortcut", perform: { Windows.selectedWindow()?.close() }),
        ShortcutAction(id: "minDeminWindowShortcut", perform: { Windows.selectedWindow()?.minDemin() }),
        ShortcutAction(id: "toggleFullscreenWindowShortcut", perform: { Windows.selectedWindow()?.toggleFullscreen() }),
        ShortcutAction(id: "quitAppShortcut", perform: { Windows.selectedWindow()?.application.quit() }),
        ShortcutAction(id: "hideShowAppShortcut", perform: { Windows.selectedWindow()?.application.hideOrShow() }),
        ShortcutAction(id: "searchShortcut", perform: {
            guard SwitcherSession.isActive else { return }
            TilesView.toggleSearchModeFromShortcut()
        }),
        ShortcutAction(id: "lockSearchShortcut", perform: {
            guard SwitcherSession.isActive, TilesView.isSearchModeOn else { return }
            TilesView.lockSearchMode()
        }),
    ]

    private static let byId: [String: ShortcutAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> ShortcutAction? {
        byId[id]
    }

    static func execute(_ id: String) {
        // Gate *pressing* a Pro-only shortcut slot (index >= 1). Without this, configured Cmd+Tab
        // variants past the first keep working after Day15 lock. Mirrors the `.lockSearch` /
        // `.search` gates in `TilesView` and the slot-add gate in `addShortcutSlot()`.
        if id.hasPrefix("holdShortcut") || id.hasPrefix("nextWindowShortcut") {
            let index = Preferences.nameToIndex(id)
            if index >= 1 {
                if !ProFeature.extraShortcut(index: index).attemptUse() { return }
            }
        }
        if let action = find(id) {
            action.perform()
            return
        }
        if id.hasPrefix("holdShortcut") {
            App.focusTarget()
            return
        }
        if id.hasPrefix("nextWindowShortcut") {
            App.showUiOrCycleSelection(Preferences.nameToIndex(id), false)
            return
        }
        if let appBindingIndex = AppBindings.index(fromShortcutId: id) {
            AppBindings.activate(appBindingIndex)
        }
    }
}

struct AppBindingShortcutDefinition {
    let id: String
    let keyEquivalent: String
    let index: Int
}

enum AppBindings {
    static let shortcutDefinitions: [AppBindingShortcutDefinition] = keyEquivalents.enumerated().map {
        AppBindingShortcutDefinition(id: Preferences.indexToName("appBindingShortcut", $0.offset), keyEquivalent: $0.element, index: $0.offset)
    }

    private static let keyEquivalents = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    static func index(fromShortcutId id: String) -> Int? {
        guard id.hasPrefix("appBindingShortcut") else { return nil }
        let index = Preferences.nameToIndex(id)
        guard (0..<Preferences.appBindingCount).contains(index) else { return nil }
        return index
    }

    static func bundleId(_ index: Int) -> String? {
        let bundleId = Preferences.appBindingBundleId(index)
        return bundleId.isEmpty ? nil : bundleId
    }

    static func activate(_ index: Int) {
        guard let bundleId = bundleId(index) else { return }
        guard !focusExistingWindow(bundleId) else { return }
        guard !activateRunningApp(bundleId) else { return }
        launchApp(bundleId)
    }

    private static func focusExistingWindow(_ bundleId: String) -> Bool {
        guard let window = Windows.list.first(where: { $0.application.bundleIdentifier == bundleId && $0.shouldShowTheUser }) else { return false }
        App.hideUi(true)
        window.focus()
        return true
    }

    private static func activateRunningApp(_ bundleId: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return false }
        App.hideUi(true)
        app.activate(options: .activateAllWindows)
        return true
    }

    private static func launchApp(_ bundleId: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            NSSound.beep()
            return
        }
        App.hideUi(true)
        if #available(macOS 10.15, *) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
                if error != nil { NSSound.beep(); return }
                app?.activate(options: .activateAllWindows)
            }
            return
        }
        if (try? NSWorkspace.shared.launchApplication(at: url, configuration: [:])) == nil {
            NSSound.beep()
        }
    }
}
