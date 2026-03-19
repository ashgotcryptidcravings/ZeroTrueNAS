import SwiftUI

struct ImageViewerView: View {
    let data: Data
    let filename: String

    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            // Image label
            HStack {
                Image(systemName: "photo.fill")
                    .foregroundColor(Theme.purple)
                Text(filename)
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(Formatters.fileSize(Int64(data.count)))
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.surfaceDark)
            )

            // Image display
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.purple.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    scale = 1.0
                                }
                            }
                    )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.warning)
                    Text("Cannot render image")
                        .font(Theme.monoFont(12))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surfaceDark)
                )
            }
        }
    }
}
