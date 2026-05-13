import AppKit
import SwiftUI

struct ColorRGBA: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    static let white  = ColorRGBA(r: 1, g: 1, b: 1, a: 1)
    static let black  = ColorRGBA(r: 0, g: 0, b: 0, a: 1)
    static let clear  = ColorRGBA(r: 0, g: 0, b: 0, a: 0)

    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? .white
        self.init(r: Double(c.redComponent),
                  g: Double(c.greenComponent),
                  b: Double(c.blueComponent),
                  a: Double(c.alphaComponent))
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum DefaultsKey {
    static let script               = "script"
    static let fontName             = "fontName"
    static let fontSize             = "fontSize"
    static let textColor            = "textColor"
    static let bgColor              = "bgColor"
    static let bgOpacity            = "bgOpacity"
    static let speed                = "speed"
    static let panelWidth           = "panelWidth"
    static let panelHeight          = "panelHeight"
    static let isLocked             = "isLocked"
    static let isVisible            = "isVisible"
    static let debugCaptureVisible  = "debugCaptureVisible"
}

enum SettingsDefaults {
    static let script: String = """
    Welcome to Telesouffleur. Type or paste your script in the settings window.

    Use ⌥⌘Space to play or pause. Use ⌥⌘↑ and ⌥⌘↓ to adjust speed. Use ⌥⌘← to reset to the start. Use ⌥⌘L to toggle click-through. Use ⌥⌘H to show or hide the prompter.

    Look at the camera. Read naturally. Smile.
    """
    static let fontName    = "Helvetica Neue"
    static let fontSize: CGFloat = 18
    static let textColor   = ColorRGBA.white
    static let bgColor     = ColorRGBA.black
    static let bgOpacity: Double = 1.0
    static let speed: Double = 40       // points per second
    /// Computed via `NotchGeometry.suggestedPanelWidth()` at first launch when no value is stored.
    static let panelWidthFallback:  CGFloat = 320
    static let panelHeight: CGFloat = 60
    static let isLocked:  Bool = true
    static let isVisible: Bool = true
    static let debugCaptureVisible: Bool = false
}

/// Helpers for dealing with the MacBook notch geometry.
enum NotchGeometry {
    /// Width of the actual notch (the camera cutout), in points, on the given screen.
    /// Returns 0 when the screen has no notch.
    static func notchWidth(on screen: NSScreen?) -> CGFloat {
        guard let screen, screen.safeAreaInsets.top > 0 else { return 0 }
        let leftAux  = screen.auxiliaryTopLeftArea?.width  ?? 0
        let rightAux = screen.auxiliaryTopRightArea?.width ?? 0
        let total = screen.frame.width
        let notch = total - leftAux - rightAux
        return max(0, notch)
    }

    /// A reasonable starting panel width: notch width + a small margin, or a fallback when
    /// no notch is detected.
    static func suggestedPanelWidth() -> CGFloat {
        let nw = notchWidth(on: NSScreen.main)
        if nw > 0 { return nw + 80 }
        return SettingsDefaults.panelWidthFallback
    }
}

/// Thin layer over UserDefaults for codable values.
enum Defaults {
    static let suite = UserDefaults.standard

    static func string(_ key: String, default value: String) -> String {
        suite.string(forKey: key) ?? value
    }
    static func double(_ key: String, default value: Double) -> Double {
        suite.object(forKey: key) as? Double ?? value
    }
    static func cgFloat(_ key: String, default value: CGFloat) -> CGFloat {
        if let n = suite.object(forKey: key) as? NSNumber { return CGFloat(n.doubleValue) }
        return value
    }
    static func bool(_ key: String, default value: Bool) -> Bool {
        suite.object(forKey: key) as? Bool ?? value
    }
    static func color(_ key: String, default value: ColorRGBA) -> ColorRGBA {
        guard let data = suite.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ColorRGBA.self, from: data)
        else { return value }
        return decoded
    }

    static func setColor(_ key: String, _ value: ColorRGBA) {
        if let data = try? JSONEncoder().encode(value) {
            suite.set(data, forKey: key)
        }
    }
}
