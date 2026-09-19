import QuackCore
import SwiftUI

/// What the thumbs are doing, in view points, for the overlay to draw. The
/// controls write it on touch events; the overlay reads it.
public final class ThumbOverlayState: ObservableObject {
    /// Where the pitch pad sits: the last landing point, or nil before any touch.
    @Published var pitchOrigin: CGPoint?
    /// The thumb's current point while engaged.
    @Published var pitchKnob: CGPoint?
    /// Points of drag for full elevator in each direction from the origin; the
    /// throw shrinks to the room available toward the screen's edge.
    @Published var throwUp: CGFloat = 80
    @Published var throwDown: CGFloat = 80
    @Published var pitch: Double = 0
    @Published var fireOrigin: CGPoint?
    @Published var firing = false

    public init() {}
}

/// Translucent thumb chrome over the whole screen, letterbox bars included:
/// a pitch pad on the left and a trigger on the right. Both float to where
/// the thumb lands and stay, dimmed, where it left them, so a new player sees
/// where to press before pressing. Draw-only; touches go to the scene.
struct ThumbOverlay: View {
    @ObservedObject var state: ThumbOverlayState
    var pitchInverted = false

    private let ink = Color(red: 0.12, green: 0.12, blue: 0.12)

    var body: some View {
        Canvas { context, size in
            drawPitchPad(&context, size: size)
            drawTrigger(&context, size: size)
        }
        .allowsHitTesting(false)
    }

    /// Resting places before the first touch: low, inside each thumb's reach.
    private func restingPitch(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.18, y: size.height * 0.62)
    }

    private func restingFire(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.82, y: size.height * 0.62)
    }

    private func drawPitchPad(_ context: inout GraphicsContext, size: CGSize) {
        let engaged = state.pitchKnob != nil
        let rest = engaged ? 1.0 : 0.5
        let origin = state.pitchOrigin ?? restingPitch(size)
        let up = engaged ? state.throwUp : 80
        let down = engaged ? state.throwDown : 80
        // The track: the range the thumb can travel, top to bottom.
        let track = CGRect(x: origin.x - 22, y: origin.y - up, width: 44, height: up + down)
        context.fill(
            Path(roundedRect: track, cornerRadius: 22), with: .color(.white.opacity(0.14 * rest)))
        context.stroke(
            Path(roundedRect: track, cornerRadius: 22), with: .color(ink.opacity(0.45 * rest)),
            lineWidth: 1.5)
        // Centre mark: where level is.
        var cross = Path()
        cross.move(to: CGPoint(x: origin.x - 8, y: origin.y))
        cross.addLine(to: CGPoint(x: origin.x + 8, y: origin.y))
        context.stroke(cross, with: .color(ink.opacity(0.8 * rest)), lineWidth: 2)
        // The bar to the knob: how much elevator is in.
        if let knob = state.pitchKnob {
            let y = min(max(knob.y, origin.y - up), origin.y + down)
            var bar = Path()
            bar.move(to: origin)
            bar.addLine(to: CGPoint(x: origin.x, y: y))
            context.stroke(bar, with: .color(ink.opacity(0.7)), lineWidth: 4)
            let dot = CGRect(x: origin.x - 9, y: y - 9, width: 18, height: 18)
            context.fill(Path(ellipseIn: dot), with: .color(ink.opacity(0.9)))
        }
        // Chevrons: which way is nose up. Pulling toward you (down) lifts the
        // nose unless inverted, and the lit one shows the elevator's sense.
        let noseUpIsDown = !pitchInverted
        let upLit = max(0, noseUpIsDown ? -state.pitch : state.pitch)
        let downLit = max(0, noseUpIsDown ? state.pitch : -state.pitch)
        chevron(
            &context, at: CGPoint(x: origin.x, y: origin.y - up - 14), pointingUp: true, lit: upLit,
            rest: rest)
        chevron(
            &context, at: CGPoint(x: origin.x, y: origin.y + down + 14), pointingUp: false,
            lit: downLit, rest: rest)
    }

    private func chevron(
        _ context: inout GraphicsContext, at p: CGPoint, pointingUp: Bool, lit: Double, rest: Double
    ) {
        let d: CGFloat = pointingUp ? -1 : 1
        var path = Path()
        path.move(to: CGPoint(x: p.x - 9, y: p.y - 5 * d))
        path.addLine(to: CGPoint(x: p.x, y: p.y + 5 * d))
        path.addLine(to: CGPoint(x: p.x + 9, y: p.y - 5 * d))
        let alpha = (0.35 + 0.65 * lit) * rest
        context.stroke(
            path, with: .color(ink.opacity(alpha)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }

    private func drawTrigger(_ context: inout GraphicsContext, size: CGSize) {
        let rest = state.firing ? 1.0 : 0.5
        let origin = state.fireOrigin ?? restingFire(size)
        let r: CGFloat = 34
        let ring = CGRect(x: origin.x - r, y: origin.y - r, width: 2 * r, height: 2 * r)
        context.fill(
            Path(ellipseIn: ring), with: .color(.white.opacity((state.firing ? 0.3 : 0.14) * rest)))
        context.stroke(
            Path(ellipseIn: ring), with: .color(ink.opacity(0.45 * rest)), lineWidth: 1.5)
        // A gun-sight: ring and dot, filling when held.
        let inner = ring.insetBy(dx: r * 0.55, dy: r * 0.55)
        context.stroke(Path(ellipseIn: inner), with: .color(ink.opacity(0.8 * rest)), lineWidth: 2)
        let dot = ring.insetBy(dx: r - 4, dy: r - 4)
        context.fill(
            Path(ellipseIn: dot), with: .color(ink.opacity((state.firing ? 0.95 : 0.6) * rest)))
    }
}
