import CoreMotion

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    @Published var gravity: CMAcceleration = CMAcceleration()

    init() {
        startMotionUpdates()
    }

    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { (data, error) in
                guard let data = data, error == nil else { return }
                self.pitch = data.attitude.pitch
                self.roll = data.attitude.roll
                self.gravity = data.gravity
            }
        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
