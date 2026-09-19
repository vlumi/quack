import QuackCore
import SpriteKit

/// The biplane, drawn from a livery, as a rig that can roll. Geometry is in
/// design units with the nose along +x and the design sheet's y (down)
/// flipped to SpriteKit's (up); 24 units make a metre. Each part knows its
/// height above the fuselage axis and its depth toward the camera, so a roll
/// angle projects every part to where it belongs: side-view parts squash by
/// cos φ about their own line, wings and tailplane are re-drawn from their
/// projected corners with a mild perspective and split where they pass behind
/// the body, struts join the wings' projected corners, and the pilot is a
/// sphere at head height. At φ = 0 it is the side view; at π the same,
/// mirrored, which is the sim's `inverted`.
public final class PlaneNode: SKNode {
    /// Roll about the long axis, 0 (upright, side view) to π (inverted).
    public var roll: CGFloat = 0 {
        didSet { if roll != oldValue { layout() } }
    }
    /// Enamel highlights; the scene sets the alpha from the sun.
    public var gloss: SKNode { p.gloss }

    private let b: PlaneBuilder
    private let p: Parts

    /// Every part of the rig, built once; the roll only moves them.
    struct Parts {
        let prop: SKNode
        let body: SKNode
        let hub: SKNode
        let skid: SKNode
        let vent: SKNode
        let gear: SKNode
        let cockpitSide: SKNode
        let cockpitTop: SKNode
        let pilot = SKNode()
        let pilotSide: SKNode
        let pilotTop: SKNode
        let windSide: SKNode
        let windTop: SKNode
        let gunSide: SKNode
        let gunTop: SKNode
        let tailCap: SKNode
        let fin: SKNode
        let lowerCap: SKNode
        let upperCap: SKNode
        let tail: Planform
        let lower: Planform
        let upper: Planform
        let nearStruts = SKShapeNode()
        let farStruts = SKShapeNode()
        let gloss: SKNode

        // The rig itself, one part a line: data, not logic.
        // swiftlint:disable:next function_body_length
        init(_ b: PlaneBuilder) {
            let ink = PlaneArt.ink
            prop = b.node(
                b.ellipse(cx: 75, cy: 0, rx: 4, ry: 24, fill: ink.withAlphaComponent(0.28)))
            body = b.node(b.fill(b.fuselage(), b.body), b.fill(b.cowl(), b.trim))
            hub = b.node(b.circle(cx: 73, cy: 0, r: 4.5, fill: ink, line: 0))
            skid = b.node(b.stroke(b.line((-60, 6), (-64, 13)), 2.8))
            vent = b.node(b.fill(b.rect(x: 52, y: -4, w: 4, h: 8, r: 1), ink, line: 0))
            gear = b.node(
                b.stroke(b.open((30, 17), (36, 29), (44, 17)), 2.8),
                b.circle(cx: 36, cy: 32, r: 9, fill: ink, line: 0),
                b.circle(cx: 36, cy: 32, r: 3, fill: b.wing, line: 0))
            cockpitSide = b.pivoted(b.node(b.fill(b.cockpit(), ink)), y0: -9)
            cockpitTop = b.node(b.ellipse(cx: -18, cy: 0, rx: 13, ry: 9, fill: ink))
            pilotSide = b.sideHead()
            pilotTop = b.topHead()
            windSide = b.pivoted(b.sideWindscreen(), y0: -19.5)
            windTop = b.topWindscreen()
            gunSide = b.pivoted(b.sideGun(), y0: -18)
            gunTop = b.topGun()
            tailCap = b.pivoted(
                b.node(
                    b.fill(b.airfoil(xTE: -74, xLE: -38, t: 6, y0: 0), b.wing),
                    b.stroke(b.line((-61, -2.4), (-61, 2.1)), 1.5)),
                y0: 0)
            fin = b.node(
                b.fill(b.poly((-66, -4), (-60, -38), q: (-58, -42), (-52, -40), (-30, -6)), b.body),
                b.emblemNode(at: (-52.5, -21), radius: 8))
            lowerCap = b.pivoted(
                b.node(b.fill(b.airfoil(xTE: -14, xLE: 46, t: 8, y0: 15), b.wing)), y0: 15)
            upperCap = b.pivoted(
                b.node(b.fill(b.airfoil(xTE: -6, xLE: 60, t: 9, y0: -36), b.wing)), y0: -36)
            tail = Planform(
                b: b, u: 0, xTE: -74, xLE: -40, span: 16, bulge: 12, radius: 4, emblems: [])
            lower = Planform(
                b: b, u: -15, xTE: -14, xLE: 46, span: 74, bulge: 18, radius: PlaneArt.bodyRadius,
                emblems: [])
            upper = Planform(
                b: b, u: 36, xTE: -6, xLE: 60, span: 82, bulge: 20, radius: PlaneArt.bodyRadius,
                emblems: [(27, -78), (27, 78)])
            gloss = b.gloss()
            pilot.addChild(pilotSide)
            pilot.addChild(pilotTop)
            for n in [nearStruts, farStruts] {
                n.strokeColor = ink
                n.lineWidth = 2.8 * b.s
                n.lineCap = .round
                n.fillColor = .clear
            }
        }

        /// Back to front.
        var order: [SKNode] {
            [
                farStruts, lower.back, upper.back, tail.back,
                prop, body, skid, vent, gear, cockpitSide, cockpitTop, pilot, windSide, windTop,
                gunSide, gunTop,
                tail.front, tailCap, fin,
                lower.front, lowerCap, nearStruts, upper.front, upperCap, hub, gloss,
            ]
        }
    }

    public init(livery: Livery, pointsPerMetre: CGFloat) {
        b = PlaneBuilder(scale: pointsPerMetre / PlaneArt.unitsPerMetre, livery: livery)
        p = Parts(b)
        super.init()
        for (i, n) in p.order.enumerated() {
            n.zPosition = CGFloat(i)
            addChild(n)
        }
        layout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: The roll

    private func layout() {
        let c = cos(roll), sn = sin(roll)
        layoutBody(c: c, sn: sn)
        layoutWings(c: c, sn: sn)
    }

    /// Screen y (design, down) of a point at height u and depth z.
    private func yd(_ u: CGFloat, _ z: CGFloat, _ c: CGFloat, _ sn: CGFloat) -> CGFloat {
        -u * c + z * sn
    }

    /// A side-view part pivoted on its own line, standing at height u and depth z.
    private func place(
        _ n: SKNode, u: CGFloat, z: CGFloat, c: CGFloat, sn: CGFloat, alpha: CGFloat = 1
    ) {
        n.position.y = -yd(u, z, c, sn) * b.s
        n.yScale = c
        n.alpha = alpha
    }

    /// A part drawn as seen from above, lying at height u on the centreline.
    private func top(_ n: SKNode, u: CGFloat, c: CGFloat, sn: CGFloat) {
        let k = PlaneArt.project(x: 0, u: u, z: 0, c: c, sn: sn).k
        n.position.y = -yd(u, 0, c, sn) * b.s
        n.xScale = k
        n.yScale = k * sn
        n.alpha = sn * sn
    }

    private func layoutBody(c: CGFloat, sn: CGFloat) {
        let ac = abs(c)
        p.skid.yScale = c
        p.fin.yScale = c
        p.vent.position.y = -(14 * sn * (c >= 0 ? 1 : -1)) * b.s
        p.vent.yScale = ac
        p.vent.alpha = ac
        p.gear.position.y = -(10 * sn) * b.s
        p.gear.yScale = c
        place(p.cockpitSide, u: 9, z: 0, c: c, sn: sn, alpha: c * c)
        top(p.cockpitTop, u: 9, c: c, sn: sn)
        place(p.windSide, u: 19.5, z: 0, c: c, sn: sn, alpha: c * c)
        top(p.windTop, u: 19.5, c: c, sn: sn)
        place(p.gunSide, u: 18, z: 0, c: c, sn: sn, alpha: c * c)
        top(p.gunTop, u: 18, c: c, sn: sn)
        // The pilot: a sphere at head height, side head away from 90°, helmet from above near it.
        let ps = max(0, min(1, 0.5 + 3 * (ac - sn)))
        let head = PlaneArt.project(x: -18, u: 23, z: 0, c: c, sn: sn)
        p.pilot.position = b.pt(head.x, head.y)
        p.pilot.setScale(head.k)
        p.pilotSide.yScale = c >= 0 ? 1 : -1
        p.pilotSide.alpha = ps
        p.pilotTop.alpha = 1 - ps
    }

    private func layoutWings(c: CGFloat, sn: CGFloat) {
        // The edge-on wing sections are the side view's wings; they hand over to the plan-forms quickly.
        let cap = max(0, 1 - 2.5 * sn)
        place(p.tailCap, u: 0, z: 28, c: c, sn: sn, alpha: cap)
        place(p.lowerCap, u: -15, z: 92, c: c, sn: sn, alpha: cap)
        place(p.upperCap, u: 36, z: 100, c: c, sn: sn, alpha: cap)
        p.tail.layout(c: c, sn: sn)
        p.lower.layout(c: c, sn: sn)
        p.upper.layout(c: c, sn: sn)
        let nearZ: CGFloat = c >= 0 ? 70 : -70
        p.nearStruts.path = b.struts(z: nearZ, c: c, sn: sn)
        p.farStruts.path = b.struts(z: -nearZ, c: c, sn: sn)
        p.gloss.yScale = c
        p.gloss.alpha = c * c
    }
}
