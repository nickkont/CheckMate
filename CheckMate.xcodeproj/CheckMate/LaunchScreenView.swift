import SwiftUI

struct LaunchScreenView: View {
    @Binding var showLaunchScreen: Bool
    @State private var opacity = 1.0 

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                Image("CheckLaunch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 400, height: 400)
            }
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
