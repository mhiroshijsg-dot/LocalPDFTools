/// JPEG の画質の段階。
/// MEMO(2026-11-24・by claude): 計画 §4.2。Mac の JPEG 変換は 0.85 を超えてもほとんど大きくならないので、それより上は用意しない。
public enum JPEGQuality: String, CaseIterable, Sendable {
    case high, medium, low, lowest

    public var title: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        case .lowest: return "最低"
        }
    }

    /// Mac の JPEG 変換に渡す値（0〜1）
    public var value: Double {
        switch self {
        case .high: return 0.85
        case .medium: return 0.75
        case .low: return 0.6
        case .lowest: return 0.5
        }
    }

    /// 目安の計算に使う「元の大きさに対する割合」。
    /// MEMO(2026-11-26・by claude): 実測の表ではなく大まかな値。だから画面では必ず「目安」と書き、正確な数字は試算で出す。
    var estimatedRatio: Double {
        switch self {
        case .high: return 0.8
        case .medium: return 0.6
        case .low: return 0.45
        case .lowest: return 0.38
        }
    }
}
