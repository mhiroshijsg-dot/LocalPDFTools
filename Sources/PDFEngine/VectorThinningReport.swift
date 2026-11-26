/// 図の線を減らすと、どれだけ減るか（実行前に数える。実行後の結果にも使う）
public struct VectorThinningReport: Sendable, Equatable {
    /// 消せる補助グリッド線の本数
    public var gridLines = 0
    /// 消せる補助目盛の本数
    public var tickMarks = 0
    /// 曲線の点の数（間引く前・後）
    public var pointsBefore = 0
    public var pointsAfter = 0
    /// 小さくなる大きさの目安（バイト。PDF の中の圧縮後の大きさに直したもの）
    public var gridBytes: Int64 = 0
    public var tickBytes: Int64 = 0
    public var curveBytes: Int64 = 0

    public init() {}

    /// 選んだやり方で小さくなる大きさの目安
    public func savedBytes(_ thinning: VectorThinning) -> Int64 {
        (thinning.removeMinorGrid ? gridBytes : 0) + (thinning.removeMinorTicks ? tickBytes : 0)
            + (thinning.simplifyCurves ? curveBytes : 0)
    }

    public static func + (lhs: VectorThinningReport, rhs: VectorThinningReport) -> VectorThinningReport {
        var sum = lhs
        sum.gridLines += rhs.gridLines
        sum.tickMarks += rhs.tickMarks
        sum.pointsBefore += rhs.pointsBefore
        sum.pointsAfter += rhs.pointsAfter
        sum.gridBytes += rhs.gridBytes
        sum.tickBytes += rhs.tickBytes
        sum.curveBytes += rhs.curveBytes
        return sum
    }
}
