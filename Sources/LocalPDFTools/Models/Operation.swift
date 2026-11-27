import PDFEngine

/// 画面の「操作」の欄に並ぶもの
enum Operation: String, CaseIterable, Identifiable {
    case decrypt, rotate, merge, split, compress, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .decrypt: return "暗号化の解除"
        case .rotate: return "回転"
        case .merge: return "結合"
        case .split: return "分割"
        case .compress: return "圧縮"
        case .text: return "文字の抽出"
        }
    }

    /// 名前の下に出す一言（何をするか）
    var summary: String {
        switch self {
        case .decrypt: return "パスワードや制限を外す"
        case .rotate: return "ページの向きを直す"
        case .merge: return "1 つの PDF にまとめる"
        case .split: return "いくつかの PDF に分ける"
        case .compress: return "ファイルを小さくする"
        case .text: return "PDF の文字を取り出す"
        }
    }

    var symbolName: String {
        switch self {
        case .decrypt: return "lock.open.fill"
        case .rotate: return "rotate.right"
        case .merge: return "doc.on.doc.fill"
        case .split: return "scissors"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .text: return "text.viewfinder"
        }
    }

    /// 処理の部品の側の名前。PDF の保存の流れに入らない操作（文字の抽出）は nil
    var step: PipelineStep? {
        switch self {
        case .decrypt: return .decrypt
        case .rotate: return .rotate
        case .merge: return .merge
        case .split: return .split
        case .compress: return .compress
        case .text: return nil
        }
    }

    init(_ step: PipelineStep) {
        switch step {
        case .decrypt: self = .decrypt
        case .rotate: self = .rotate
        case .merge: self = .merge
        case .split: self = .split
        case .compress: self = .compress
        }
    }

    /// まだ作っていない操作（「今後のバージョンで追加」と出す）。
    /// MEMO(2026-11-26・by claude): 段階 3 で文字の抽出を作ったので、今は無い。今後の操作を足すときに使う
    static let upcoming: [Operation] = []
}
