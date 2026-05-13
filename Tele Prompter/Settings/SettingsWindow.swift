import AppKit
import SwiftUI

/// SwiftUI form for editing every setting. The PrompterController is the single source of truth;
/// every binding writes directly back into it (which auto-persists to UserDefaults).
struct SettingsView: View {
    @Bindable var controller: PrompterController
    var hotKeysAuthorized: Bool
    var onOpenInputMonitoring: () -> Void
    var onTogglePrompter: () -> Void

    private let availableFonts: [String] = NSFontManager.shared
        .availableFontFamilies
        .sorted()

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                form
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 360)

            Divider()

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Script")
            TextEditor(text: $controller.script)
                .font(.system(size: 13, design: .monospaced))
                .frame(minHeight: 140)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))

            sectionHeader("Typography")
            HStack {
                Text("Font").frame(width: 70, alignment: .leading)
                Picker("", selection: $controller.fontName) {
                    ForEach(availableFonts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
            }
            HStack {
                Text("Size").frame(width: 70, alignment: .leading)
                Slider(value: $controller.fontSize, in: 16...96, step: 1)
                Text("\(Int(controller.fontSize)) pt").monospacedDigit().frame(width: 56, alignment: .trailing)
            }
            HStack {
                Text("Color").frame(width: 70, alignment: .leading)
                ColorPicker("", selection: textColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }

            sectionHeader("Background")
            HStack {
                Text("Color").frame(width: 70, alignment: .leading)
                ColorPicker("", selection: bgColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack {
                Text("Opacity").frame(width: 70, alignment: .leading)
                Slider(value: $controller.bgOpacity, in: 0...1)
                Text(String(format: "%.0f%%", controller.bgOpacity * 100)).monospacedDigit().frame(width: 56, alignment: .trailing)
            }

            sectionHeader("Scroll")
            HStack {
                Text("Speed").frame(width: 70, alignment: .leading)
                Slider(value: $controller.speed, in: 10...200)
                Text("\(Int(controller.speed)) pt/s").monospacedDigit().frame(width: 64, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Button(controller.isPlaying ? "Pause" : "Play") {
                    controller.togglePlay()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Reset to start") {
                    controller.resetToStart()
                }
            }

            sectionHeader("Panel size")
            HStack {
                Text("Width").frame(width: 70, alignment: .leading)
                Slider(value: $controller.panelWidth, in: 200...1200, step: 5)
                Text("\(Int(controller.panelWidth)) pt").monospacedDigit().frame(width: 64, alignment: .trailing)
            }
            HStack {
                Text("Height").frame(width: 70, alignment: .leading)
                Slider(value: $controller.panelHeight, in: 30...200, step: 5)
                Text("\(Int(controller.panelHeight)) pt").monospacedDigit().frame(width: 64, alignment: .trailing)
            }
            HStack {
                let nw = Int(NotchGeometry.notchWidth(on: NSScreen.main))
                Button("Match panel to notch") { controller.matchPanelToNotch() }
                    .help("Sets panel width to notch width + 80pt and height to a compact default.")
                if nw > 0 {
                    Text("notch ≈ \(nw) pt").font(.caption).foregroundStyle(.secondary)
                }
            }

            sectionHeader("Behavior")
            Toggle("Lock from clicks (click-through)", isOn: $controller.isLocked)
                .help("When locked, clicks pass through the prompter to whatever is below. Toggle off to scroll manually.")

            Toggle("Debug: visible in screenshots & screen recordings", isOn: $controller.debugCaptureVisible)
                .help("Default OFF means the prompter is invisible to QuickTime, screen sharing, and ⌘⇧3. Turn ON to take a screenshot or record a demo.")

            if controller.debugCaptureVisible {
                Text("⚠️ Prompter is currently CAPTURED by screenshots and screen recording.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 4)
            }

            HStack(spacing: 8) {
                Button(controller.isVisible ? "Hide prompter" : "Show prompter", action: onTogglePrompter)
            }

            if !hotKeysAuthorized {
                permissionsBanner
            }

            sectionHeader("Hotkeys")
            VStack(alignment: .leading, spacing: 4) {
                hotkeyRow("⌥⌘ Space", "Play / Pause")
                hotkeyRow("⌥⌘ ↑ / ↓",  "Speed +/- 10%")
                hotkeyRow("⌥⌘ ←",      "Reset to start")
                hotkeyRow("⌥⌘ →",      "Skip to end")
                hotkeyRow("⌥⌘ H",      "Show / hide prompter")
                hotkeyRow("⌥⌘ L",      "Toggle click-through")
            }
            .font(.system(size: 12))
        }
    }

    private var preview: some View {
        VStack(spacing: 12) {
            Text("Preview").font(.headline).foregroundStyle(.secondary)
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: min(controller.panelWidth, 540),
                           height: min(controller.panelHeight, 180))
                    .overlay(
                        controller.bgColor.swiftUIColor.opacity(controller.bgOpacity)
                    )
                    .overlay(
                        Text(String(controller.script.prefix(160)))
                            .font(.custom(controller.fontName, size: controller.fontSize * 0.6))
                            .foregroundStyle(controller.textColor.swiftUIColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .clipped()
                    )
                    .cornerRadius(6)
                    .shadow(radius: 8)
            }
            Text("Live preview — actual rendering happens under the notch.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
    }

    private var permissionsBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Global hotkeys need Input Monitoring", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Without this permission, hotkeys only work when the settings window is focused.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Open Privacy & Security…", action: onOpenInputMonitoring)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(.orange.opacity(0.12)))
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func hotkeyRow(_ keys: String, _ desc: String) -> some View {
        HStack {
            Text(keys).monospaced().frame(width: 110, alignment: .leading)
            Text(desc).foregroundStyle(.secondary)
        }
    }

    // MARK: Color bindings

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { controller.textColor.swiftUIColor },
            set: { newValue in
                controller.textColor = ColorRGBA(NSColor(newValue))
            }
        )
    }

    private var bgColorBinding: Binding<Color> {
        Binding(
            get: { controller.bgColor.swiftUIColor },
            set: { newValue in
                controller.bgColor = ColorRGBA(NSColor(newValue))
            }
        )
    }
}

/// Window controller that hosts SettingsView in a regular AppKit window.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private let controller: PrompterController
    private let onOpenInputMonitoring: () -> Void
    private let onTogglePrompter: () -> Void
    private let hotKeysAuthorized: () -> Bool

    init(controller: PrompterController,
         hotKeysAuthorized: @escaping () -> Bool,
         onOpenInputMonitoring: @escaping () -> Void,
         onTogglePrompter: @escaping () -> Void) {

        self.controller = controller
        self.hotKeysAuthorized = hotKeysAuthorized
        self.onOpenInputMonitoring = onOpenInputMonitoring
        self.onTogglePrompter = onTogglePrompter

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Telesouffleur"
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TelesouffleurSettings")
        super.init(window: window)
        window.delegate = self

        rebuildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func rebuildContent() {
        let view = SettingsView(
            controller: controller,
            hotKeysAuthorized: hotKeysAuthorized(),
            onOpenInputMonitoring: onOpenInputMonitoring,
            onTogglePrompter: onTogglePrompter
        )
        window?.contentView = NSHostingView(rootView: view)
    }

    func showAndFocus() {
        rebuildContent()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.orderFrontRegardless()
    }
}
