//
//  TutorialView.swift
//  OneTone
//

import SwiftUI

/// チュートリアルの画面。`Tutorial.pages` を 1 ページずつ表示する。
///
/// iOS はスワイプでページを送り（`TabView` の page スタイル）、macOS は Back / Next ボタンとページインジケーターで送る。
/// Skip・最後のページの完了・閉じるボタンのどれで閉じても、`onDismiss` で閉じ方を呼び出し元に伝える（どれも既読にする）。
/// シートを下へスワイプするなど、この画面の外で閉じられた場合は呼び出し元が `.closed` として扱う
struct TutorialView: View {
    let pages: [TutorialPage]
    let onDismiss: (TutorialDismissal) -> Void

    @State private var pager: TutorialPager

    init(pages: [TutorialPage] = Tutorial.pages, onDismiss: @escaping (TutorialDismissal) -> Void) {
        self.pages = pages
        self.onDismiss = onDismiss
        _pager = State(initialValue: TutorialPager(pageCount: pages.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            pageContent
            footer
        }
        #if os(macOS)
        .frame(width: TutorialLayout.macSize.width, height: TutorialLayout.macSize.height)
        #endif
        .themedScreen()
    }

    // MARK: - 上部（閉じる・Skip）

    private var header: some View {
        HStack {
            Button {
                onDismiss(.closed)
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .accessibilityLabel("Close Tutorial")
            // macOS は Esc、iOS はハードウェアキーボードの Esc で閉じられる
            .keyboardShortcut(.cancelAction)

            Spacer()

            // 最後のページでは完了ボタンと役割が重なるので出さない（位置がずれないよう透明にして残す）
            Button("Skip") {
                onDismiss(.skipped)
            }
            .buttonStyle(.plain)
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .opacity(pager.isLastPage ? 0 : 1)
            .disabled(pager.isLastPage)
            .accessibilityHidden(pager.isLastPage)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - ページ

    @ViewBuilder
    private var pageContent: some View {
        #if os(iOS)
        TabView(selection: pageSelection) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                TutorialPageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #else
        TutorialPageView(page: pages[pager.index])
            .id(pager.index)
            .transition(.opacity)
        #endif
    }

    /// `TabView` の選択とページ送りの状態をつなぐ
    private var pageSelection: Binding<Int> {
        Binding(get: { pager.index }, set: { pager.show($0) })
    }

    // MARK: - 下部（ページ送り・完了）

    private var footer: some View {
        HStack(spacing: 16) {
            #if os(macOS)
            Button("Back") {
                withAnimation { pager.back() }
            }
            .buttonStyle(TutorialSecondaryButtonStyle())
            .opacity(pager.isFirstPage ? 0 : 1)
            .disabled(pager.isFirstPage)
            .accessibilityHidden(pager.isFirstPage)

            Spacer()

            TutorialPageIndicator(pageCount: pages.count, index: pager.index)

            Spacer()
            #endif

            primaryButton
        }
        .padding()
    }

    /// 最後のページでは完了、それ以外では次のページへ
    private var primaryButton: some View {
        Button {
            if pager.isLastPage {
                onDismiss(.completed)
            } else {
                withAnimation { pager.next() }
            }
        } label: {
            Text(pager.isLastPage ? "Get Started" : "Next")
                #if os(iOS)
                .frame(maxWidth: .infinity)
                #endif
        }
        .buttonStyle(TutorialPrimaryButtonStyle())
        .keyboardShortcut(.defaultAction)
    }
}

/// 1 ページ分の表示（画面のスクリーンショット・タイトル・本文・注意書き）
struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 16) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.surfaceRaised, lineWidth: 1))
                .frame(maxHeight: .infinity)
                // 画像は画面の見本で、内容は下の文章で説明する
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let caution = page.caution {
                    Label(caution, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.accentSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.surface))
                }
            }
            .frame(maxWidth: 480)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        #if os(iOS)
        // ページインジケーターと重ならないよう下に余白をとる
        .padding(.bottom, 48)
        #endif
    }
}

/// macOS のページインジケーター。今のページだけ差し色で塗り、幅も広げて色以外でも分かるようにする
struct TutorialPageIndicator: View {
    let pageCount: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { page in
                Capsule()
                    .fill(page == index ? Theme.accent : Theme.textDisabled)
                    .frame(width: page == index ? 20 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(index + 1) of \(pageCount)")
    }
}

/// 次へ・完了のボタン。差し色で塗る
private struct TutorialPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Capsule().fill(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1)))
            .contentShape(Capsule())
    }
}

/// 戻るボタン。面の色で目立たせない
private struct TutorialSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Capsule().fill(Theme.surfaceRaised.opacity(configuration.isPressed ? 0.6 : 1)))
            .contentShape(Capsule())
    }
}

/// チュートリアルの画面の大きさ
enum TutorialLayout {
    /// macOS のシートの大きさ（pt）。画像（16:10）と本文が縦に収まる大きさ
    static let macSize = CGSize(width: 640, height: 640)
}

#Preview("Tutorial") {
    TutorialView(onDismiss: { _ in })
}

#Preview("Volume page") {
    TutorialPageView(page: Tutorial.pages[3])
        .themedScreen()
}
