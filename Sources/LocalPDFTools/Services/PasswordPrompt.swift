import AppKit

/// 開くのにパスワードが要る PDF を処理する時点で、パスワードを 1 回だけ聞く。
/// MEMO(2026-11-26・by claude): 村田さんの指示「パスワードはどこにも保存しない（一時的にも）」。
/// 入力欄の中身を読んだらすぐ空にし、受け取った文字は呼び出し元がそのまま qpdf の標準入力へ渡す。
/// 設定・キーチェーン・ファイル・ログ・画面の状態のどれにも入れない。
@MainActor
enum PasswordPrompt {
    /// isRetry は「前に入れたパスワードが違った」。キャンセルなら nil
    static func ask(_ file: URL, _ isRetry: Bool) async -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "「\(file.lastPathComponent)」を開くパスワード")
        alert.informativeText = (isRetry ? String(localized: "パスワードが違いました。もう一度入力してください。") + "\n\n" : "")
            + String(localized: "パスワードはこの Mac の中で qpdf に渡すだけで、保存も送信もしません。")
        if isRetry { alert.alertStyle = .warning }
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = String(localized: "パスワード")
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "OK"))
        alert.addButton(withTitle: String(localized: "このファイルをやめる"))
        alert.buttons[1].keyEquivalent = "\u{1b}"  // esc でやめる
        alert.window.initialFirstResponder = field

        let answer = alert.runModal()
        let password = field.stringValue
        field.stringValue = ""
        return answer == .alertFirstButtonReturn ? password : nil
    }
}
