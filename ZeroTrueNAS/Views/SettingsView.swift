import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var service: TrueNASService

    @State private var serverAddress = ServerConfig.savedAddress
    @State private var showClearConfirm = false
    @State private var showLogoutConfirm = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var savedBanner = false

    enum ConnectionStatus {
        case unknown, checking, connected, disconnected
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    header

                    VStack(spacing: 24) {
                        // Connection section
                        connectionSection

                        // Server section
                        serverSection

                        // Credentials section
                        credentialsSection

                        // About section
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Text("SETTINGS")
                .font(Theme.headerFont(17))
                .tracking(3)
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(Theme.cyan.opacity(0.03)))
    }

    // MARK: - Connection

    private var connectionSection: some View {
        SettingsCard {
            VStack(spacing: 12) {
                HStack {
                    Label("CONNECTION", systemImage: "network")
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }

                HStack(spacing: 12) {
                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .glow(color: statusColor, radius: 4)

                    Text(statusText)
                        .font(Theme.monoFont(13))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Button("Test") {
                        Task { await testConnection() }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(connectionStatus == .checking)
                }
            }
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        SettingsCard {
            VStack(spacing: 12) {
                HStack {
                    Label("SERVER ADDRESS", systemImage: "server.rack")
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }

                TextField("192.168.0.107", text: $serverAddress)
                    .textFieldStyle(ThemedTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                HStack {
                    Button("Save") {
                        ServerConfig.savedAddress = serverAddress
                        withAnimation { savedBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedBanner = false }
                        }
                    }
                    .buttonStyle(CyanButtonStyle(isCompact: true))

                    Button("Reset") {
                        serverAddress = ServerConfig.defaultAddress
                        ServerConfig.savedAddress = ServerConfig.defaultAddress
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                if savedBanner {
                    StatusBanner(message: "Server address saved", type: .success)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Credentials

    private var credentialsSection: some View {
        SettingsCard {
            VStack(spacing: 12) {
                HStack {
                    Label("CREDENTIALS", systemImage: "key.fill")
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(KeychainHelper.hasAPIKey ? Theme.success : Theme.textMuted)
                            .frame(width: 8, height: 8)
                        Text(KeychainHelper.hasAPIKey ? "API key stored in Keychain" : "No API key saved")
                            .font(Theme.monoFont(12))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Clear Key") {
                        showClearConfirm = true
                    }
                    .buttonStyle(DestructiveButtonStyle())
                    .confirmationDialog("Clear saved API key?", isPresented: $showClearConfirm) {
                        Button("Clear API Key", role: .destructive) {
                            _ = KeychainHelper.deleteAPIKey()
                        }
                    }

                    Button("Logout") {
                        showLogoutConfirm = true
                    }
                    .buttonStyle(DestructiveButtonStyle())
                    .confirmationDialog("Logout and return to login?", isPresented: $showLogoutConfirm) {
                        Button("Logout", role: .destructive) {
                            service.logout()
                        }
                    }
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsCard {
            VStack(spacing: 8) {
                HStack {
                    Label("ABOUT", systemImage: "info.circle")
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }

                VStack(spacing: 5) {
                    aboutRow("App", "ZeroTrueNAS v4.0")
                    aboutRow("Update Info", "Fixed file Editing and Audio Viewing.")
                    aboutRow("Target", "TrueNAS Goldeye")
                    aboutRow("API", "REST v2.0")
                    aboutRow("Server", ServerConfig.savedAddress)
                }

                Divider()
                    .background(Theme.surfaceLight)
                    .padding(.vertical, 8)

                Button {
                    if let url = URL(string: "https://github.com/ashgotcryptidcravings/ZeroTrueNAS") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14))
                        Text("VIEW ON GITHUB")
                            .font(Theme.monoFont(12))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Theme.cyan)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Text(value)
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func testConnection() async {
        connectionStatus = .checking
        let result = await service.testConnection()
        connectionStatus = result ? .connected : .disconnected
    }

    private var statusColor: Color {
        switch connectionStatus {
        case .unknown: return Theme.textMuted
        case .checking: return Theme.warning
        case .connected: return Theme.success
        case .disconnected: return Theme.error
        }
    }

    private var statusText: String {
        switch connectionStatus {
        case .unknown: return "Not tested"
        case .checking: return "Testing..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .glassEffect(.regular.tint(Theme.cyan.opacity(0.03)), in: .rect(cornerRadius: 16))
    }
}
