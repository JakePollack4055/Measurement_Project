import Foundation

enum MeasurementStage: String {
    case firstBottom
    case secondBottom
    case thirdTop
    case complete
}

struct MeasurementSession {
    var stage: MeasurementStage = .firstBottom
    var baselineFeet: Double = 1.0
    var firstBottom: OrientationRecord?
    var secondBottom: OrientationRecord?
    var thirdTop: OrientationRecord?
    var distanceFeet: Double?
    var heightFeet: Double?
}

