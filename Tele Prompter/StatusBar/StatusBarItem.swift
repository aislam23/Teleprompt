import AppKit

/// NSStatusBar entry with a small menu (Show/Hide, Settings, Play/Pause, Quit).
@MainActor
final class StatusBarItem: NSObject, NSMenuDelegate {

    private let controller: PrompterController
    private let onOpenSettings: () -> Void
    private let onTogglePrompter: () -> Void
    private let onTogglePlay: () -> Void
    private let onToggleLock: () -> Void
    private let onQuit: () -> Void

    private let item: NSStatusItem
    private let menu = NSMenu()

    init(controller: PrompterController,
         onOpenSettings: @escaping () -> Void,
         onTogglePrompter: @escaping () -> Void,
         onTogglePlay: @escaping () -> Void,
         onToggleLock: @escaping () -> Void,
         onQuit: @escaping () -> Void) {

        self.controller = controller
        self.onOpenSettings = onOpenSettings
        self.onTogglePrompter = onTogglePrompter
        self.onTogglePlay = onTogglePlay
        self.onToggleLock = onToggleLock
        self.onQuit = onQuit

        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Telesouffleur")
            button.image?.isTemplate = true
        }

        menu.delegate = self
        item.menu = menu
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()

        let toggleVisible = NSMenuItem(
            title: controller.isVisible ? "Hide prompter" : "Show prompter",
            action: #selector(togglePrompter), keyEquivalent: "h")
        toggleVisible.keyEquivalentModifierMask = [.option, .command]
        toggleVisible.target = self
        menu.addItem(toggleVisible)

        let togglePlay = NSMenuItem(
            title: controller.isPlaying ? "Pause" : "Play",
            action: #selector(togglePlayItem), keyEquivalent: " ")
        togglePlay.keyEquivalentModifierMask = [.option, .command]
        togglePlay.target = self
        menu.addItem(togglePlay)

        let toggleLockItem = NSMenuItem(
            title: controller.isLocked ? "Unlock (allow clicks)" : "Lock (click-through)",
            action: #selector(toggleLockItemAction), keyEquivalent: "l")
        toggleLockItem.keyEquivalentModifierMask = [.option, .command]
        toggleLockItem.target = self
        menu.addItem(toggleLockItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Telesouffleur", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func togglePrompter()    { onTogglePrompter() }
    @objc private func togglePlayItem()    { onTogglePlay() }
    @objc private func toggleLockItemAction() { onToggleLock() }
    @objc private func openSettings()      { onOpenSettings() }
    @objc private func quit()              { onQuit() }
}
