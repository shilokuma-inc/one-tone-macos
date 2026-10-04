//
//  TitleView.swift
//  OneTone
//

import SwiftUI

/// 虹色のグラデーションの色相を回し続けるタイトル
struct TitleView: View {
    @State private var hue: Double = 0

    var body: some View {
        Text("One Tone")
            .foregroundColor(Color.white)
            .font(.custom("Helvetica Neue", size: 60))
            .fontWeight(.bold)
            // iPhone の幅では 60pt のままだとタイトルが収まらないので縮小を許可する
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.red, Color.orange, Color.yellow, Color.green,
                        Color.blue, Color.purple, Color.red
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text("One Tone")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                )
                .font(.custom("Helvetica Neue", size: 60))
                .fontWeight(.bold)
                .hueRotation(Angle(degrees: hue))
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    hue = 360
                }
            }
    }
}

#Preview {
    TitleView()
}
