import CoreMotion
import Foundation

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()

    @Published private(set) var latestMotion: CMDeviceMotion?

    func start() {
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, _ in
            self?.latestMotion = motion
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    deinit {
        stop()
    }
}

