import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var service: TrueNASService

    @State private var currentPath = ServerConfig.defaultBasePath
    @State private var files: [FileItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigationStack: [String] = []
    @State private var selectedFile: FileItem?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GridOverlay(lineSpacing: 48, lineOpacity: 0.02)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Breadcrumb
                BreadcrumbView(path: currentPath) { path in
                    navigateTo(path)
                }

                Divider()
                    .background(Theme.cyan.opacity(0.15))

                // Content
                if isLoading {
                    SkeletonList(count: 8)
                } else if let error = errorMessage {
                    Spacer()
                    errorView(error)
                    Spacer()
                } else if files.isEmpty {
                    Spacer()
                    emptyView
                    Spacer()
                } else {
                    fileList
                }
            }
        }
        .sheet(item: $selectedFile) { file in
            FileDetailView(file: file)
                .environmentObject(service)
        }
        .task {
            await loadDirectory()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if !navigationStack.isEmpty {
                Button {
                    goBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(Theme.monoFont(13))
                    }
                    .foregroundColor(Theme.cyan)
                }
            }

            Spacer()

            Text("FILES")
                .font(Theme.headerFont(17))
                .tracking(3)
                .foregroundColor(Theme.textPrimary)

            Spacer()

            // Refresh button
            Button {
                Task { await loadDirectory() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.cyan)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surfaceDark.opacity(0.9))
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files) { file in
                    Button {
                        handleFileTap(file)
                    } label: {
                        FileRowView(item: file)
                            .environmentObject(service)
                    }
                    .buttonStyle(.plain)

                    if file.id != files.last?.id {
                        Divider()
                            .background(Theme.surfaceLight.opacity(0.5))
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await loadDirectory()
        }
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(Theme.textMuted)

            Text("Empty directory")
                .font(Theme.monoFont(14))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            StatusBanner(message: message, type: .error)

            Button("Retry") {
                Task { await loadDirectory() }
            }
            .buttonStyle(GhostButtonStyle())
        }
    }

    // MARK: - Navigation

    private func handleFileTap(_ file: FileItem) {
        if file.isDirectory {
            navigationStack.append(currentPath)
            currentPath = file.path
            Task { await loadDirectory() }
        } else {
            selectedFile = file
        }
    }

    private func navigateTo(_ path: String) {
        if path != currentPath {
            navigationStack.append(currentPath)
            currentPath = path
            Task { await loadDirectory() }
        }
    }

    private func goBack() {
        if let previous = navigationStack.popLast() {
            currentPath = previous
            Task { await loadDirectory() }
        }
    }

    private func loadDirectory() async {
        // Cancel any previous load
        loadTask?.cancel()

        isLoading = true
        errorMessage = nil

        let task = Task {
            do {
                let items = try await service.listDirectory(path: currentPath)
                if !Task.isCancelled {
                    files = items
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    if service.useMockData {
                        files = FileItem.mockFiles
                        errorMessage = nil
                    }
                }
            }
            if !Task.isCancelled {
                isLoading = false
            }
        }
        loadTask = task
        await task.value
    }
}
