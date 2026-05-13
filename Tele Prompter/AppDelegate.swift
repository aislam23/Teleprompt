import AppKit
import SwiftUI
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let controller = PrompterController()
    private var panel: PrompterPanel?
    private var statusBar: StatusBarItem?
    private var hotKeys: HotKeyMonitor?
    private var settingsWC: SettingsWindowController?

    private let firstLaunchKey = "telesouffleur.hasLaunched"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Build the prompter overlay panel.
        let panel = PrompterPanel(controller: controller)
        self.panel = panel
        panel.applyControllerState()

        // 2. Hotkeys (best-effort; without permission only local monitor fires).
        let hotKeys = HotKeyMonitor(controller: controller)
        hotKeys.start()
        self.hotKeys = hotKeys

        // 3. Status bar menu.
        let statusBar = StatusBarItem(
            controller: controller,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onTogglePrompter: { [weak self] in self?.controller.toggleVisible() },
            onTogglePlay:     { [weak self] in self?.controller.togglePlay() },
            onToggleLock:     { [weak self] in self?.controller.toggleLock() },
            onQuit:           { NSApp.terminate(nil) }
        )
        self.statusBar = statusBar

        // 4. React to state changes that affect the AppKit-side panel (SwiftUI handles its own).
        observePanelState()

        // 5. Open settings on first launch so the user finds the script editor immediately.
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.stop()
    }

    // MARK: - Settings window

    private func showSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(
                controller: controller,
                hotKeysAuthorized: HotKeyMonitor.isAuthorized,
                onOpenInputMonitoring: HotKeyMonitor.openInputMonitoringSettings,
                onTogglePrompter: { [weak self] in self?.controller.toggleVisible() }
            )
        }
        settingsWC?.showAndFocus()
    }

    // MARK: - Observation

    /// Re-arms an observation each time the tracked properties change, mirroring the standard
    /// @Observable + AppKit recipe.
    private func observePanelState() {
        withObservationTracking {
            _ = controller.panelWidth
            _ = controller.panelHeight
            _ = controller.isLocked
            _ = controller.isVisible
            _ = controller.debugCaptureVisible
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                self?.panel?.applyControllerState()
                self?.observePanelState()
            }
        }
    }
}
