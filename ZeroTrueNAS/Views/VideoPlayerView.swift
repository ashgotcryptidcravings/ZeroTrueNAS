import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let fileURL: URL
    let filename: String

    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayerRepresentable(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        scheduleHideControls()
                    }
            } else {
                LoadingIndicator(label: "Preparing video...")
            }

            // Controls overlay
            if showControls {
                controlsOverlay
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            hideControlsTask?.cancel()
        }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(.black.opacity(0.5)))
                }

                Spacer()

                Text(filename)
                    .font(Theme.monoFont(12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Spacer for symmetry
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Center play/pause
            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: Theme.cyan.opacity(0.3), radius: 12)
            }

            Spacer()

            // Bottom scrubber
            VStack(spacing: 8) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.surfaceLight)
                            .frame(height: 4)

                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.cyan)
                            .frame(width: duration > 0 ? geo.size.width * (currentTime / duration) : 0, height: 4)
                            .shadow(color: Theme.cyan.opacity(0.5), radius: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                let seekTime = fraction * duration
                                player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                            }
                    )
                }
                .frame(height: 20)

                // Time labels
                HStack {
                    Text(formatTime(currentTime))
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.cyan)
                    Spacer()
                    Text(formatTime(duration))
                        .font(Theme.monoFont(11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    // MARK: - Helpers

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: fileURL)
        player = avPlayer

        // Observe time
        avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { time in
            currentTime = time.seconds
            if let dur = avPlayer.currentItem?.duration.seconds, dur.isFinite {
                duration = dur
            }
        }

        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
        }

        avPlayer.play()
        isPlaying = true
        scheduleHideControls()
    }

    private func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            if currentTime >= duration - 0.5 {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled && isPlaying {
                withAnimation(.easeOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - AVPlayer SwiftUI Wrapper

struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspect
        vc.view.backgroundColor = .black
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
