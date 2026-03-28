import SwiftUI

struct FullScreenImageViewer: View {
    let data: Data
    let filename: String
    let fileSize: Int64?

    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var showOverlay = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dragOffset.height)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation(.spring(response: 0.3)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale <= 1.0 {
                                    // Vertical drag to dismiss
                                    dragOffset = CGSize(width: 0, height: value.translation.height)
                                } else {
                                    // Pan when zoomed
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { value in
                                if scale <= 1.0 {
                                    if abs(dragOffset.height) > 120 {
                                        dismiss()
                                    } else {
                                        withAnimation(.spring(response: 0.3)) {
                                            dragOffset = .zero
                                        }
                                    }
                                } else {
                                    lastOffset = offset
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring(response: 0.3)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showOverlay.toggle()
                        }
                    }
            }

            // Overlay info
            if showOverlay {
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Bottom info bar
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundColor(Theme.purple)
                        Text(filename)
                            .font(Theme.monoFont(12))
                            .foregroundColor(.white)
                        Spacer()
                        Text(Formatters.fileSize(fileSize))
                            .font(Theme.monoFont(11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .environment(\.colorScheme, .dark)
                }
            }
        }
        .opacity(1.0 - min(abs(dragOffset.height) / 300.0, 0.5))
        .statusBarHidden(!showOverlay)
    }
}
