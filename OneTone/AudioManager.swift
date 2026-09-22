//
//  AudioManager.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import AVFoundation

class AudioManager: ObservableObject {
    var audioEngine: AVAudioEngine
    var audioPlayerNode: AVAudioPlayerNode
    var timer: Timer?
    var isPlaying: Bool = false
    var currentFrequency: Double = 20.0

    init() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(audioPlayerNode, to: mainMixer, format: nil)
        configureAudioSession()
        do {
            try audioEngine.start()
        } catch {
            print("AVAudioEngine の開始に失敗しました: \(error)")
        }
    }

    /// iOS はオーディオセッションのカテゴリを指定しないと、既定の .soloAmbient になり
    /// サイレントスイッチや画面ロックで音が止まってしまうため .playback を明示する。
    /// macOS には AVAudioSession が無いので何もしない。
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AVAudioSession の設定に失敗しました: \(error)")
        }
        #endif
    }

    func playTone(frequency: Double, duration: Double = 5.0) {
        let format = audioPlayerNode.outputFormat(forBus: 0)
        // サンプルレートは 44.1kHz 固定ではなく実際の出力に合わせる。
        // iOS は 48kHz が既定のため、固定値のままだと出力される周波数が指定値からずれる
        let sampleRate = format.sampleRate
        let amplitude: Float = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard sampleRate > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return }

        for i in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)) * amplitude
            // 出力チャンネル数はデバイスによって変わるため、2ch 決め打ちにせず実際の数だけ書き込む
            for channel in 0..<Int(format.channelCount) {
                channels[channel][i] = sample
            }
        }
        buffer.frameLength = frameCount
        isPlaying = true
        currentFrequency = frequency

        audioPlayerNode.stop()
        audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        audioPlayerNode.play()
    }

    func updateFrequency(_ frequency: Double) {
        self.currentFrequency = frequency
        if isPlaying {
            playTone(frequency: currentFrequency, duration: 5)
        }
    }

    func stopTone() {
        audioPlayerNode.stop()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
}
