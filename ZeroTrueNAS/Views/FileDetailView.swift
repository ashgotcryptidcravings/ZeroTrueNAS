import SwiftUI

struct FileDetailView: View {
    @EnvironmentObject var service: TrueNASService
    @Environment(\.dismiss) var dismiss

    let file: FileItem

    @State private var isDownloading = false
    @State private var downloadedData: Data?
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var tempFileURL: URL?
    @State private var textContent: String?
    @State private var showFullScreenImage = false
    @State private var showVideoPlayer = false
    @State private var downloadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GridOverlay(lineSpacing: 48, lineOpacity: 0.02)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Theme.surfaceLight)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // File info header
                fileInfoHeader

                Divider()
                    .background(Theme.cyan.opacity(0.15))
                    .padding(.vertical, 16)

                // Preview area
                if file.isImage, let data = downloadedData {
                    imagePreview(data: data)
                } else if file.isText, let text = textContent {
                    TextViewerView(text: text, filename: file.name)
                        .frame(maxHeight: 400)
                        .padding(.horizontal)
                } else if isDownloading {
                    Spacer()
                    LoadingIndicator(label: file.isVideo ? "Preparing video..." : "Downloading...")
                    Spacer()
                }

                Spacer()

                // Action buttons
                actionButtons

                if let error = errorMessage {
                    StatusBanner(message: error, type: .error)
                        .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = tempFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let data = downloadedData {
                FullScreenImageViewer(data: data, filename: file.name, fileSize: file.size)
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let url = tempFileURL {
                VideoPlayerView(fileURL: url, filename: file.name)
            }
        }
        .task {
            await autoPreview()
        }
        .onDisappear {
            downloadTask?.cancel()
        }
    }

    // MARK: - Image Preview (tappable to full-screen)

    private func imagePreview(data: Data) -> some View {
        Group {
            if let uiImage = UIImage(data: data) {
                Button {
                    showFullScreenImage = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.purple.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Circle().fill(.black.opacity(0.5)))
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                ImageViewerView(data: data, filename: file.name)
                    .frame(maxHeight: 300)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - File Info Header

    private var fileInfoHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: file.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
            }
            .glow(color: iconColor, radius: 8)

            Text(file.name)
                .font(Theme.monoFont(16))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 20) {
                DetailChip(label: "SIZE", value: Formatters.fileSize(file.size))
                DetailChip(label: "MODIFIED", value: Formatters.relativeDate(file.modified))
                DetailChip(label: "TYPE", value: file.fileExtension.uppercased().isEmpty ? "FILE" : file.fileExtension.uppercased())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary action depends on file type
            if file.isImage || file.isVideo {
                Button {
                    Task { await openMedia() }
                } label: {
                    HStack(spacing: 8) {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: file.isVideo ? "play.circle.fill" : "arrow.up.left.and.arrow.down.right")
                        }
                        Text(file.isVideo ? "PLAY" : "VIEW FULL SCREEN")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CyanButtonStyle())
                .disabled(isDownloading)
            } else {
                // Download
                Button {
                    Task { await downloadAndSave() }
                } label: {
                    HStack(spacing: 8) {
                        if isDownloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.background))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isDownloading ? "DOWNLOADING..." : "DOWNLOAD")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CyanButtonStyle())
                .disabled(isDownloading)
            }

            HStack(spacing: 12) {
                // Share
                Button {
                    Task { await shareFile() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("SHARE")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())

                // Download (for media that has View as primary)
                if file.isImage || file.isVideo {
                    Button {
                        Task { await downloadAndSave() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                            Text("SAVE")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - File Operations

    private func autoPreview() async {
        if file.isImage || file.isText {
            await fetchFileData()
        }
    }

    private func fetchFileData() async {
        isDownloading = true
        errorMessage = nil

        let task = Task {
            do {
                let (data, _) = try await service.downloadFile(path: file.path)
                if !Task.isCancelled {
                    downloadedData = data
                    if file.isText {
                        textContent = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            if !Task.isCancelled {
                isDownloading = false
            }
        }
        downloadTask = task
        await task.value
    }

    private func openMedia() async {
        if file.isImage {
            if downloadedData == nil {
                await fetchFileData()
            }
            if downloadedData != nil {
                showFullScreenImage = true
            }
        } else if file.isVideo {
            if tempFileURL == nil {
                await downloadToTemp()
            }
            if tempFileURL != nil {
                showVideoPlayer = true
            }
        }
    }

    private func downloadToTemp() async {
        isDownloading = true
        errorMessage = nil

        do {
            let (data, filename) = try await service.downloadFile(path: file.path)
            downloadedData = data
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            tempFileURL = fileURL
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    private func downloadAndSave() async {
        if tempFileURL == nil {
            await downloadToTemp()
        }
        if tempFileURL != nil {
            showShareSheet = true
        }
    }

    private func shareFile() async {
        if tempFileURL != nil {
            showShareSheet = true
            return
        }
        await downloadAndSave()
    }

    private var iconColor: Color {
        if file.isImage { return Theme.purple }
        if file.isVideo { return Theme.purple }
        if file.isText { return Theme.success }
        return Theme.cyan
    }
}

// MARK: - Detail Chip

struct DetailChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Theme.monoFont(9))
                .foregroundColor(Theme.textMuted)
            Text(value)
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
