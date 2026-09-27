//
//  AudioManager.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import AVFoundation

class AudioManager: ObservableObject {
    private static let amplitude: Float = 0.5
    /// 出力デバイスが無くサンプルレートが取れない環境向けのフォールバック
    private static let fallbackSampleRate: Double = 44100

    let audioEngine: AVAudioEngine
    private let sourceNode: AVAudioSourceNode
    /// Play / Stop ボタンの活性制御に使うため、UI から購読できるようにする
    @Published private(set) var isPlaying: Bool = false
    var currentFrequency: Double = 20.0

    // レンダーブロックはリアルタイムスレッドで動き、ロックやメモリ確保ができない。
    // そのため状態は init で確保したポインタに置き、メインスレッドは値の書き込みだけを行う
    private let generator: UnsafeMutablePointer<ToneGenerator>
    private let targetFrequency: UnsafeMutablePointer<Double>
    private let isRendering: UnsafeMutablePointer<Bool>

    init() {
        // セッションを有効にしてから出力フォーマットを読まないと、iOS でサンプルレートが確定しない
        Self.configureAudioSession()
        audioEngine = AVAudioEngine()

        // サンプルレートは 44.1kHz 固定ではなく実際の出力に合わせる。
        // iOS は 48kHz が既定のため、固定値のままだと出力される周波数が指定値からずれる
        let outputSampleRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outputSampleRate > 0 ? outputSampleRate : Self.fallbackSampleRate

        generator = .allocate(capacity: 1)
        generator.initialize(to: ToneGenerator(sampleRate: sampleRate, frequency: currentFrequency))
        targetFrequency = .allocate(capacity: 1)
        targetFrequency.initialize(to: currentFrequency)
        isRendering = .allocate(capacity: 1)
        isRendering.initialize(to: false)

        let generator = generator
        let targetFrequency = targetFrequency
        let isRendering = isRendering
        let amplitude = Self.amplitude
        sourceNode = AVAudioSourceNode { isSilence, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard isRendering.pointee else {
                for buffer in buffers {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                isSilence.pointee = true
                return noErr
            }
            generator.pointee.frequency = targetFrequency.pointee
            for frame in 0..<Int(frameCount) {
                let sample = generator.pointee.nextSample() * amplitude
                // 出力チャンネル数はデバイスによって変わるため、決め打ちにせず実際の数だけ書き込む
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
        } catch {
            print("AVAudioEngine の開始に失敗しました: \(error)")
        }
    }

    deinit {
        // レンダーブロックがポインタを参照しなくなってから解放する
        audioEngine.stop()
        generator.deallocate()
        targetFrequency.deallocate()
        isRendering.deallocate()
    }

    /// iOS はオーディオセッションのカテゴリを指定しないと、既定の .soloAmbient になり
    /// サイレントスイッチや画面ロックで音が止まってしまうため .playback を明示する。
    /// macOS には AVAudioSession が無いので何もしない。
    private static func configureAudioSession() {
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

    func playTone(frequency: Double) {
        updateFrequency(frequency)
        isRendering.pointee = true
        isPlaying = true
    }

    /// 再生中でも停止中でも呼んでよい。再生中は次のレンダー周期から位相を保ったまま新しい周波数になる
    func updateFrequency(_ frequency: Double) {
        currentFrequency = frequency
        targetFrequency.pointee = frequency
    }

    func stopTone() {
        isRendering.pointee = false
        isPlaying = false
    }
}

/// 位相を保持したまま 1 サンプルずつサイン波を生成する。
/// `AVAudioEngine` に依存しないため単体でテストでき、レンダーブロックからも値型のまま使える。
struct ToneGenerator {
    let sampleRate: Double
    var frequency: Double
    /// 1 周期を 0..<1 に正規化した位相。周波数を変えてもここは引き継ぐので波形が不連続にならない
    private(set) var phase: Double = 0

    init(sampleRate: Double, frequency: Double) {
        self.sampleRate = sampleRate
        self.frequency = frequency
    }

    mutating func nextSample() -> Float {
        let sample = Float(sin(2.0 * Double.pi * phase))
        phase += frequency / sampleRate
        // 長時間再生しても精度が落ちないよう、整数部を捨てて 0..<1 に保つ
        phase -= floor(phase)
        return sample
    }
}
