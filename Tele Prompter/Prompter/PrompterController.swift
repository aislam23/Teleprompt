import AppKit
import SwiftUI
import Observation

/// Single source of truth for the prompter UI. Persists every setting to UserDefaults on mutation.
@Observable
final class PrompterController {

    // MARK: - Persisted settings

    var script: String { didSet { Defaults.suite.set(script, forKey: DefaultsKey.script) } }

    var fontName: String { didSet { Defaults.suite.set(fontName, forKey: DefaultsKey.fontName) } }
    var fontSize: CGFloat { didSet { Defaults.suite.set(Double(fontSize), forKey: DefaultsKey.fontSize) } }

    var textColor: ColorRGBA { didSet { Defaults.setColor(DefaultsKey.textColor, textColor) } }
    var bgColor:   ColorRGBA { didSet { Defaults.setColor(DefaultsKey.bgColor,   bgColor) } }
    var bgOpacity: Double    { didSet { Defaults.suite.set(bgOpacity, forKey: DefaultsKey.bgOpacity) } }

    var speed: Double { didSet { Defaults.suite.set(speed, forKey: DefaultsKey.speed) } }

    var panelWidth:  CGFloat { didSet { Defaults.suite.set(Double(panelWidth),  forKey: DefaultsKey.panelWidth) } }
    var panelHeight: CGFloat { didSet { Defaults.suite.set(Double(panelHeight), forKey: DefaultsKey.panelHeight) } }

    var isLocked:  Bool { didSet { Defaults.suite.set(isLocked,  forKey: DefaultsKey.isLocked) } }
    var isVisible: Bool { didSet { Defaults.suite.set(isVisible, forKey: DefaultsKey.isVisible) } }

    /// When ON, the prompter window is captured by screenshots/screen recordings.
    /// Default OFF so the prompter remains private.
    var debugCaptureVisible: Bool { didSet { Defaults.suite.set(debugCaptureVisible, forKey: DefaultsKey.debugCaptureVisible) } }

    // MARK: - Transient state

    /// Auto-scroll on/off.
    var isPlaying: Bool = false

    /// Current vertical scroll offset within the prompter text view (top-anchored, in points).
    var scrollOffset: CGFloat = 0

    /// Bumped every time we want the scroll view to programmatically jump (e.g. reset to start).
    var scrollResetToken: Int = 0

    // MARK: - Init

    init() {
        Self.runMigrations()
        self.script              = Defaults.string(DefaultsKey.script,              default: SettingsDefaults.script)
        self.fontName            = Defaults.string(DefaultsKey.fontName,            default: SettingsDefaults.fontName)
        self.fontSize            = Defaults.cgFloat(DefaultsKey.fontSize,           default: SettingsDefaults.fontSize)
        self.textColor           = Defaults.color(DefaultsKey.textColor,            default: SettingsDefaults.textColor)
        self.bgColor             = Defaults.color(DefaultsKey.bgColor,              default: SettingsDefaults.bgColor)
        self.bgOpacity           = Defaults.double(DefaultsKey.bgOpacity,           default: SettingsDefaults.bgOpacity)
        self.speed               = Defaults.double(DefaultsKey.speed,               default: SettingsDefaults.speed)
        self.panelWidth          = Defaults.cgFloat(DefaultsKey.panelWidth,         default: NotchGeometry.suggestedPanelWidth())
        self.panelHeight         = Defaults.cgFloat(DefaultsKey.panelHeight,        default: SettingsDefaults.panelHeight)
        self.isLocked            = Defaults.bool(DefaultsKey.isLocked,              default: SettingsDefaults.isLocked)
        self.isVisible           = Defaults.bool(DefaultsKey.isVisible,             default: SettingsDefaults.isVisible)
        self.debugCaptureVisible = Defaults.bool(DefaultsKey.debugCaptureVisible,   default: SettingsDefaults.debugCaptureVisible)
    }

    /// Snap panel size to the notch width + small margin. Useful as a "reset" action.
    func matchPanelToNotch() {
        panelWidth  = NotchGeometry.suggestedPanelWidth()
        panelHeight = SettingsDefaults.panelHeight
    }

    /// One-time migrations of UserDefaults across app versions. Idempotent.
    private static func runMigrations() {
        let key = "telesouffleur.migration.compactDefaults.v1"
        if !Defaults.suite.bool(forKey: key) {
            Defaults.suite.set(true, forKey: key)
            // The earliest build shipped with 700×90 panel and 28pt font, which is way too wide
            // for a notch-anchored teleprompter. Drop those keys so the notch-aware fallbacks
            // apply on next read. User-customized values set after this migration are preserved.
            Defaults.suite.removeObject(forKey: DefaultsKey.panelWidth)
            Defaults.suite.removeObject(forKey: DefaultsKey.panelHeight)
            Defaults.suite.removeObject(forKey: DefaultsKey.fontSize)
        }
    }

    // MARK: - Actions

    func togglePlay()         { isPlaying.toggle() }
    func toggleLock()         { isLocked.toggle() }
    func toggleVisible()      { isVisible.toggle() }

    func adjustSpeed(by factor: Double) {
        // factor like +0.10 / -0.10
        speed = max(5, min(400, speed * (1 + factor)))
    }

    func resetToStart() {
        scrollOffset = 0
        scrollResetToken &+= 1
    }

    func skipToEnd() {
        // Use a sentinel; ScrollingTextView clamps to actual content height on apply.
        scrollOffset = .greatestFiniteMagnitude
        scrollResetToken &+= 1
    }

    var nsFont: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
}
