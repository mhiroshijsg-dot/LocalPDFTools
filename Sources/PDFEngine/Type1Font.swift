/// Type1 フォント（PDF の /FontFile）を読み取った中身。CFF に作り直すために使う（Type1FontParser が作る）
struct Type1Font {
    var fontName = ""
    var fontMatrix: [Double] = [0.001, 0, 0, 0.001, 0, 0]
    var fontBBox: [Double] = [0, 0, 0, 0]
    var paintType = 0
    /// フォントに組み込まれた文字の割り当て（文字の番号 → 字形の名前）。nil なら標準（StandardEncoding）
    var encoding: [Int: String]?
    var italicAngle: Double?
    var underlinePosition: Double?
    var underlineThickness: Double?
    var isFixedPitch = false
    /// Private 辞書のうち、CFF に写す値（/BlueValues など。配列は配列のまま）
    var privateValues: [String: [Double]] = [:]
    /// 字形の描き方の暗号を解く前に捨てるバイト数
    var lenIV = 4
    /// 暗号を解いた下請けの描き方（Subrs）
    var subrs: [[UInt8]] = []
    /// 暗号を解いた字形の描き方（名前 → 中身）。並びはフォントの中の順
    var charStrings: [(name: String, data: [UInt8])] = []
}
