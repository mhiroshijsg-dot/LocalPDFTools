/// ヘルプの項目に、文章の他に出すもの
enum HelpAttachment: Hashable {
    /// 使い方の流れの図（入れる → オンにする → 保存）
    case flow
    /// 操作の順番の図（今の設定の順）
    case order
    /// 同梱した部品のライセンスの文を Finder で開くボタン
    case licenses

    /// 図なら文章の前、ボタンなら文章の後に出す
    var isFigure: Bool {
        self != .licenses
    }
}
