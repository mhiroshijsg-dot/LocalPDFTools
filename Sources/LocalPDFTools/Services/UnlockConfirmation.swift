import AppKit

/// PDF の保護（暗号化）を外す前の確認。
/// MEMO(2026-11-26・by claude): 村田さんの指示「保護を外すけどいいんだね？という確認をポップアップで出す」。
@MainActor
struct UnlockConfirmation {
    /// byMergeOnly は「解除にはチェックが無いが、結合で制限が外れる」場合
    func ask(fileNames: [String], byMergeOnly: Bool) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "PDF の保護を外します。よろしいですか？"
        let list = fileNames.map { "・" + $0 }.joined(separator: "\n")
        let reason = byMergeOnly
            ? "次の PDF は編集・印刷などが制限されています。結合すると、できあがる PDF にはこの制限が残りません。"
            : "次の PDF の暗号化（開くときのパスワード、編集・印刷などの制限）を外した PDF を保存します。"
        alert.informativeText = reason + "\n\n" + list + "\n\n"
            + "自分が権利を持つ書類（自分の成績証明書やスコアレポートなど）にだけ使ってください。元のファイルは変わりません。"
        alert.addButton(withTitle: "外して続ける")
        alert.addButton(withTitle: "やめる")
        alert.buttons[1].keyEquivalent = "\u{1b}"  // esc でやめる
        return alert.runModal() == .alertFirstButtonReturn
    }
}
