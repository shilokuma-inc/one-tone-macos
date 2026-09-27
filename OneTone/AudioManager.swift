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

/// 目標値へ指数的に近づける 1 次のスムーザー。
/// 値が急に切り替わると波形に段差ができてクリックノイズになるため、サンプルごとに少しずつ寄せる。
struct ParameterSmoother {
    private(set) var current: Double
    var target: Double
    /// 1 サンプルで残り差分のどれだけを詰めるか。`timeConstant` 秒で差分の約 63% が埋まる
    private let coefficient: Double

    init(value: Double, sampleRate: Double, timeConstant: Double) {
        current = value
        target = value
        coefficient = 1 - exp(-1 / (timeConstant * sampleRate))
    }

    mutating func next() -> Double {
        current += (target - current) * coefficient
        return current
    }

    /// 補間を飛ばして目標値に揃える
    mutating func snap(to value: Double) {
        current = value
        target = value
    }
}

/// 周波数の補間と再生開始・停止時のフェードを含めて、出力サンプルを 1 つずつ作る。
/// レンダーブロックから呼ぶため、メモリ確保をしない値型にしている。
struct ToneSynthesizer {
    /// 周波数とフェードの振幅を目標値へ寄せる時定数。数 ms で追従し、段差によるクリックノイズを出さない
    static let smoothingTime: Double = 0.005
    /// フェードアウト後、この振幅を下回ったら無音とみなす（約 -80dB）
    static let silenceThreshold: Double = 0.0001

    private(set) var generator: ToneGenerator
    private var frequency: ParameterSmoother
    private var gain: ParameterSmoother

    init(sampleRate: Double, frequency: Double) {
        generator = ToneGenerator(sampleRate: sampleRate, frequency: frequency)
        self.frequency = ParameterSmoother(value: frequency, sampleRate: sampleRate, timeConstant: Self.smoothingTime)
        gain = ParameterSmoother(value: 0, sampleRate: sampleRate, timeConstant: Self.smoothingTime)
    }

    /// フェードアウトが終わり、出力が無音になっているか
    var isSilent: Bool {
        gain.target == 0 && gain.current < Self.silenceThreshold
    }

    mutating func update(frequency newFrequency: Double, isPlaying: Bool) {
        if gain.current < Self.silenceThreshold {
            // 無音から鳴らし始めるときは、前回の周波数から滑らせず目標の周波数でそのまま始める
            frequency.snap(to: newFrequency)
        } else {
            frequency.target = newFrequency
        }
        if !isPlaying && isSilent {
            gain.snap(to: 0)
        }
        gain.target = isPlaying ? 1 : 0
    }

    /// 振幅 1 を上限としたサンプルを返す
    mutating func nextSample() -> Float {
        generator.frequency = frequency.next()
        let currentGain = gain.next()
        return generator.nextSample() * Float(currentGain)
    }
}
