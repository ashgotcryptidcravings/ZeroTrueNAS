import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    FileBrowserView()
                case 1:
                    SettingsView()
                default:
                    FileBrowserView()
                }
            }

            // Custom tab bar
            customTabBar
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "externaldrive.fill", label: "FILES", index: 0)
            tabButton(icon: "gearshape.fill", label: "SETTINGS", index: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            ZStack {
                Theme.surfaceDark
                    .shadow(color: .black.opacity(0.5), radius: 20, y: -8)

                // Top border glow
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.cyan.opacity(0.2), Theme.purple.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        )
    }

    private func tabButton(icon: String, label: String, index: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedTab == index ? Theme.cyan : Theme.textMuted)
                    .shadow(
                        color: selectedTab == index ? Theme.cyan.opacity(0.5) : .clear,
                        radius: 6
                    )

                Text(label)
                    .font(Theme.monoFont(9))
                    .tracking(1.5)
                    .foregroundColor(selectedTab == index ? Theme.cyan : Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
