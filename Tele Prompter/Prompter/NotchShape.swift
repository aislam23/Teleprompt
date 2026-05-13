import SwiftUI

/// Shape of the prompter body. Drawn so it looks like a logical extension of the MacBook notch:
/// flat top edge that tucks a few points up into the notch area (so there's no visible seam
/// between the OS notch and the prompter), and rounded bottom-left/bottom-right corners only.
///
/// Drawn in the panel's own coordinate space (origin at top-left, y increases downward).
struct NotchExtendedShape: Shape {
    /// Notch height in points (typically `screen.safeAreaInsets.top`). The prompter's filled
    /// area starts at `notchHeight - topOverlap` so it slides under the notch.
    var notchHeight: CGFloat
    /// How many points the prompter's top edge overlaps upward into the notch / menu-bar area.
    /// A small value (~4–8pt) eliminates the visible seam at the notch base.
    var topOverlap: CGFloat
    /// Radius of the two convex bottom corners.
    var cornerRadius: CGFloat
    /// 0 = body collapsed into the notch (invisible), 1 = fully extended to bottom of rect.
    /// Two-axis: `.first` is vertical extension, `.second` is horizontal expansion (0 → narrow
    /// neck flush with the notch sides, 1 → full panel width). Animating both gives the
    /// Dynamic-Island-style "blob growing out of the notch" feel.
    var expansion: CGFloat
    var widthExpansion: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(expansion, widthExpansion) }
        set {
            expansion = newValue.first
            widthExpansion = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let W = rect.width
        let H = rect.height

        let topY = max(0, notchHeight - topOverlap)
        let e = max(0, min(1, expansion))
        let we = max(0, min(1, widthExpansion))

        // Vertical: collapsed bottom sits at `notchHeight` (hidden by the OS notch).
        let collapsedBottom = notchHeight
        let bottomY = collapsedBottom + (H - collapsedBottom) * e

        // Horizontal: shrink toward a "neck" that approximates the notch base width when
        // collapsed, blooming out to the full panel width as we expand.
        let neckHalfWidth = min(W / 2, max(60, notchHeight * 3))   // rough Dynamic-Island neck
        let halfWidth = neckHalfWidth + (W / 2 - neckHalfWidth) * we
        let leftX  = W / 2 - halfWidth
        let rightX = W / 2 + halfWidth
        let usableW = rightX - leftX

        let r = max(0, min(cornerRadius, min(usableW / 2, (bottomY - topY) / 2)))

        // Top edge sits behind the notch — sharp corners are fine, the OS notch hides them.
        p.move(to: CGPoint(x: leftX, y: topY))
        p.addLine(to: CGPoint(x: rightX, y: topY))
        p.addLine(to: CGPoint(x: rightX, y: bottomY - r))
        p.addQuadCurve(to: CGPoint(x: rightX - r, y: bottomY),
                       control: CGPoint(x: rightX, y: bottomY))
        p.addLine(to: CGPoint(x: leftX + r, y: bottomY))
        p.addQuadCurve(to: CGPoint(x: leftX, y: bottomY - r),
                       control: CGPoint(x: leftX, y: bottomY))
        p.closeSubpath()
        return p
    }
}
