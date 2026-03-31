import SwiftUI

struct StatusBanner: View {
    let message: String
    let type: BannerType

    enum BannerType {
        case error, success, info

        var color: Color {
            switch self {
            case .error: return Theme.error
            case .success: return Theme.success
            case .info: return Theme.cyan
            }
        }

        var icon: String {
            switch self {
            case .error: return "xmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundColor(type.color)

            Text(message)
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(type.color.opacity(0.1)), in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }
}

struct LoadingIndicator: View {
    var label: String = "Loading..."
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceLight, lineWidth: 2)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Theme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }

            Text(label)
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
