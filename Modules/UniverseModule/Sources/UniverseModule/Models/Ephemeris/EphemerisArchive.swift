import CryptoKit
import Foundation
import simd

/// Immutable, shared archive. Loading/checksums happen during preparation, never in the frame loop.
struct EphemerisArchive: CelestialStateProviding {
    struct Manifest: Decodable {
        struct Body: Decodable {
            let filename: String
            let count: Int
            let sha256: String
        }
        let version: Int
        let frame: String
        let timeScale: String
        let recordFormat: String
        let startSeconds: Double
        let endSeconds: Double
        let orientationSHA256: String
        let bodies: [String: Body]
    }

    struct Record: Sendable {
        let time: Double
        let position: SIMD3<Double>
        let velocity: SIMD3<Double>
    }

    static let bundled: Result<EphemerisArchive, CelestialStateError> = {
        do { return .success(try load()) } catch { return .failure(.invalidData) }
    }()
    private static let calendarStart = SimulationTime.tdbSeconds(for: Date(timeIntervalSince1970: 946_684_800))
    private static let calendarEnd = SimulationTime.tdbSeconds(for: Date(timeIntervalSince1970: 4_133_980_800))

    let startSeconds: Double
    let endSeconds: Double
    var coverage: ClosedRange<Double>? { max(startSeconds, Self.calendarStart)...min(endSeconds, Self.calendarEnd.nextDown) }
    private let records: [CelestialBodyID: [Record]]
    private let orientation: IAUOrientation

    static func load(directory: URL? = nil) throws -> Self {
        guard let directory = directory ?? Bundle.module.url(forResource: "Ephemeris", withExtension: nil) else {
            throw CelestialStateError.invalidData
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
        guard manifest.version == 1, manifest.frame == "heliocentric-ecliptic-J2000", manifest.timeScale == "TDB",
              manifest.recordFormat == "little-endian-7-float64", manifest.startSeconds.isFinite,
              manifest.endSeconds.isFinite, manifest.endSeconds > manifest.startSeconds else { throw CelestialStateError.invalidData }
        let orientationData = try Data(contentsOf: directory.appendingPathComponent("orientation.json"))
        guard checksum(orientationData) == manifest.orientationSHA256 else { throw CelestialStateError.invalidData }
        let orientation = try JSONDecoder().decode(IAUOrientation.self, from: orientationData)
        var records: [CelestialBodyID: [Record]] = [:]
        for body in CelestialBodyID.allCases {
            guard orientation.bodies[body.rawValue]?.isValid == true else { throw CelestialStateError.invalidData }
            if body == .sun { continue }
            guard let entry = manifest.bodies[body.rawValue], entry.count >= 2,
                  entry.filename == body.rawValue.lowercased() + ".bin" else { throw CelestialStateError.invalidData }
            let data = try Data(contentsOf: directory.appendingPathComponent(entry.filename), options: .mappedIfSafe)
            guard entry.count <= data.count / 56, data.count == entry.count * 56,
                  checksum(data) == entry.sha256 else { throw CelestialStateError.invalidData }
            let decoded: [Record] = data.withUnsafeBytes { bytes in
                func number(_ offset: Int) -> Double {
                    Double(bitPattern: UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self)))
                }
                return (0..<entry.count).map { index in
                    let offset = index * 56
                    return Record(time: number(offset), position: SIMD3(number(offset+8), number(offset+16), number(offset+24)),
                                  velocity: SIMD3(number(offset+32), number(offset+40), number(offset+48)))
                }
            }
            guard decoded.first?.time == manifest.startSeconds, decoded.last?.time == manifest.endSeconds,
                  decoded.allSatisfy({ $0.time.isFinite && simd_length($0.position).isFinite && simd_length($0.velocity).isFinite }),
                  zip(decoded, decoded.dropFirst()).allSatisfy({ $0.time < $1.time }) else { throw CelestialStateError.invalidData }
            records[body] = decoded
        }
        return Self(startSeconds: manifest.startSeconds, endSeconds: manifest.endSeconds, records: records, orientation: orientation)
    }

    private static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        guard seconds.isFinite, seconds >= startSeconds, seconds <= endSeconds,
              seconds >= Self.calendarStart, seconds < Self.calendarEnd else { throw CelestialStateError.outsideCoverage }
        guard let model = orientation.bodies[body.rawValue] else { throw CelestialStateError.unknownBody }
        if body == .sun {
            return CelestialBodyState(positionKm: .zero, velocityKmPerSecond: .zero, bodyFixedToEcliptic: model.matrix(at: seconds))
        }
        guard let rows = records[body] else { throw CelestialStateError.unknownBody }
        var low = 0
        var high = rows.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if rows[middle].time <= seconds { low = middle } else { high = middle }
        }
        let orbital = Self.interpolate(rows[low], rows[high], at: seconds)
        return CelestialBodyState(positionKm: orbital.position, velocityKmPerSecond: orbital.velocity,
                                  bodyFixedToEcliptic: model.matrix(at: seconds))
    }

    static func interpolate(_ left: Record, _ right: Record, at seconds: Double) -> OrbitalState {
        let duration = right.time - left.time
        let fraction = (seconds - left.time) / duration
        let squared = fraction * fraction
        let cubed = squared * fraction
        let position = (2*cubed - 3*squared + 1) * left.position + (cubed - 2*squared + fraction) * duration * left.velocity +
            (-2*cubed + 3*squared) * right.position + (cubed - squared) * duration * right.velocity
        let velocity = (6*squared - 6*fraction) / duration * left.position + (3*squared - 4*fraction + 1) * left.velocity +
            (-6*squared + 6*fraction) / duration * right.position + (3*squared - 2*fraction) * right.velocity
        return OrbitalState(position: position, velocity: velocity)
    }
}
