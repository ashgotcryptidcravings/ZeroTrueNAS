import SwiftUI

struct TextViewerView: View {
    let text: String
    let filename: String

    var body: some View {
        VStack(spacing: 8) {
            // File label
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(Theme.success)
                Text(filename)
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(text.count) chars")
                    .font(Theme.monoFont(11))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.surfaceDark)
            )

            // Text content
            ScrollView {
                HStack {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                            Text("\(index + 1)")
                                .font(Theme.monoFont(11))
                                .foregroundColor(Theme.textMuted)
                                .frame(height: 18)
                        }
                    }
                    .padding(.trailing, 8)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Theme.cyan.opacity(0.1))
                            .frame(width: 1)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(Theme.monoFont(11))
                                .foregroundColor(Theme.textPrimary)
                                .frame(height: 18, alignment: .leading)
                        }
                    }

                    Spacer()
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surfaceDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.success.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    private var lines: [String] {
        let allLines = text.components(separatedBy: .newlines)
        // Cap at 500 lines for performance
        return Array(allLines.prefix(500))
    }
}
