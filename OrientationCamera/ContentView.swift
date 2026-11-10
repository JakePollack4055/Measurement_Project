import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var camera: CameraViewModel
    @State private var baselineText = "1.0"

    init() {
        let motion = MotionManager()
        _motionManager = StateObject(wrappedValue: motion)
        _camera = StateObject(wrappedValue: CameraViewModel(motionManager: motion))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            CrosshairView()
                .stroke(.white, lineWidth: 2)
                .frame(width: 56, height: 56)

            VStack(spacing: 12) {
                Text(instruction)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                if camera.measurement.stage == .firstBottom {
                    HStack {
                        Text("Move distance (ft)")
                        TextField("1.0", text: $baselineText)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
                Button {
                    if let baseline = Double(baselineText) {
                        camera.setBaselineFeet(baseline)
                    }
                    camera.capturePhoto()
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 2))
                }
                .padding(.bottom, 32)
            }
        }
        .overlay(alignment: .top) {
            if let record = camera.lastRecord {
                Text("\(Int(record.headingDegrees))°  •  \(record.classification)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 20)
            }
        }
        .alert("Camera unavailable", isPresented: .constant(camera.authorizationMessage != nil)) {
            Button("OK") { camera.authorizationMessage = nil }
        } message: {
            Text(camera.authorizationMessage ?? "")
        }
        .onAppear {
            camera.configure()
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var instruction: String {
        switch camera.measurement.stage {
        case .firstBottom:
            return "Center the bottom of the object"
        case .secondBottom:
            return "Move horizontally, then center the bottom again"
        case .thirdTop:
            return "Stay in place and tilt up to the top"
        case .complete:
            let distance = camera.measurement.distanceFeet.map { String(format: "%.2f ft", $0) } ?? "—"
            let height = camera.measurement.heightFeet.map { String(format: "%.2f ft", $0) } ?? "—"
            return "Distance: \(distance)  Height: \(height)"
        }
    }
}

struct CrosshairView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x - 24, y: center.y))
        path.addLine(to: CGPoint(x: center.x + 24, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - 24))
        path.addLine(to: CGPoint(x: center.x, y: center.y + 24))
        return path
    }
}

