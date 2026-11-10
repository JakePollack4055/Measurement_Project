import SwiftUI

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @StateObject private var camera: CameraViewModel

    init() {
        let motion = MotionManager()
        _motionManager = StateObject(wrappedValue: motion)
        _camera = StateObject(wrappedValue: CameraViewModel(motionManager: motion))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button {
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
}

