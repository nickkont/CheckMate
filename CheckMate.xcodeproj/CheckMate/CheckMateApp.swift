import SwiftUI
import GoogleMobileAds

@main
struct CheckMateApp: App {
    @State private var navigationPath = NavigationPath()
    @State private var showLaunchScreen = true // New state for controlling launch screen
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    init() {
        MobileAds.shared.start(completionHandler: nil)
        }
    var body: some Scene {
        WindowGroup {
            if showLaunchScreen {
                LaunchScreenView(showLaunchScreen: $showLaunchScreen)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showLaunchScreen = false
                            }
                        }
                    }
            } else {
                NavigationStack(path: $navigationPath) {
                    CameraView(navigationPath: $navigationPath)
                }
            }
        }
    }
}
