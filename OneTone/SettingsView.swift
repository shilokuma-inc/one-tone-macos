//
//  SettingsView.swift
//  OneTone
//

import SwiftUI

/// 設定画面の中身。macOS は設定ウィンドウ（`Settings` シーン）、iOS はメイン画面から開くシートで同じ View を使う。
/// 選んだ値はその場で `@AppStorage` に保存され、メイン画面にもすぐ反映される
struct SettingsView: View {
    @AppStorage(ThemeColor.storageKey) private var themeColor: ThemeColor = .default

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DeckPanel(title: "THEME COLOR") {
                    ThemeColorPicker(selection: $themeColor)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(width: 420, height: 320)
        #endif
        .themedScreen()
        // 設定画面自体も選んだテーマの差し色で表示する
        .environment(\.themeColor, themeColor)
    }
}

/// テーマカラーの選択。色見本と名前を並べ、選択中は差し色の枠とチェックで示す（色だけに頼らない）
struct ThemeColorPicker: View {
    @Binding var selection: ThemeColor

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ThemeColor.allCases) { theme in
                let isSelected = theme == selection
                Button {
                    selection = theme
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(theme.onAccent)
                                }
                            }
                        Text(theme.displayName)
                            .font(.system(.caption, design: .rounded).weight(isSelected ? .bold : .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WaveformButtonStyle(isSelected: isSelected))
                .accessibilityLabel(theme.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
    }
}

#Preview {
    SettingsView()
}

#Preview("選択の見た目") {
    ThemeColorPicker(selection: .constant(.pink))
        .padding()
        .frame(width: 400)
        .themedScreen()
        .environment(\.themeColor, .pink)
}
