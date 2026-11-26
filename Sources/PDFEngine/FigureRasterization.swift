/// 重い図を画像にするやり方。見た目が変わる（図の中の文字が画像になる）ので、既定はオフ。
/// MEMO(2026-11-26・by claude): 段階 5。村田さんの了承: 既定オフ・150/200/300 dpi・最初は 200・可逆の圧縮で固定。
public struct FigureRasterization: Equatable, Sendable {
    /// 選べる解像度（dpi）
    public static let dpiChoices = [300, 200, 150]

    /// 「図を画像にする」のスイッチ
    public var isEnabled: Bool
    /// 画像にする図（HeavyFigure.id = 中身の指紋）
    public var selected: Set<String>
    /// 画像にするときの解像度（ページ上に置かれた大きさに対して）
    public var dpi: Int

    public init(isEnabled: Bool = false, selected: Set<String> = [], dpi: Int = 200) {
        self.isEnabled = isEnabled
        self.selected = selected
        self.dpi = dpi
    }

    public var isActive: Bool { isEnabled && !selected.isEmpty }
}
