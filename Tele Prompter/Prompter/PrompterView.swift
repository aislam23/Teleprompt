import SwiftUI
import AppKit

/// SwiftUI root mounted inside the PrompterPanel.
///
/// Renders as a single rounded-bottom rectangle that tucks slightly up into the notch area,
/// so visually it looks like the OS notch grows downward into the prompter body.
struct PrompterView: View {
    @Bindable var controller: PrompterController

    private let cornerRadius: CGFloat = 18

    var body: some View {
        let notchH = NSScreen.main?.safeAreaInsets.top ?? 0
        let visible = controller.isVisible

        // Drive both axes from `isVisible`. Width settles a hair earlier than height so the
        // bloom reads as "neck widens, then body drops" — same ordering Apple uses for the
        // Dynamic Island. Both run on a bouncy spring (see `.animation` below).
        let expansion: CGFloat       = visible ? 1 : 0
        let widthExpansion: CGFloat  = visible ? 1 : 0

        let shape = NotchExtendedShape(
            notchHeight: notchH,
            topOverlap: notchH,
            cornerRadius: cornerRadius,
            expansion: expansion,
            widthExpansion: widthExpansion
        )

        ZStack {
            shape
                .fill(controller.bgColor.swiftUIColor.opacity(controller.bgOpacity))

            ScrollingTextView(controller: controller)
                .padding(.top, notchH)         // text never sneaks up into the notch area
                .opacity(visible ? 1 : 0)
        }
        .mask(shape)                           // also clips the scroll view to the shape
        .ignoresSafeArea()
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: visible)
    }
}
