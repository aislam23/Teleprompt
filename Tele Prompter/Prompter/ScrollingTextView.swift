import AppKit
import SwiftUI

/// Wraps an NSScrollView + NSTextView and drives 60fps auto-scroll from PrompterController.
/// Manual scroll (when the panel is unlocked) keeps the controller's scrollOffset in sync.
struct ScrollingTextView: NSViewRepresentable {
    var controller: PrompterController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        // Force a full redraw on every scroll. The default `copiesOnScroll = true` blits the
        // existing layer contents and only redraws the newly exposed strip — at fractional
        // scroll offsets that produces visible horizontal banding ("ripples") through the text.
        scrollView.contentView.copiesOnScroll = false
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.wantsLayer = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 24, height: 0)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.controller = controller
        context.coordinator.applyContent()
        context.coordinator.applyResetIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var controller: PrompterController
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
        private var timer: Timer?
        private var lastTick: CFTimeInterval = 0
        private var lastSeenResetToken: Int = .min
        private var suppressBoundsObserver: Bool = false

        init(controller: PrompterController) {
            self.controller = controller
            super.init()
        }

        func attach(scrollView: NSScrollView, textView: NSTextView) {
            self.scrollView = scrollView
            self.textView = textView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            startTimer()
        }

        func detach() {
            NotificationCenter.default.removeObserver(self)
            timer?.invalidate()
            timer = nil
        }

        private func startTimer() {
            timer?.invalidate()
            lastTick = CACurrentMediaTime()
            let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }

        @objc private func boundsDidChange(_ note: Notification) {
            guard !suppressBoundsObserver,
                  let clip = note.object as? NSClipView else { return }
            controller.scrollOffset = clip.bounds.origin.y
        }

        private func tick() {
            let now = CACurrentMediaTime()
            let dt = now - lastTick
            lastTick = now

            if controller.isPlaying {
                let proposed = controller.scrollOffset + CGFloat(controller.speed) * CGFloat(dt)
                applyOffset(proposed, syncController: true)
            }
        }

        /// Re-render attributed text and re-layout when the controller content/style changes.
        func applyContent() {
            guard let textView, let scrollView else { return }

            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineSpacing = 6
            para.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: controller.nsFont,
                .foregroundColor: controller.textColor.nsColor,
                .paragraphStyle: para,
            ]

            let attributed = NSAttributedString(string: controller.script, attributes: attributes)
            textView.textStorage?.setAttributedString(attributed)

            // Inset top/bottom by half the visible height so text starts mid-panel and can fully exit.
            let visibleH = scrollView.contentView.bounds.height
            let pad = max(0, visibleH / 2)
            textView.textContainerInset = NSSize(width: 24, height: pad)

            // Re-layout
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            textView.sizeToFit()
        }

        /// Apply scrollOffset programmatically. `syncController` writes the clamped value back.
        private func applyOffset(_ offset: CGFloat, syncController: Bool) {
            guard let textView, let scrollView else { return }
            let docHeight = textView.frame.height
            let visibleH = scrollView.contentView.bounds.height
            let maxY = max(0, docHeight - visibleH)
            let clamped = max(0, min(offset, maxY))

            // Snap the visual scroll position to the device pixel grid so glyphs don't
            // straddle half-pixels mid-scroll (another source of horizontal banding).
            let scale = scrollView.window?.backingScaleFactor ?? 2.0
            let snapped = (clamped * scale).rounded() / scale

            suppressBoundsObserver = true
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: snapped))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            suppressBoundsObserver = false

            if syncController {
                controller.scrollOffset = clamped
            }
        }

        /// Honor controller.scrollResetToken — applied on next update tick.
        func applyResetIfNeeded() {
            if controller.scrollResetToken != lastSeenResetToken {
                lastSeenResetToken = controller.scrollResetToken
                applyOffset(controller.scrollOffset, syncController: true)
            }
        }
    }
}
