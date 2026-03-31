import SwiftUI

struct SkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surfaceLight.opacity(0.5))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                // Name placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceLight.opacity(0.5))
                    .frame(width: CGFloat.random(in: 100...200), height: 12)

                // Meta placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surfaceLight.opacity(0.3))
                    .frame(width: CGFloat.random(in: 60...120), height: 10)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(shimmer ? 0.4 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct SkeletonList: View {
    let count: Int

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    SkeletonRow()

                    if i < count - 1 {
                        Divider()
                            .background(Theme.surfaceLight.opacity(0.3))
                            .padding(.leading, 70)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
