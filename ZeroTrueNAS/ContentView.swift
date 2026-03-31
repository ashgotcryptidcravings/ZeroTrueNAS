import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: TrueNASService
    @State private var hasAttemptedAutoLogin = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !hasAttemptedAutoLogin {
                // Splash / loading
                splashView
            } else if service.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: service.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasAttemptedAutoLogin)
        .task {
            await service.tryAutoLogin()
            withAnimation {
                hasAttemptedAutoLogin = true
            }
        }
    }

    private var splashView: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(45))
                    .glassEffect(.regular.tint(Theme.cyan.opacity(0.1)), in: .rect(cornerRadius: 16))

                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Theme.cyan)
            }
            .pulseGlow()

            Text("ZEROTRUENAS")
                .font(Theme.headerFont(22))
                .tracking(6)
                .foregroundColor(Theme.textPrimary)

            LoadingIndicator(label: "Connecting...")
        }
    }
}
