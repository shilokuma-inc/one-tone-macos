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
    
    init() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(audioPlayerNode, to: mainMixer, format: nil)
        try! audioEngine.start()
    }
    
    func playTone(frequency: Double, duration: Double = 5.0) {
        let sampleRate: Double = 44100.0
        let amplitude: Float = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioPlayerNode.outputFormat(forBus: 0), frameCapacity: frameCount)!
        
        for i in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)) * amplitude
            buffer.floatChannelData![0][i] = sample
            buffer.floatChannelData![1][i] = sample
        }
        buffer.frameLength = frameCount
        
        audioPlayerNode.stop()
        audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        audioPlayerNode.play()
    }
    
    func playToneWithRhythm(frequency: Double, rhythm: [Double]) {
        stopTone()
        var startTime: TimeInterval = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            if startTime >= rhythm.reduce(0, +) {
                startTime = 0
            }
            
            let currentBeat = rhythm.first(where: { $0 >= startTime })
            
            if let currentBeat = currentBeat, startTime.truncatingRemainder(dividingBy: currentBeat) < 0.1 {
                self.playTone(frequency: frequency, duration: currentBeat)
            } else {
                self.stopTone()
            }
            
            startTime += 0.1
        }
    }
    
    func stopTone() {
        audioPlayerNode.stop()
        timer?.invalidate()
        timer = nil
    }
}
