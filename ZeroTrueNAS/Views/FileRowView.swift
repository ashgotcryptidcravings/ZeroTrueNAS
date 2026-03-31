import SwiftUI

struct FileRowView: View {
    let item: FileItem
    @EnvironmentObject var service: TrueNASService

    @State private var thumbnail: UIImage?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 14) {
            // File type icon or thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)

                if let thumb = thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: item.iconName)
                        .font(.system(size: 17))
                        .foregroundColor(iconColor)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.monoFont(14))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if !item.isDirectory {
                        Text(Formatters.fileSize(item.size))
                            .font(Theme.monoFont(11))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text(Formatters.relativeDate(item.modified))
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textMuted)
                }
            }

            Spacer()

            // Type badge for media files
            if item.isVideo {
                Text("VIDEO")
                    .font(Theme.monoFont(8))
                    .tracking(1)
                    .foregroundColor(Theme.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.purple.opacity(0.12))
                    )
            } else if item.isAudio {
                Text("AUDIO")
                    .font(Theme.monoFont(8))
                    .tracking(1)
                    .foregroundColor(Theme.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.warning.opacity(0.12))
                    )
            } else if item.isPDF {
                Text("PDF")
                    .font(Theme.monoFont(8))
                    .tracking(1)
                    .foregroundColor(Theme.error)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.error.opacity(0.12))
                    )
            } else if item.isUnknown {
                HStack(spacing: 3) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 7, weight: .bold))
                    Text(item.fileExtension.isEmpty ? "UNKNOWN" : ".\(item.fileExtension.uppercased())")
                        .font(Theme.monoFont(8))
                        .tracking(1)
                }
                .foregroundColor(Theme.unknown)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Theme.unknown.opacity(0.4), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.unknown.opacity(0.08))
                        )
                )
            }

            // Chevron for directories
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface.opacity(0.01))
        .contentShape(Rectangle())
        .task(id: item.id) {
            await loadThumbnail()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadThumbnail() async {
        guard item.isImage else { return }
        // Check cache synchronously via actor
        if let cached = await ThumbnailCache.shared.get(item.path) {
            thumbnail = cached
            return
        }
        // Fetch async
        let task = Task.detached { [path = item.path] () -> UIImage? in
            await service.fetchThumbnail(path: path)
        }
        loadTask = Task {
            if let img = await task.value {
                thumbnail = img
            }
        }
    }

    private var iconColor: Color {
        if item.isDirectory { return Theme.cyan }
        if item.isImage { return Theme.purple }
        if item.isVideo { return Theme.purple }
        if item.isAudio { return Theme.warning }
        if item.isPDF { return Theme.error }
        if item.isCode { return Theme.success }
        if item.isText { return Theme.success }
        if item.isArchive { return Theme.textSecondary }
        if item.isUnknown { return Theme.unknown }
        return Theme.textSecondary
    }

    private var iconBackground: Color {
        iconColor.opacity(0.08)
    }
}
