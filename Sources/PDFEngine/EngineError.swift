import Foundation

/// PDFEngine が出すエラー。画面にはそのまま説明を出す（日本語・英語。訳はエンジンの Localizable.xcstrings）。
public enum EngineError: LocalizedError, Equatable {
    case qpdfNotFound(searched: [String])
    case qpdfFailed(exitCode: Int32, message: String)
    case outputSameAsInput(path: String)
    case unreadablePDF(path: String)
    case passwordRequired(path: String)
    case wrongPassword(path: String)
    case stillEncrypted(path: String)
    case outputNotCreated
    case passwordCancelled(path: String)
    case nothingToDo
    case pageNotRendered(page: Int, path: String)
    case invalidPageRanges(reason: String)

    public var errorDescription: String? {
        switch self {
        case .qpdfNotFound(let searched):
            return String(localized: "qpdf が見つかりません。探した場所: \(searched.joined(separator: ", "))", bundle: .engine)
        case .qpdfFailed(let exitCode, let message):
            return String(localized: "qpdf が失敗しました（終了コード \(exitCode)）。qpdf の報告: \(message)", bundle: .engine)
        case .outputSameAsInput(let path):
            return String(localized: "保存先が入力のファイルと同じです。元のファイルを壊さないため、別の名前か場所を選んでください: \(path)", bundle: .engine)
        case .unreadablePDF(let path):
            return String(localized: "PDF として読めません: \(path)", bundle: .engine)
        case .passwordRequired(let path):
            return String(localized: "開くのにパスワードが要る PDF です。「暗号化の解除」にチェックを入れてください: \(path)", bundle: .engine)
        case .wrongPassword(let path):
            return String(localized: "パスワードが違います: \(path)", bundle: .engine)
        case .stillEncrypted(let path):
            return String(localized: "解除したはずの出力がまだ暗号化されていたので、保存をやめました: \(path)", bundle: .engine)
        case .outputNotCreated:
            return String(localized: "出力のファイルができていません。", bundle: .engine)
        case .passwordCancelled(let path):
            return String(localized: "パスワードの入力をやめたので、このファイルは処理しませんでした: \(path)", bundle: .engine)
        case .nothingToDo:
            return String(localized: "行う操作がありません。", bundle: .engine)
        case .pageNotRendered(let page, let path):
            return String(localized: "\(page) ページ目を画像にできなかったので、OCR できませんでした: \(path)", bundle: .engine)
        case .invalidPageRanges(let reason):
            return String(localized: "分けるページの指定が正しくありません: \(reason)", bundle: .engine)
        }
    }
}
