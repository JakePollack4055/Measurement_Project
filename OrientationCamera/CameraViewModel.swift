import AVFoundation
import Photos
import SwiftUI

final class CameraViewModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()

    @Published var authorizationMessage: String?
    @Published var lastRecord: OrientationRecord?
    @Published private(set) var measurement = MeasurementSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let motionManager: MotionManager
    private var isConfigured = false
    private var pendingRecord: OrientationRecord?

    init(motionManager: MotionManager) {
        self.motionManager = motionManager
        super.init()
    }

    func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfigured else { return }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted { self.configure() }
                    else { DispatchQueue.main.async { self.authorizationMessage = "Camera access is required." } }
                }
            default:
                DispatchQueue.main.async { self.authorizationMessage = "Enable camera access in Settings." }
            }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
        motionManager.start()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
        motionManager.stop()
    }

    func capturePhoto() {
        guard measurement.stage != .complete else { return }

        let settings = AVCapturePhotoSettings()
        let record = makeRecord()
        pendingRecord = record
        lastRecord = record
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func setBaselineFeet(_ value: Double) {
        guard value > 0 else { return }
        measurement.baselineFeet = value
    }

    func resetMeasurement() {
        measurement = MeasurementSession(baselineFeet: measurement.baselineFeet)
        lastRecord = nil
        pendingRecord = nil
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else {
            DispatchQueue.main.async { self.authorizationMessage = "Unable to configure the camera." }
            return
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        isConfigured = true
    }

    private func makeRecord() -> OrientationRecord {
        let motion = motionManager.latestMotion
        let heading = motion?.heading ?? -1
        let pitch = radiansToDegrees(motion?.attitude.pitch ?? 0)
        let roll = radiansToDegrees(motion?.attitude.roll ?? 0)
        let yaw = radiansToDegrees(motion?.attitude.yaw ?? 0)

        return OrientationRecord(
            id: UUID(),
            timestamp: Date(),
            headingDegrees: heading,
            pitchDegrees: pitch,
            rollDegrees: roll,
            yawDegrees: yaw,
            camera: "rear",
            target: measurement.stage == .thirdTop ? "top" : "bottom",
            classification: classify(pitch: pitch, roll: roll)
        )
    }

    private func radiansToDegrees(_ value: Double) -> Double {
        value * 180.0 / .pi
    }

    private func classify(pitch: Double, roll: Double) -> String {
        let rollMagnitude = abs(roll)
        let pitchMagnitude = abs(pitch)

        if pitchMagnitude < 15 && rollMagnitude < 15 { return "approximately level" }
        if pitchMagnitude > 75 { return "approximately upright" }
        return "angled"
    }

    private func angleDifference(_ first: Double, _ second: Double) -> Double {
        var difference = (second - first).truncatingRemainder(dividingBy: 360.0)
        if difference > 180 { difference -= 360 }
        if difference < -180 { difference += 360 }
        return difference
    }

    private func processMeasurement(_ record: OrientationRecord) {
        switch measurement.stage {
        case .firstBottom:
            measurement.firstBottom = record
            measurement.stage = .secondBottom

        case .secondBottom:
            measurement.secondBottom = record

            guard let first = measurement.firstBottom else { return }
            let horizontalAngle = abs(angleDifference(first.headingDegrees, record.headingDegrees))
            let angleRadians = horizontalAngle * .pi / 180.0

            guard horizontalAngle > 0.1,
                  abs(tan(angleRadians)) > 0.0001 else {
                authorizationMessage = "The horizontal angle was too small to calculate distance."
                return
            }

            let originalDistance = measurement.baselineFeet / tan(angleRadians)
            measurement.distanceFeet = hypot(originalDistance, measurement.baselineFeet)
            measurement.stage = .thirdTop

        case .thirdTop:
            measurement.thirdTop = record

            guard let second = measurement.secondBottom,
                  let distance = measurement.distanceFeet else { return }

            let bottomAngle = second.pitchDegrees * .pi / 180.0
            let topAngle = record.pitchDegrees * .pi / 180.0
            measurement.heightFeet = distance * (tan(topAngle) - tan(bottomAngle))
            measurement.stage = .complete

        case .complete:
            break
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let record = pendingRecord else { return }

        DispatchQueue.main.async { [weak self] in
            self?.processMeasurement(record)
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }

            self.saveRecord(record)
        }
    }

    private func saveRecord(_ record: OrientationRecord) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(record)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try data.write(to: documents.appendingPathComponent("\(record.id.uuidString).json"), options: .atomic)
        } catch {
            print("Unable to save orientation record: \(error)")
        }
    }
}

