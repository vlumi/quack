import Foundation

/// Bytes on the wire, little-endian, hand-rolled: `Codable` is not a wire
/// format (Skid Jam measured 15× inflation from spelling keys per entry).
struct ByteWriter {
    private(set) var bytes: [UInt8] = []

    mutating func byte(_ v: UInt8) { bytes.append(v) }
    mutating func int32(_ v: Int32) {
        withUnsafeBytes(of: v.littleEndian) { bytes.append(contentsOf: $0) }
    }
    mutating func float(_ v: Double) {
        withUnsafeBytes(of: Float32(v).bitPattern.littleEndian) { bytes.append(contentsOf: $0) }
    }
    mutating func append(_ more: [UInt8]) { bytes.append(contentsOf: more) }
}

/// Reads what `ByteWriter` wrote; nil at the first byte that is not there.
struct ByteReader {
    private let bytes: [UInt8]
    private(set) var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var isDrained: Bool { offset == bytes.count }

    mutating func byte() -> UInt8? {
        guard offset < bytes.count else { return nil }
        defer { offset += 1 }
        return bytes[offset]
    }
    mutating func int32() -> Int32? {
        guard offset + 4 <= bytes.count else { return nil }
        var v: Int32 = 0
        withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: bytes[offset..<offset + 4]) }
        offset += 4
        return Int32(littleEndian: v)
    }
    mutating func float() -> Double? {
        guard offset + 4 <= bytes.count else { return nil }
        var v: UInt32 = 0
        withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: bytes[offset..<offset + 4]) }
        offset += 4
        return Double(Float32(bitPattern: UInt32(littleEndian: v)))
    }
    mutating func bytes(_ n: Int) -> [UInt8]? {
        guard n >= 0, offset + n <= bytes.count else { return nil }
        defer { offset += n }
        return Array(bytes[offset..<offset + n])
    }
}

/// A player's input as two bytes: the elevator to a hundredth, and flags for
/// power, fire and the takeoff request either way.
public struct PlaneInputWire: Equatable, Sendable {
    public static let byteCount = 2
    private let pitchByte: Int8
    private let flags: UInt8

    public init(_ input: PlaneInput) {
        pitchByte = Int8(max(-100, min(100, (input.pitch * 100).rounded())))
        var f: UInt8 = 0
        if input.power { f |= 1 }
        if input.fire { f |= 2 }
        if input.takeOff > 0 { f |= 4 }
        if input.takeOff < 0 { f |= 8 }
        flags = f
    }

    public var input: PlaneInput {
        PlaneInput(
            pitch: Double(pitchByte) / 100, power: flags & 1 != 0, fire: flags & 2 != 0,
            takeOff: flags & 4 != 0 ? 1 : (flags & 8 != 0 ? -1 : 0))
    }

    var bytes: [UInt8] { [UInt8(bitPattern: pitchByte), flags] }

    init?(bytes: [UInt8]) {
        guard bytes.count == PlaneInputWire.byteCount else { return nil }
        pitchByte = Int8(bitPattern: bytes[0])
        flags = bytes[1]
    }
}
