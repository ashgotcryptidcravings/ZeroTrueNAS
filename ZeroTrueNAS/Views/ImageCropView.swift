import SwiftUI
import UIKit

struct ImageCropView: View {
    @EnvironmentObject var service: TrueNASService
    @Environment(\.dismiss) var dismiss

    let imageData: Data
    let filePath: String
    let filename: String

    @State private var cropRect: CGRect = .zero
    @State private var imageSize: CGSize = .zero
    @State private var displaySize: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var activeHandle: CropHandle?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveSuccess = false

    private let handleSize: CGFloat = 28
    private let minCropSize: CGFloat = 40

    private var uiImage: UIImage? { UIImage(data: imageData) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                cropToolbar

                GeometryReader { geo in
                    ZStack {
                        if let img = uiImage {
                            let fitted = fittedSize(img.size, in: geo.size)

                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: fitted.width, height: fitted.height)
                                .overlay(cropOverlay(imageFrame: fitted))
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                                .onAppear {
                                    imageSize = img.size
                                    displaySize = fitted
                                    // Start with crop covering 80% of image
                                    let inset = min(fitted.width, fitted.height) * 0.1
                                    cropRect = CGRect(
                                        x: inset, y: inset,
                                        width: fitted.width - inset * 2,
                                        height: fitted.height - inset * 2
                                    )
                                }
                        }
                    }
                }

                cropBottomBar
            }
        }
    }

    // MARK: - Toolbar

    private var cropToolbar: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(Theme.monoFont(14))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text("CROP")
                .font(Theme.headerFont(15))
                .tracking(2)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button {
                Task { await saveCropped() }
            } label: {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.cyan))
                        .scaleEffect(0.8)
                } else {
                    Text("Save")
                        .font(Theme.monoFont(14))
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.cyan)
                }
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Crop Overlay

    private func cropOverlay(imageFrame: CGSize) -> some View {
        ZStack {
            // Dimmed area outside crop
            CropDimmingShape(cropRect: cropRect, bounds: CGRect(origin: .zero, size: imageFrame))
                .fill(.black.opacity(0.55))

            // Crop border
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Rule-of-thirds grid
            Path { path in
                let x = cropRect.origin.x
                let y = cropRect.origin.y
                let w = cropRect.width
                let h = cropRect.height
                // Vertical lines
                path.move(to: CGPoint(x: x + w / 3, y: y))
                path.addLine(to: CGPoint(x: x + w / 3, y: y + h))
                path.move(to: CGPoint(x: x + 2 * w / 3, y: y))
                path.addLine(to: CGPoint(x: x + 2 * w / 3, y: y + h))
                // Horizontal lines
                path.move(to: CGPoint(x: x, y: y + h / 3))
                path.addLine(to: CGPoint(x: x + w, y: y + h / 3))
                path.move(to: CGPoint(x: x, y: y + 2 * h / 3))
                path.addLine(to: CGPoint(x: x + w, y: y + 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)

            // Corner handles
            ForEach(CropHandle.allCases, id: \.self) { handle in
                cornerHandle(handle)
            }
        }
        .contentShape(Rectangle())
        .gesture(cropDragGesture(imageFrame: imageFrame))
    }

    private func cornerHandle(_ handle: CropHandle) -> some View {
        let pos = handlePosition(handle)
        return Rectangle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .opacity(0.01) // Invisible hit area
            .overlay(
                handleLines(handle)
            )
            .position(pos)
    }

    private func handleLines(_ handle: CropHandle) -> some View {
        let lineLen: CGFloat = 16
        let lineW: CGFloat = 3

        return ZStack {
            // Horizontal arm
            Rectangle()
                .fill(Color.white)
                .frame(
                    width: lineLen,
                    height: lineW
                )
                .offset(
                    x: handle.isLeft ? lineLen / 2 - handleSize / 2 : handleSize / 2 - lineLen / 2,
                    y: handle.isTop ? -handleSize / 2 + lineW / 2 : handleSize / 2 - lineW / 2
                )

            // Vertical arm
            Rectangle()
                .fill(Color.white)
                .frame(
                    width: lineW,
                    height: lineLen
                )
                .offset(
                    x: handle.isLeft ? -handleSize / 2 + lineW / 2 : handleSize / 2 - lineW / 2,
                    y: handle.isTop ? lineLen / 2 - handleSize / 2 : handleSize / 2 - lineLen / 2
                )
        }
    }

    private func handlePosition(_ handle: CropHandle) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight: return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft: return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    // MARK: - Drag Gesture

    private func cropDragGesture(imageFrame: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let loc = value.location
                if dragStart == nil {
                    dragStart = value.startLocation
                    activeHandle = hitTestHandle(at: value.startLocation)
                }

                let bounds = CGRect(origin: .zero, size: imageFrame)

                if let handle = activeHandle {
                    resizeCrop(handle: handle, location: loc, bounds: bounds)
                } else {
                    // Move entire crop rect
                    let delta = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                    var newRect = cropRect
                    newRect.origin.x = max(0, min(bounds.width - cropRect.width, cropRect.origin.x + delta.width - (dragStart.map { value.startLocation.x - $0.x } ?? 0)))
                    // Simpler: just move based on translation from start
                    let startRect = cropRect
                    newRect.origin.x = startRect.origin.x + value.translation.width
                    newRect.origin.y = startRect.origin.y + value.translation.height
                    // Clamp
                    newRect.origin.x = max(0, min(bounds.width - newRect.width, newRect.origin.x))
                    newRect.origin.y = max(0, min(bounds.height - newRect.height, newRect.origin.y))
                    cropRect = newRect
                }
            }
            .onEnded { _ in
                dragStart = nil
                activeHandle = nil
            }
    }

    private func hitTestHandle(at point: CGPoint) -> CropHandle? {
        let threshold: CGFloat = handleSize * 1.5
        for handle in CropHandle.allCases {
            let pos = handlePosition(handle)
            if abs(point.x - pos.x) < threshold && abs(point.y - pos.y) < threshold {
                return handle
            }
        }
        return nil
    }

    private func resizeCrop(handle: CropHandle, location: CGPoint, bounds: CGRect) {
        var rect = cropRect
        let loc = CGPoint(
            x: max(0, min(bounds.width, location.x)),
            y: max(0, min(bounds.height, location.y))
        )

        switch handle {
        case .topLeft:
            let maxX = rect.maxX - minCropSize
            let maxY = rect.maxY - minCropSize
            rect.origin.x = min(loc.x, maxX)
            rect.origin.y = min(loc.y, maxY)
            rect.size.width = cropRect.maxX - rect.origin.x
            rect.size.height = cropRect.maxY - rect.origin.y
        case .topRight:
            let minX = rect.minX + minCropSize
            let maxY = rect.maxY - minCropSize
            rect.size.width = max(minCropSize, loc.x - rect.origin.x)
            rect.origin.y = min(loc.y, maxY)
            rect.size.height = cropRect.maxY - rect.origin.y
            _ = minX // suppress unused warning
        case .bottomLeft:
            let maxX = rect.maxX - minCropSize
            let minY = rect.minY + minCropSize
            rect.origin.x = min(loc.x, maxX)
            rect.size.width = cropRect.maxX - rect.origin.x
            rect.size.height = max(minCropSize, loc.y - rect.origin.y)
            _ = minY
        case .bottomRight:
            rect.size.width = max(minCropSize, loc.x - rect.origin.x)
            rect.size.height = max(minCropSize, loc.y - rect.origin.y)
        }

        cropRect = rect
    }

    // MARK: - Bottom Bar

    private var cropBottomBar: some View {
        VStack(spacing: 8) {
            if let error = saveError {
                Text(error)
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.error)
            }

            if showSaveSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Cropped image saved")
                }
                .font(Theme.monoFont(11))
                .foregroundColor(Theme.success)
                .transition(.opacity)
            }

            if displaySize.width > 0 {
                let scaleX = imageSize.width / displaySize.width
                let scaleY = imageSize.height / displaySize.height
                let cropW = Int(cropRect.width * scaleX)
                let cropH = Int(cropRect.height * scaleY)
                Text("\(cropW) x \(cropH) px")
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textSecondary)
            }

            Button {
                // Reset crop to full image
                let inset = min(displaySize.width, displaySize.height) * 0.1
                withAnimation(.easeOut(duration: 0.2)) {
                    cropRect = CGRect(
                        x: inset, y: inset,
                        width: displaySize.width - inset * 2,
                        height: displaySize.height - inset * 2
                    )
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("RESET")
                }
                .font(Theme.monoFont(11))
                .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Helpers

    private func fittedSize(_ original: CGSize, in container: CGSize) -> CGSize {
        let scale = min(container.width / original.width, container.height / original.height)
        return CGSize(width: original.width * scale, height: original.height * scale)
    }

    private func saveCropped() async {
        guard let source = uiImage, displaySize.width > 0 else { return }
        isSaving = true
        saveError = nil

        // Convert display-space crop to image-space crop
        let scaleX = imageSize.width / displaySize.width
        let scaleY = imageSize.height / displaySize.height
        let imageCrop = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = source.cgImage?.cropping(to: imageCrop) else {
            saveError = "Failed to crop image"
            isSaving = false
            return
        }

        let cropped = UIImage(cgImage: cgImage, scale: source.scale, orientation: source.imageOrientation)

        // Encode based on file extension
        let ext = (filename as NSString).pathExtension.lowercased()
        let data: Data?
        if ext == "png" {
            data = cropped.pngData()
        } else {
            data = cropped.jpegData(compressionQuality: 0.92)
        }

        guard let imageData = data else {
            saveError = "Failed to encode image"
            isSaving = false
            return
        }

        do {
            try await service.uploadFile(path: filePath, data: imageData)
            withAnimation { showSaveSuccess = true }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Supporting Types

enum CropHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
    var isTop: Bool { self == .topLeft || self == .topRight }
}

struct CropDimmingShape: Shape {
    let cropRect: CGRect
    let bounds: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(bounds)
        path.addRect(cropRect)
        return path
    }

    var animatableData: AnimatablePair<CGRect.AnimatableData, CGRect.AnimatableData> {
        get { AnimatablePair(cropRect.animatableData, bounds.animatableData) }
        set {
            // Not animated
        }
    }
}

extension CropDimmingShape {
    // Use even-odd fill rule for the cutout effect
    func fill<S: ShapeStyle>(_ content: S) -> some View {
        self._fill(content)
    }

    private func _fill<S: ShapeStyle>(_ content: S) -> some View {
        Path { path in
            path.addRect(bounds)
            path.addRect(cropRect)
        }
        .fill(content, style: FillStyle(eoFill: true))
    }
}
