import Foundation

/// PDFEngine が出すエラー。画面にはそのまま日本語の説明を出す。
public enum EngineError: LocalizedError, Equatable {
    case qpdfNotFound(searched: [String])
    case qpdfFailed(exitCode: Int32, message: String)
    case outputSameAsInput(path: String)
    case unreadablePDF(path: String)
    case passwordRequired(path: String)
    case wrongPassword(path: String)
    case stillEncrypted(path: String)
    case outputNotCreated

    public var errorDescription: String? {
        switch self {
        case .qpdfNotFound(let searched):
            return "qpdf が見つかりません。探した場所: " + searched.joined(separator: ", ")
        case .qpdfFailed(let exitCode, let message):
            return "qpdf が失敗しました（終了コード \(exitCode)）。qpdf の報告: \(message)"
        case .outputSameAsInput(let path):
            return "保存先が入力のファイルと同じです。元のファイルを壊さないため、別の名前か場所を選んでください: \(path)"
        case .unreadablePDF(let path):
            return "PDF として読めません: \(path)"
        case .passwordRequired(let path):
            return "開くのにパスワードが要る PDF です。先に「暗号化の解除」でパスワードを外してください: \(path)"
        case .wrongPassword(let path):
            return "パスワードが違います: \(path)"
        case .stillEncrypted(let path):
            return "解除したはずの出力がまだ暗号化されていたので、保存をやめました: \(path)"
        case .outputNotCreated:
            return "出力のファイルができていません。"
        }
    }
}
