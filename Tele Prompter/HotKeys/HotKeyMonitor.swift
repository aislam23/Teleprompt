import AppKit

/// Maps a key combination to a controller action.
struct HotKeyBinding {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let action: (PrompterController) -> Void
}

/// Manages global + local NSEvent monitors for the fixed v1 hotkey set.
///
/// Global monitor requires "Input Monitoring" permission. Without it, the local monitor still
/// fires whenever the settings window has key focus.
@MainActor
final class HotKeyMonitor {
    private weak var controller: PrompterController?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let bindings: [HotKeyBinding]

    init(controller: PrompterController) {
        self.controller = controller

        // ⌥⌘ on every binding.
        let mods: NSEvent.ModifierFlags = [.option, .command]

        self.bindings = [
            // ⌥⌘ Space — Play/Pause
            HotKeyBinding(keyCode: 0x31, modifiers: mods) { $0.togglePlay() },
            // ⌥⌘ ↑   — Speed +10%
            HotKeyBinding(keyCode: 0x7E, modifiers: mods) { $0.adjustSpeed(by: +0.10) },
            // ⌥⌘ ↓   — Speed -10%
            HotKeyBinding(keyCode: 0x7D, modifiers: mods) { $0.adjustSpeed(by: -0.10) },
            // ⌥⌘ ←   — Reset to start
            HotKeyBinding(keyCode: 0x7B, modifiers: mods) { $0.resetToStart() },
            // ⌥⌘ →   — Skip to end
            HotKeyBinding(keyCode: 0x7C, modifiers: mods) { $0.skipToEnd() },
            // ⌥⌘ H   — Show/hide
            HotKeyBinding(keyCode: 0x04, modifiers: mods) { $0.toggleVisible() },
            // ⌥⌘ L   — Toggle lock (click-through)
            HotKeyBinding(keyCode: 0x25, modifiers: mods) { $0.toggleLock() },
        ]
    }

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                _ = self?.handle(event: event, isLocal: false)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { () -> NSEvent? in
                guard let self else { return event }
                return self.handle(event: event, isLocal: true) ? nil : event
            }
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor  { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private func handle(event: NSEvent, isLocal: Bool) -> Bool {
        guard let controller else { return false }
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        for binding in bindings {
            if event.keyCode == binding.keyCode && mods.contains(binding.modifiers) {
                binding.action(controller)
                return true
            }
        }
        return false
    }

    /// Best-effort permission check — ask whether we can post system-wide events. Sufficient for
    /// distinguishing "you should see Input Monitoring banner" from "you're good".
    static func isAuthorized() -> Bool {
        // There's no public API that strictly tests Input Monitoring without prompting,
        // but checking AXIsProcessTrusted gives a reasonable proxy: most users grant both
        // permissions together, and NSEvent.addGlobalMonitorForEvents tends to silently no-op
        // until either is granted.
        return AXIsProcessTrusted()
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
