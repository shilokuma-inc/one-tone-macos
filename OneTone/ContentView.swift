//
//  ContentView.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var frequency: Double = 20.0
    @State private var hue: Double = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("One Tone")
                .foregroundColor(Color.white)
                .font(.custom("Helvetica Neue", size: 60))
                .fontWeight(.bold)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red, Color.orange, Color.yellow, Color.green,
                            Color.blue, Color.purple, Color.red
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .mask(Text("One Tone"))
                    .font(.custom("Helvetica Neue", size: 60))
                    .fontWeight(.bold)
                    .hueRotation(Angle(degrees: hue))
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                        hue = 360
                    }
                }
            
            Spacer()
            
            HStack {
                Button(action: {
                    audioManager.playTone(frequency: frequency)
                }) {
                    Text("Play Tone")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    audioManager.stopTone()
                }) {
                    Text("Stop Tone")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            Slider(value: Binding<Double>(
                get: {
                    log10(frequency)
                },
                set: { newValue in
                    frequency = pow(10, newValue)
                }
            ), in: log10(20)...log10(20000), step: 0.02) {
                Text("Frequency")
            }
            .padding()
            
            Text("Frequency: \(Int(frequency)) Hz")
                .padding()
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
