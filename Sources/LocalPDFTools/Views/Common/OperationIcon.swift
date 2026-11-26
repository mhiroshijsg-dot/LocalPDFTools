import SwiftUI

/// 操作の印: 色の付いた角丸の四角に白い記号（システム設定の項目と同じ見せ方）。
/// MEMO(2026-11-26・by claude): 操作ごとに色を決めておき、操作の欄・これから行うことの欄・設定で同じ色を使う。
/// 色で「どの操作か」を見分けられるようにするため。
struct OperationIcon: View {
    let operation: Operation
    var size: CGFloat = 28
    /// まだ使えない操作は灰色にする
    var isEnabled = true

    var body: some View {
        Image(systemName: operation.symbolName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill((isEnabled ? Self.color(of: operation) : Color.gray).gradient)
            )
    }

    static func color(of operation: Operation) -> Color {
        switch operation {
        case .decrypt: return .orange
        case .rotate: return .blue
        case .merge: return .purple
        case .compress: return .green
        case .text: return .teal
        }
    }
}
