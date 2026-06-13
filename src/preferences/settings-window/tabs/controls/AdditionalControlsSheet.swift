import Cocoa

class AdditionalControlsSheet: SheetWindow {
    // Localized labels live here once. `searchableStrings` and `makeContentView` both reference
    // these constants so changing a string takes one edit, and search can't silently miss a row
    // because of a typo divergence between the two paths.
    private static let title = NSLocalizedString("Additional controls", comment: "")
    private static let titleMiscellaneous = NSLocalizedString("Miscellaneous", comment: "")
    private static let labelArrows = NSLocalizedString("Select windows using arrow keys", comment: "")
    private static let labelVim = NSLocalizedString("Select windows using vim keys", comment: "")
    private static let labelMouse = NSLocalizedString("Select windows on mouse hover", comment: "")
    private static let labelScroll = NSLocalizedString("Select windows by scrolling", comment: "")
    private static let labelScrollDirection = NSLocalizedString("Scrolling direction", comment: "")
    private static let labelCursorFollow = NSLocalizedString("Cursor follows focus", comment: "")
    private static let labelTrackpad = NSLocalizedString("Trackpad haptic feedback", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title, titleMiscellaneous,
        labelArrows, labelVim, labelMouse, labelScroll, labelScrollDirection,
        labelCursorFollow, labelTrackpad,
    ] + CursorFollowFocus.allCases.map { $0.localizedString }
      + ScrollToSelectDirection.allCases.map { $0.localizedString }

    override func makeContentView() -> NSView {
        let enableArrows = TableGroupView.Row(leftTitle: Self.labelArrows,
            rightViews: [LabelAndControl.makeSwitch("arrowKeysEnabled", extraAction: ControlsTab.arrowKeysEnabledCallback)])
        let enableVimKeys = TableGroupView.Row(leftTitle: Self.labelVim,
            rightViews: [LabelAndControl.makeSwitch("vimKeysEnabled", extraAction: ControlsTab.vimKeysEnabledCallback)])
        let enableMouse = TableGroupView.Row(leftTitle: Self.labelMouse,
            rightViews: [LabelAndControl.makeSwitch("mouseHoverEnabled")])
        let enableScroll = TableGroupView.Row(leftTitle: Self.labelScroll,
            rightViews: [LabelAndControl.makeSwitch("scrollToSelectEnabled")])
        let scrollDirection = TableGroupView.Row(leftTitle: Self.labelScrollDirection,
            rightViews: [LabelAndControl.makeDropdown("scrollToSelectDirection", ScrollToSelectDirection.allCases)])
        let enableCursorFollowFocus = TableGroupView.Row(leftTitle: Self.labelCursorFollow,
            rightViews: [LabelAndControl.makeDropdown("cursorFollowFocus", CursorFollowFocus.allCases)])
        let enableTrackpadHapticFeedback = TableGroupView.Row(leftTitle: Self.labelTrackpad,
            rightViews: [LabelAndControl.makeSwitch("trackpadHapticFeedbackEnabled")])
        ControlsTab.arrowKeysCheckbox = enableArrows.rightViews[0] as? Switch
        ControlsTab.vimKeysCheckbox = enableVimKeys.rightViews[0] as? Switch
        ControlsTab.arrowKeysEnabledCallback(ControlsTab.arrowKeysCheckbox)
        ControlsTab.vimKeysEnabledCallback(ControlsTab.vimKeysCheckbox)
        let table1 = TableGroupView(title: Self.title, width: SheetWindow.width)
        _ = table1.addRow(enableArrows)
        _ = table1.addRow(enableVimKeys)
        _ = table1.addRow(enableMouse)
        _ = table1.addRow(enableScroll)
        _ = table1.addRow(scrollDirection)
        let table2 = TableGroupView(title: Self.titleMiscellaneous, width: SheetWindow.width)
        _ = table2.addRow(enableCursorFollowFocus)
        _ = table2.addRow(enableTrackpadHapticFeedback)
        let view = TableGroupSetView(originalViews: [table1, table2], padding: 0)
        return view
    }
}

class AppBindingsSheet: SheetWindow {
    private static let title = NSLocalizedString("App bindings", comment: "")
    private static let enableLabel = NSLocalizedString("Enable app bindings", comment: "")
    private static let chooseTitle = NSLocalizedString("Choose…", comment: "")
    private static let clearTitle = NSLocalizedString("Clear", comment: "")
    private static let runningAppsTitle = NSLocalizedString("Assign a running app", comment: "")
    private static let diskTitle = NSLocalizedString("Assign an app from disk", comment: "")
    private static let keyLabelPrefix = NSLocalizedString("Press", comment: "")

    static let searchableStrings: [String] = [
        title, enableLabel, chooseTitle, clearTitle, runningAppsTitle, diskTitle, keyLabelPrefix,
    ] + AppBindings.shortcutDefinitions.map { $0.keyEquivalent }

    private var assignmentButtons = [Int: NSButton]()
    private var clearButtons = [Int: NSButton]()

    override func makeContentView() -> NSView {
        assignmentButtons.removeAll()
        clearButtons.removeAll()
        let table = TableGroupView(title: Self.title, width: SheetWindow.width)
        table.addRow(TableGroupView.Row(leftTitle: Self.enableLabel,
            rightViews: [LabelAndControl.makeSwitch("appBindingsEnabled")]))
        AppBindings.shortcutDefinitions.forEach {
            table.addRow(TableGroupView.Row(leftTitle: Self.keyLabelPrefix + " " + $0.keyEquivalent,
                rightViews: rowControls($0.index)))
        }
        refresh()
        return TableGroupSetView(originalViews: [table], padding: 0)
    }

    func refresh() {
        AppBindings.shortcutDefinitions.forEach { updateRow($0.index) }
    }

    private func rowControls(_ index: Int) -> [NSView] {
        let chooseButton = NSButton(title: Self.chooseTitle, target: nil, action: nil)
        chooseButton.translatesAutoresizingMaskIntoConstraints = false
        chooseButton.widthAnchor.constraint(equalToConstant: 210).isActive = true
        chooseButton.onAction = { [weak self, weak chooseButton] _ in
            guard let self, let chooseButton else { return }
            self.showAssignmentMenu(index, near: chooseButton)
        }
        let clearButton = NSButton(title: Self.clearTitle, target: nil, action: nil)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.onAction = { [weak self] _ in self?.setBinding(index, "") }
        assignmentButtons[index] = chooseButton
        clearButtons[index] = clearButton
        return [chooseButton, clearButton]
    }

    private func updateRow(_ index: Int) {
        let bundleId = Preferences.appBindingBundleId(index)
        let hasBinding = !bundleId.isEmpty
        let chooseButton = assignmentButtons[index]
        chooseButton?.title = hasBinding ? AppDisplayInfo.resolve(bundleId: bundleId).name : Self.chooseTitle
        chooseButton?.image = hasBinding ? appIcon(bundleId) : nil
        chooseButton?.imagePosition = .imageLeading
        clearButtons[index]?.isEnabled = hasBinding
    }

    private func appIcon(_ bundleId: String) -> NSImage {
        let icon = AppDisplayInfo.resolve(bundleId: bundleId).icon
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private func showAssignmentMenu(_ index: Int, near sender: NSButton) {
        let menu = NSMenu()
        let runningAppsItem = NSMenuItem(title: Self.runningAppsTitle, action: nil, keyEquivalent: "")
        runningAppsItem.submenu = buildRunningAppsSubmenu(index)
        menu.addItem(runningAppsItem)
        let diskItem = NSMenuItem(title: Self.diskTitle, action: #selector(addFromDisk(_:)), keyEquivalent: "")
        diskItem.target = self
        diskItem.representedObject = index
        menu.addItem(diskItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    private func buildRunningAppsSubmenu(_ index: Int) -> NSMenu {
        let submenu = NSMenu()
        runningAppsForMenu().forEach { submenu.addItem(makeRunningAppItem($0.app, $0.bundleId, index)) }
        return submenu
    }

    private func runningAppsForMenu() -> [(app: NSRunningApplication, bundleId: String)] {
        var appsByBundleId = [String: NSRunningApplication]()
        runningAppCandidates().forEach {
            guard let bundleId = $0.bundleIdentifier, appsByBundleId[bundleId] == nil else { return }
            appsByBundleId[bundleId] = $0
        }
        return appsByBundleId.map { ($0.value, $0.key) }.sorted { appMenuTitle($0.app).localizedStandardCompare(appMenuTitle($1.app)) == .orderedAscending }
    }

    private func runningAppCandidates() -> [NSRunningApplication] {
        Windows.list.map { $0.application.runningApplication } + NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
    }

    private func makeRunningAppItem(_ app: NSRunningApplication, _ bundleId: String, _ index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: appMenuTitle(app), action: #selector(addRunningApp(_:)), keyEquivalent: "")
        if let path = app.bundleURL?.path {
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
        }
        item.representedObject = AppBindingMenuChoice(index: index, bundleId: bundleId)
        item.target = self
        return item
    }

    private func appMenuTitle(_ app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? ""
    }

    @objc private func addRunningApp(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? AppBindingMenuChoice else { return }
        setBinding(choice.index, choice.bundleId)
    }

    @objc private func addFromDisk(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        let dialog = NSOpenPanel()
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["app"]
        dialog.canChooseDirectories = false
        dialog.beginSheetModal(for: SettingsWindow.shared) { [weak self] in
            guard $0 == .OK, let url = dialog.url, let bundleId = Bundle(url: url)?.bundleIdentifier else { return }
            self?.setBinding(index, bundleId)
        }
    }

    private func setBinding(_ index: Int, _ bundleId: String) {
        Preferences.set(Preferences.indexToName("appBindingBundleId", index), bundleId)
    }
}

private struct AppBindingMenuChoice {
    let index: Int
    let bundleId: String
}
