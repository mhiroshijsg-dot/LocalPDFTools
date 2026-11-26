/// 図の線を減らすやり方（matplotlib などで作った図向け）。
/// MEMO(2026-11-26・by claude): 村田さんの `make_compact_pdf.py` を移したもの。①②は見た目が変わるので、
/// 本人が選んだときだけ行う（既定はすべてオフ）。
public struct VectorThinning: Equatable, Sendable {
    /// 曲線の点を間引くときの、元の線からのずれの上限（ポイント）
    public static let tolerance = 0.1

    /// ① 補助グリッド線（同じ形の破線が 20 本以上繰り返すもの）を消す。見た目が変わる
    public var removeMinorGrid = false
    /// ② 補助目盛（文書の中で一番短い目盛で、同じ形が 20 本以上繰り返すもの）を消す。見た目が変わる
    public var removeMinorTicks = false
    /// ③ 曲線（折れ線）の点を、ずれが tolerance 以内に収まるように間引く。見た目はほぼ変わらない
    public var simplifyCurves = false

    public init(removeMinorGrid: Bool = false, removeMinorTicks: Bool = false, simplifyCurves: Bool = false) {
        self.removeMinorGrid = removeMinorGrid
        self.removeMinorTicks = removeMinorTicks
        self.simplifyCurves = simplifyCurves
    }

    public var isActive: Bool { removeMinorGrid || removeMinorTicks || simplifyCurves }
}
