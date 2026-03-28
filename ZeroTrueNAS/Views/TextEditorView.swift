import SwiftUI

struct TextEditorView: View {
    @EnvironmentObject var service: TrueNASService
    @Environment(\.dismiss) var dismiss

    let filePath: String
    let filename: String
    let originalText: String

    @State private var text: String
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showSaveSuccess = false
    @State private var showDiscardConfirm = false

    init(filePath: String, filename: String, text: String) {
        self.filePath = filePath
        self.filename = filename
        self.originalText = text
        self._text = State(initialValue: text)
    }

    private var hasChanges: Bool {
        text != originalText
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()
                    .background(Theme.cyan.opacity(0.15))

                // Editor
                editor

                // Bottom bar
                bottomBar
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button {
                if hasChanges {
                    showDiscardConfirm = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(filename)
                    .font(Theme.monoFont(13))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                if hasChanges {
                    Text("MODIFIED")
                        .font(Theme.monoFont(9))
                        .foregroundColor(Theme.warning)
                        .tracking(1)
                }
            }

            Spacer()

            Button {
                Task { await saveFile() }
            } label: {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.cyan))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text("SAVE")
                        .font(Theme.monoFont(12))
                }
                .foregroundColor(hasChanges ? Theme.cyan : Theme.textMuted)
            }
            .disabled(!hasChanges || isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surfaceDark.opacity(0.9))
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: $text)
            .font(Theme.monoFont(13))
            .foregroundColor(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .tint(Theme.cyan)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.cyan.opacity(0.15))

            HStack {
                let lines = text.components(separatedBy: .newlines).count
                let chars = text.count
                Text("\(lines) lines  \(chars) chars")
                    .font(Theme.monoFont(10))
                    .foregroundColor(Theme.textMuted)

                Spacer()

                if showSaveSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Saved")
                            .font(Theme.monoFont(10))
                    }
                    .foregroundColor(Theme.success)
                    .transition(.opacity)
                }

                if let error = saveError {
                    Text(error)
                        .font(Theme.monoFont(10))
                        .foregroundColor(Theme.error)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.surfaceDark)
        }
    }

    // MARK: - Save

    private func saveFile() async {
        isSaving = true
        saveError = nil
        showSaveSuccess = false

        do {
            guard let data = text.data(using: .utf8) else {
                saveError = "Failed to encode text"
                isSaving = false
                return
            }
            try await service.uploadFile(path: filePath, data: data)
            withAnimation { showSaveSuccess = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showSaveSuccess = false }
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}
