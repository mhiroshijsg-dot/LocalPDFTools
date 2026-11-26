import Foundation

/// 1 つの PDF の図の一覧（圧縮の画面の「図を画像にする」に出す）
public struct FigureReport: Sendable {
    /// ページに置かれた図のすべて（見つけた順）
    public let figures: [HeavyFigure]
    /// ページに直接書かれた命令が多い（図として独立していない重い描画がある）ページ（1 始まり）
    public let heavyPages: [Int]

    /// 一覧に出す重い図
    public var heavyFigures: [HeavyFigure] { figures.filter(\.isHeavy) }
}
