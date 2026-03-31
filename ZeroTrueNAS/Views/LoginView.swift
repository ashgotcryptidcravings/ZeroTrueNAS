import SwiftUI

struct LoginView: View {
    @EnvironmentObject var service: TrueNASService

    @State private var apiKey = ""
    @State private var serverAddress = ServerConfig.savedAddress
    @State private var showKey = false
    @State private var isAttempting = false

    var body: some View {
        ZStack {
            // Background
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Logo / Title
                    headerSection

                    Spacer().frame(height: 48)

                    // Form
                    formSection

                    Spacer().frame(height: 32)

                    // Connect Button
                    connectButton

                    // Mock data fallback
                    mockDataButton

                    Spacer().frame(height: 16)

                    // Error display
                    if let error = service.connectionError {
                        StatusBanner(message: error, type: .error)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .animation(.easeOut(duration: 0.3), value: service.connectionError)
        .onAppear {
            if let saved = KeychainHelper.loadAPIKey() {
                apiKey = saved
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Geometric logo
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(45))
                    .glassEffect(.regular.tint(Theme.cyan.opacity(0.15)), in: .rect(cornerRadius: 16))

                Image(systemName: "externaldrive.connected.to.line.below.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Theme.cyan)
            }
            .frame(height: 100)

            Text("ZEROTRUENAS")
                .font(Theme.headerFont(28))
                .tracking(6)
                .foregroundColor(Theme.textPrimary)

            Text("PERSONAL FILE SYSTEM")
                .font(Theme.monoFont(11))
                .tracking(3)
                .foregroundColor(Theme.cyan.opacity(0.7))

            // Decorative line
            HStack(spacing: 8) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.cyan.opacity(0), Theme.cyan.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Circle()
                    .fill(Theme.cyan.opacity(0.6))
                    .frame(width: 4, height: 4)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.cyan.opacity(0.3), Theme.cyan.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private var formSection: some View {
        VStack(spacing: 20) {
            // Server address
            VStack(alignment: .leading, spacing: 6) {
                Label("SERVER", systemImage: "network")
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textSecondary)

                TextField("192.168.0.107", text: $serverAddress)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            // API Key
            VStack(alignment: .leading, spacing: 6) {
                Label("API KEY", systemImage: "key.fill")
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: 0) {
                    Group {
                        if showKey {
                            TextField("Enter API key", text: $apiKey)
                        } else {
                            SecureField("Enter API key", text: $apiKey)
                        }
                    }
                    .font(Theme.monoFont(15))
                    .foregroundColor(Theme.textPrimary)
                    .tint(Theme.cyan)

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.trailing, 4)
                }
                .padding(14)
                .glassEffect(.regular.tint(Theme.cyan.opacity(0.05)), in: .rect(cornerRadius: 12))
            }
        }
    }

    private var connectButton: some View {
        Button {
            Task {
                isAttempting = true
                _ = await service.authenticate(apiKey: apiKey, serverAddress: serverAddress)
                isAttempting = false
            }
        } label: {
            HStack(spacing: 8) {
                if service.isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "bolt.fill")
                }
                Text(service.isConnecting ? "CONNECTING..." : "CONNECT")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CyanButtonStyle())
        .disabled(apiKey.isEmpty || service.isConnecting)
        .opacity(apiKey.isEmpty ? 0.5 : 1)
        .padding(.bottom, 12)
    }

    private var mockDataButton: some View {
        Button {
            service.useMockData = true
            service.isAuthenticated = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.dashed")
                Text("USE MOCK DATA")
            }
        }
        .buttonStyle(GhostButtonStyle())
        .padding(.bottom, 16)
    }
}
