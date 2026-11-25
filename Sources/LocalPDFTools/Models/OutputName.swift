import Foundation

/// 保存するファイル名と、その文字数の確認
struct OutputName {
    /// 末尾に .pdf が無ければ付ける
    static func withPDFExtension(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "output.pdf" }
        return trimmed.lowercased().hasSuffix(".pdf") ? trimmed : trimmed + ".pdf"
    }

    /// 文字数（拡張子 .pdf も含めて数える。日本語も 1 文字は 1）
    /// MEMO(2026-11-25・by claude): 提出先の「ファイル名 ○ 文字以下」という決まりは、拡張子を含むかが書かれていないことが多いので、厳しい側（含める）で数える。
    static func length(_ name: String) -> Int {
        name.count
    }

    /// 上限（0 は上限なし）を超えているか
    static func exceeds(_ name: String, limit: Int) -> Bool {
        limit > 0 && length(name) > limit
    }
}
