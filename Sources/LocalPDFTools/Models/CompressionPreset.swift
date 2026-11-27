import PDFEngine

/// 圧縮の品質（高・中・低）。詳細を開かなければ、この 3 つから選ぶだけで済む（iLovePDF と同じ形）。
/// 品質を選ぶと、詳細の中の設定（構造の圧縮・解像度・JPEG の画質・図の線を減らす）をまとめて書き換える。
/// 図を画像にするは、図を 1 つずつ選ぶものなので品質では変えない（詳細の中だけ）。
/// MEMO(2026-11-26・by claude): 村田さんの指示「詳細を開かない限りは三つの品質から選ぶ形にする。品質は高、中、低」。
/// 値は LaTeX で作った約 250 ページの文書（4.2 MB）で測って決めた: 高 2.4 MB・中 2.3 MB・低 2.2 MB（iLovePDF では 2.5 MB。フォントの作り直しと小さな部品の重複を入れた後）。
enum CompressionPreset: String, CaseIterable, Identifiable {
    case high, medium, low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return String(localized: "高")
        case .medium: return String(localized: "中")
        case .low: return String(localized: "低")
        }
    }

    /// この品質の設定。figures（図を画像にする）は base のまま残す
    func settings(keeping base: CompressionSettings) -> CompressionSettings {
        var settings = base
        settings.structural = true
        settings.vector = VectorThinning(removeMinorGrid: true, removeMinorTicks: true, simplifyCurves: true)
        switch self {
        case .high:
            settings.targetDPI = 300
            settings.jpegQuality = nil
        case .medium:
            settings.targetDPI = 150
            settings.jpegQuality = .medium
        case .low:
            settings.targetDPI = 100
            settings.jpegQuality = .low
        }
        return settings
    }

    /// 今の設定がどの品質と同じか（詳細で変えていれば nil）
    static func matching(_ settings: CompressionSettings) -> CompressionPreset? {
        allCases.first { $0.settings(keeping: settings) == settings }
    }

    /// 圧縮をオンにしたときの品質
    static let initial: CompressionPreset = .high
}
