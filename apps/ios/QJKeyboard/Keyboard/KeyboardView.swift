//
//  KeyboardView.swift
//  青简 M0 键盘界面：候选栏 + QWERTY 全拼 + 中英文切换 + 空格/回车/退格。
//

import SwiftUI

struct KeyboardView: View {
    @ObservedObject var controller: KeyboardViewController

    private let rows: [[String]] = [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            candidateBar
            keyboardArea
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Color(red: 0.10, green: 0.14, 0.12))
    }

    // MARK: - 候选栏

    private var candidateBar: some View {
        HStack(spacing: 0) {
            // 编码 / 上屏中显示
            Text(controller.isEnglish ? "英文" : (controller.pinyin.isEmpty ? "青简" : controller.pinyin))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.44, green: 0.78, green: 0.60))
                .frame(width: 56)
                .lineLimit(1)

            Rectangle()
                .fill(Color(red: 0.22, green: 0.30, 0.26))
                .frame(width: 1, height: 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if controller.candidates.isEmpty && !controller.pinyin.isEmpty {
                        Text("无候选").font(.system(size: 15)).foregroundColor(Color(red: 0.55, green: 0.62, 0.58))
                            .padding(.horizontal, 10)
                    }
                    ForEach(Array(controller.candidates.enumerated()), id: \.offset) { idx, word in
                        CandidateButton(title: word, emphasized: idx == 0) {
                            controller.tapCandidate(idx)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 40)
        }
        .frame(height: 40)
        .background(Color(red: 0.13, green: 0.18, 0.16))
        .cornerRadius(8)
    }

    // MARK: - 主键区

    private var keyboardArea: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 6) {
                    if rowIdx == 2 {
                        // 左下角：中英切换
                        WideKey(label: controller.isEnglish ? "中" : "EN", wide: false, accent: true) {
                            controller.toggleMode()
                        }
                    }
                    ForEach(row, id: \.self) { letter in
                        CharKey(label: letter.uppercased()) {
                            controller.tapLetter(letter)
                        }
                    }
                    if rowIdx == 2 {
                        // 右下角：退格
                        WideKey(label: "⌫", wide: false, accent: false) {
                            controller.tapBackspace()
                        }
                    }
                }
            }
            // 底行：数字/符号（切系统键盘）、空格、回车
            HStack(spacing: 6) {
                WideKey(label: "123", wide: false, accent: false) {
                    controller.advanceToNextInputMode()
                }
                WideKey(label: controller.isEnglish ? "space" : "空格", wide: true, accent: false) {
                    controller.tapSpace()
                }
                WideKey(label: "换行", wide: false, accent: true) {
                    controller.tapReturn()
                }
            }
        }
    }
}

/// 字符键。
private struct CharKey: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.91, green: 0.94, 0.91))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(red: 0.20, green: 0.26, 0.23))
                .cornerRadius(7)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 功能键 / 宽键。
private struct WideKey: View {
    let label: String
    let wide: Bool
    let accent: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accent ? Color(red: 0.44, green: 0.78, 0.60) : Color(red: 0.85, green: 0.89, 0.86))
                .frame(maxWidth: .infinity)
                .frame(width: wide ? nil : 62, height: 42)
                .background(Color(red: 0.14, green: 0.19, 0.17))
                .cornerRadius(7)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 候选词按钮。
private struct CandidateButton: View {
    let title: String
    let emphasized: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: emphasized ? 19 : 17, weight: emphasized ? .bold : .regular))
                .foregroundColor(emphasized ? Color(red: 0.44, green: 0.78, 0.60) : Color(red: 0.90, green: 0.93, 0.90))
                .padding(.horizontal, 12)
                .frame(height: 34)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
