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
}
