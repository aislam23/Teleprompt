import AppKit
import SwiftUI

/// Borderless overlay panel pinned under the MacBook notch.
/// Hidden from screen capture (sharingType = .none) and configurable click-through.
final class PrompterPanel: NSPanel {

    private weak var controller: PrompterController?
    private var observation: NSObjectProtocol?

    init(controller: PrompterController) {
        self.controller = controller

        let frame = Self.computeFrame(width: controller.panelWidth, height: controller.panelHeight)

        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        // KEY: hide from screen capture, screenshots, screen sharing.
        // Toggleable via PrompterController.debugCaptureVisible.
        self.sharingType = controller.debugCaptureVisible ? .readOnly : .none

        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces,
                                   .stationary,
                                   .ignoresCycle,
                                   .fullScreenAuxiliary]

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.worksWhenModal = true
        // Click-through state syncs from controller via `applyControllerState`.
        self.ignoresMouseEvents = controller.isLocked

        let host = NSHostingView(rootView: PrompterView(controller: controller))
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.autoresizingMask = [.width, .height]
        self.contentView = host

        observation = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.repositionUnderNotch()
        }
    }

    deinit {
        if let observation { NotificationCenter.default.removeObserver(observation) }
    }

    /// Compute the panel frame so it sits flush against the **top of the screen**, covering the
    /// notch area as well. Total panel height = notch height + the user-configured extension
    /// (`controller.panelHeight`). Horizontally centered on the camera.
    /// On notch-less screens the panel just hugs the top with a small top-offset.
    static func computeFrame(width: CGFloat, height extensionHeight: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: width, height: extensionHeight)
        }
        let f = screen.frame
        let notchHeight = screen.safeAreaInsets.top
        let totalHeight = notchHeight + extensionHeight
        let x = f.midX - width / 2
        let y = f.maxY - totalHeight
        return NSRect(x: x, y: y, width: width, height: totalHeight)
    }

    func repositionUnderNotch() {
        guard let controller else { return }
        let f = Self.computeFrame(width: controller.panelWidth, height: controller.panelHeight)
        setFrame(f, display: true, animate: false)
    }

    func applyControllerState() {
        guard let controller else { return }
        // Stay alive across show/hide so the SwiftUI bounce-collapse animation can play.
        // When not visible, swallow no clicks so the desktop underneath stays interactive.
        ignoresMouseEvents = controller.isLocked || !controller.isVisible
        sharingType        = controller.debugCaptureVisible ? .readOnly : .none
        repositionUnderNotch()
        orderFrontRegardless()
    }

    // Keep behavior even though we never want focus — but allow first responder so
    // local key monitor inside this panel could fire if needed in future.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
