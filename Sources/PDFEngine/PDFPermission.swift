/// 暗号化された PDF で、許可・禁止が決められる操作。
/// rawValue は qpdf の JSON（`--json-key=encrypt` の capabilities）の名前。
public enum PDFPermission: String, CaseIterable, Sendable {
    case printLow = "printlow"
    case printHigh = "printhigh"
    case extract
    case modifyAssembly = "modifyassembly"
    case modifyOther = "modifyother"
    case modifyAnnotations = "modifyannotations"
    case modifyForms = "modifyforms"
    case accessibility

    public var title: String {
        switch self {
        case .printLow: return "印刷"
        case .printHigh: return "高画質の印刷"
        case .extract: return "文字や画像のコピー"
        case .modifyAssembly: return "ページの追加・削除・並べ替え"
        case .modifyOther: return "内容の編集"
        case .modifyAnnotations: return "注釈の追加"
        case .modifyForms: return "フォームへの入力"
        case .accessibility: return "読み上げ機能での読み取り"
        }
    }
}
