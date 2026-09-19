import Foundation

/// Smooth random bumps that repeat: octaves of value noise, each a random value
/// per cell eased into the next, summed. Used for the strip's hills and the
/// backdrop's ridges.
enum ValueNoise {
    /// `count` samples spread evenly over one `period`, wrapping seamlessly.
    /// Each octave is a wavelength and an amplitude, in the period's units.
    static func periodic(
        _ rng: inout SeededRNG, count: Int, period: Double, octaves: [(Double, Double)]
    ) -> [Double] {
        var out = [Double](repeating: 0, count: count)
        for (wavelength, amplitude) in octaves {
            let cells = max(1, Int((period / wavelength).rounded()))
            let values = (0..<cells).map { _ in rng.unit() * 2 - 1 }
            for i in 0..<count {
                let u = Double(i) / Double(count) * Double(cells)
                let c = Int(u.rounded(.down))
                let f = u - Double(c)
                let s = f * f * (3 - 2 * f)
                out[i] += amplitude * (values[c % cells] * (1 - s) + values[(c + 1) % cells] * s)
            }
        }
        return out
    }
}
