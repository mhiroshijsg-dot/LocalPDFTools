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
        case .printLow: return String(localized: "印刷", bundle: .engine)
        case .printHigh: return String(localized: "高画質の印刷", bundle: .engine)
        case .extract: return String(localized: "文字や画像のコピー", bundle: .engine)
        case .modifyAssembly: return String(localized: "ページの追加・削除・並べ替え", bundle: .engine)
        case .modifyOther: return String(localized: "内容の編集", bundle: .engine)
        case .modifyAnnotations: return String(localized: "注釈の追加", bundle: .engine)
        case .modifyForms: return String(localized: "フォームへの入力", bundle: .engine)
        case .accessibility: return String(localized: "読み上げ機能での読み取り", bundle: .engine)
        }
    }
}
