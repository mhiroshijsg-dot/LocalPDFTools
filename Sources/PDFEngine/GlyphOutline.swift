/// 字形 1 つの形（絶対座標の線と曲線）・送り幅・ステムの手がかり（hint）。
/// Type1 の描き方を実行して作り（Type1CharStringInterpreter）、CFF の描き方に書き直す（Type2CharStringEncoder）
struct GlyphOutline {
    struct Point: Equatable {
        var x: Double
        var y: Double
    }

    enum Segment: Equatable {
        case move(Point)
        case line(Point)
        case curve(Point, Point, Point)
    }

    /// ステム（位置と幅。幅が負なのは片側だけの手がかり＝ゴーストの手がかり）
    struct Stem: Equatable {
        var position: Double
        var width: Double
    }

    var segments: [Segment] = []
    var width: Double = 0
    var horizontalStems: [Stem] = []
    var verticalStems: [Stem] = []
}
