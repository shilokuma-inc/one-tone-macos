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
            .foregroundStyle(Theme.textPrimary)
            .font(.custom("Helvetica Neue", size: 60))
            .fontWeight(.bold)
            // iPhone の幅では 60pt のままだとタイトルが収まらないので縮小を許可する
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: Theme.rainbow),
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
        .padding()
        .themedScreen()
}
