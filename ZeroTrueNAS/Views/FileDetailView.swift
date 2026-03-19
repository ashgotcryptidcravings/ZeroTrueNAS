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
    @State private var showImageViewer = false
    @State private var showTextViewer = false
    @State private var textContent: String?

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
                    ImageViewerView(data: data, filename: file.name)
                        .frame(maxHeight: 300)
                        .padding(.horizontal)
                } else if file.isText, let text = textContent {
                    TextViewerView(text: text, filename: file.name)
                        .frame(maxHeight: 400)
                        .padding(.horizontal)
                } else if isDownloading {
                    Spacer()
                    LoadingIndicator(label: "Downloading...")
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
        .task {
            if file.isImage || file.isText {
                await previewFile()
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
            // Download & Save
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

                // View inline (if applicable)
                if file.isImage || file.isText {
                    Button {
                        Task { await previewFile() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                            Text("PREVIEW")
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

    private func previewFile() async {
        isDownloading = true
        errorMessage = nil

        do {
            let (data, _) = try await service.downloadFile(path: file.path)
            downloadedData = data

            if file.isText {
                textContent = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    private func downloadAndSave() async {
        isDownloading = true
        errorMessage = nil

        do {
            let (data, filename) = try await service.downloadFile(path: file.path)
            downloadedData = data

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            tempFileURL = fileURL
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    private func shareFile() async {
        if let url = tempFileURL {
            showShareSheet = true
            return
        }

        await downloadAndSave()
    }

    private var iconColor: Color {
        if file.isImage { return Theme.purple }
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
