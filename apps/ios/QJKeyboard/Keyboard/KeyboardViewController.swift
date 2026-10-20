//
//  KeyboardViewController.swift
//  青简键盘扩展入口：承载 SwiftUI 键盘界面，维护拼音缓冲与候选，桥接文本输入。
//

import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController, ObservableObject {

    // MARK: - UI 状态

    /// 当前拼音串（仅中文模式）。
    @Published var pinyin: String = ""
    /// 候选上屏词。
    @Published var candidates: [String] = []
    /// 是否为英文直出模式。
    @Published var isEnglish: Bool = false

    private var hostingController: UIHostingController<KeyboardView>?

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()

        let bridgeReady = QjEngineBridge.shared.setupIfNeeded()
        if !bridgeReady {
            // 词库缺失也不应崩溃：键盘仍可用于英文直出。
            isEnglish = true
        }

        let hosting = UIHostingController(rootView: KeyboardView(controller: self))
        hostingController = hosting
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hosting.didMove(toParent: self)

        // 固定键盘高度（候选栏 + 四行键）。
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 268)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        QjEngineBridge.shared.flush()
    }

    // MARK: - 按键逻辑

    /// 字母键：英文模式直接上屏；中文模式追加拼音并刷新候选。
    func tapLetter(_ letter: String) {
        if isEnglish {
            textDocumentProxy.insertText(letter)
            return
        }
        pinyin.append(letter)
        refresh()
    }

    /// 退格：中文模式先删拼音；拼音为空或英文模式删除文本。
    func tapBackspace() {
        if !isEnglish && !pinyin.isEmpty {
            pinyin.removeLast()
            refresh()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    /// 空格：中文模式上屏首选；否则插入空格。
    func tapSpace() {
        if !isEnglish && !candidates.isEmpty {
            commitCandidate(at: 0)
        } else {
            textDocumentProxy.insertText(" ")
        }
    }

    /// 换行：有未上屏拼音时先原样上屏拼音；否则插入换行。
    func tapReturn() {
        if !isEnglish && !pinyin.isEmpty {
            let raw = QjEngineBridge.shared.commitRaw()
            if !raw.isEmpty {
                textDocumentProxy.insertText(raw)
            }
            resetComposition()
        } else {
            textDocumentProxy.insertText("\n")
        }
    }

    /// 点选候选。
    func tapCandidate(_ index: Int) {
        guard !isEnglish else { return }
        commitCandidate(at: index)
    }

    /// 中 / 英切换。
    func toggleMode() {
        isEnglish.toggle()
        if !pinyin.isEmpty {
            QjEngineBridge.shared.clear()
        }
        resetComposition()
    }

    // MARK: - 内核交互

    private func refresh() {
        guard !pinyin.isEmpty else {
            candidates = []
            QjEngineBridge.shared.clear()
            return
        }
        QjEngineBridge.shared.setInput(pinyin)
        if let result = QjEngineBridge.shared.query() {
            candidates = result.candidates
        } else {
            candidates = []
        }
    }

    private func commitCandidate(at index: Int) {
        let text = QjEngineBridge.shared.commit(index)
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
        resetComposition()
    }

    private func resetComposition() {
        pinyin = ""
        candidates = []
        QjEngineBridge.shared.clear()
    }
}
