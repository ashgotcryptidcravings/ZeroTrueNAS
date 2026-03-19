import SwiftUI

struct FileRowView: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 14) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)

                Image(systemName: item.iconName)
                    .font(.system(size: 17))
                    .foregroundColor(iconColor)
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
    }

    private var iconColor: Color {
        if item.isDirectory { return Theme.cyan }
        if item.isImage { return Theme.purple }
        if item.isText { return Theme.success }
        return Theme.textSecondary
    }

    private var iconBackground: Color {
        iconColor.opacity(0.1)
    }
}
