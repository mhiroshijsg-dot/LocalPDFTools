import SwiftUI

/// 色の付いた角丸の四角に白い記号（システム設定の項目と同じ見せ方）。
/// 操作の印（OperationIcon）とヘルプの項目の印が、同じ形になるように共通にしている
struct SymbolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(color.gradient)
            )
    }
}
