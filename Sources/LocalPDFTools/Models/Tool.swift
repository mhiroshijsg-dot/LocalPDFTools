/// 左の一覧に並ぶ機能
enum Tool: String, CaseIterable, Identifiable {
    case merge, compress, rotate, encryption, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .merge: return "結合"
        case .compress: return "圧縮"
        case .rotate: return "回転"
        case .encryption: return "暗号化の解除"
        case .text: return "文字の抽出"
        }
    }

    var symbolName: String {
        switch self {
        case .merge: return "doc.on.doc"
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .rotate: return "rotate.right"
        case .encryption: return "lock.open"
        case .text: return "text.viewfinder"
        }
    }

    /// まだ作っていない機能は、作る予定の段階
    var plannedStage: Int? {
        switch self {
        case .merge, .rotate, .encryption: return nil
        case .text: return 3
        case .compress: return 4
        }
    }
}
