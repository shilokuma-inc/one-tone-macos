//
//  ContentView.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    
    var body: some View {
        VStack {
            Button(action: {
                audioManager.playTone(frequency: 24000.0)
            }) {
                Text("Play 20Hz Tone")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
