//
//  QJApp.swift
//  青简宿主 App：仅用于承载键盘扩展，并提供启用引导。
//

import SwiftUI

@main
struct QJApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.14, 0.12).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("青简键盘")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(Color(red: 0.44, green: 0.78, 0.60))
                Text("已安装。这是青简开源拼音输入法的 iOS 个人移植版（M0）。")
                    .foregroundColor(Color(red: 0.80, green: 0.85, 0.81))
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 12) {
                    step("1", "设置 → 通用 → 键盘 → 键盘 → 添加新键盘")
                    step("2", "在列表中选择“青简键盘”")
                    step("3", "在任意输入框调起键盘，用地球键切换")
                }
                .padding(.top, 4)
                Text("词库完全离线、不联网；本版本为自包含内测构建，若键盘无法调起请重新安装。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.55, green: 0.62, 0.58))
                Spacer()
            }
            .padding(28)
        }
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color(red: 0.22, green: 0.55, 0.38))
                .clipShape(Circle())
            Text(text)
                .foregroundColor(Color(red: 0.85, green: 0.89, 0.86))
                .font(.system(size: 15))
        }
    }
}
