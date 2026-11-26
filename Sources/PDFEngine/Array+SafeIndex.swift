/// 範囲外なら nil を返す添字（フォントの語の並びを読むときに使う）
extension Array {
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
