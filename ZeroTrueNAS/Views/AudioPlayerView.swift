import SwiftUI
import AVFoundation
import MediaPlayer

struct AudioPlayerView: View {
    @Environment(\.dismiss) var dismiss

    let fileURL: URL
    let filename: String
    let fileSize: Int64?

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    @State private var loadError: String?
    @State private var volume: Float = 1.0
    @State private var showVolumeSlider = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close button
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .glassEffect(.regular, in: .circle)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Spacer()

                // Album art placeholder
                albumArt

                Spacer().frame(height: 32)

                // Track info
                trackInfo

                Spacer().frame(height: 32)

                // Scrubber
                scrubber

                Spacer().frame(height: 24)

                // Playback controls
                controls

                Spacer().frame(height: 20)

                // Volume
                volumeControl

                Spacer()

                if let error = loadError {
                    StatusBanner(message: error, type: .error)
                        .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            timer?.invalidate()
            player?.stop()
            clearNowPlaying()
        }
    }

    // MARK: - Album Art

    private var albumArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.clear)
                .frame(width: 200, height: 200)
                .glassEffect(.regular.tint(Theme.purple.opacity(0.15)), in: .rect(cornerRadius: 24))

            VStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Theme.purple)

                Text(fileExtension.uppercased())
                    .font(Theme.monoFont(13))
                    .tracking(2)
                    .foregroundColor(Theme.purple.opacity(0.7))
            }
        }
        .scaleEffect(isPlaying ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPlaying)
    }

    // MARK: - Track Info

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(filename)
                .font(Theme.monoFont(16))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(Formatters.fileSize(fileSize))
                .font(Theme.monoFont(12))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.surfaceLight)
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.cyan)
                        .frame(
                            width: duration > 0 ? geo.size.width * CGFloat(currentTime / duration) : 0,
                            height: 4
                        )
                        .shadow(color: Theme.cyan.opacity(0.5), radius: 4)

                    // Thumb
                    if duration > 0 {
                        Circle()
                            .fill(Theme.cyan)
                            .frame(width: 14, height: 14)
                            .shadow(color: Theme.cyan.opacity(0.4), radius: 6)
                            .offset(x: geo.size.width * CGFloat(currentTime / duration) - 7)
                    }
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            let seekTime = Double(fraction) * duration
                            player?.currentTime = seekTime
                            currentTime = seekTime
                        }
                )
            }
            .frame(height: 14)

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
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 40) {
            // Skip back 15s
            Button {
                skip(seconds: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.textSecondary)
            }

            // Play / Pause
            Button {
                togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.cyan)
                        .frame(width: 64, height: 64)
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.background)
                        .offset(x: isPlaying ? 0 : 2) // Visual centering for play icon
                }
            }

            // Skip forward 30s
            Button {
                skip(seconds: 30)
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 24))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - Volume

    private var volumeControl: some View {
        HStack(spacing: 12) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
                .onTapGesture {
                    volume = volume == 0 ? 1.0 : 0
                    player?.volume = volume
                }

            Slider(value: $volume, in: 0...1)
                .tint(Theme.cyan)
                .onChange(of: volume) { newValue in
                    player?.volume = newValue
                }

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    private func setupPlayer() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer.prepareToPlay()
            audioPlayer.volume = volume
            duration = audioPlayer.duration
            player = audioPlayer

            setupRemoteCommands()
            updateNowPlaying()

            // Start time update timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard let p = player else { return }
                currentTime = p.currentTime
                updateNowPlayingTime()
                if !p.isPlaying && isPlaying && currentTime >= duration - 0.1 {
                    isPlaying = false
                    currentTime = 0
                    p.currentTime = 0
                    updateNowPlaying()
                }
            }
        } catch {
            loadError = "Cannot play audio: \(error.localizedDescription)"
        }
    }

    private func togglePlayback() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            if currentTime >= duration - 0.1 {
                player.currentTime = 0
                currentTime = 0
            }
            player.play()
        }
        isPlaying.toggle()
        updateNowPlaying()
    }

    private func skip(seconds: Double) {
        guard let player = player else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTime = newTime
        updateNowPlayingTime()
    }

    // MARK: - Now Playing / Control Center

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            guard let p = player, !p.isPlaying else { return .commandFailed }
            p.play()
            isPlaying = true
            updateNowPlaying()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            guard let p = player, p.isPlaying else { return .commandFailed }
            p.pause()
            isPlaying = false
            updateNowPlaying()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            togglePlayback()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { event in
            guard let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skip(seconds: e.interval)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { event in
            guard let e = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skip(seconds: -e.interval)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            player?.currentTime = e.positionTime
            currentTime = e.positionTime
            updateNowPlayingTime()
            return .success
        }
    }

    private func updateNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = filename
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
