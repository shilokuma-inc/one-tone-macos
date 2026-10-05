//
//  OneToneApp.swift
//  OneTone
//
//  Created by 村石 拓海 on 2024/05/28.
//

import SwiftUI

@main
struct OneToneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // スクリーンショットの撮影モードでは、止まらないアニメーションを止めて画面を静止させる
                .environment(\.freezesAnimations, ScreenshotDemo.isEnabled)
        }
    }
}
