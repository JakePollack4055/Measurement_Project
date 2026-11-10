import Foundation

struct OrientationRecord: Codable {
    let id: UUID
    let timestamp: Date
    let headingDegrees: Double
    let pitchDegrees: Double
    let rollDegrees: Double
    let yawDegrees: Double
    let camera: String
    let target: String
    let classification: String
}

