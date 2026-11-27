import SwiftUI

/// 流れの矢印の中に並べる、操作 1 つ分の小さな札（印＋短い名前・操作の色の淡い背景）。
/// 「これから行うこと」とヘルプの順番の図で同じものを使う
struct OperationChip: View {
    let operation: Operation

    var body: some View {
        HStack(spacing: 5) {
            OperationIcon(operation: operation, size: 18)
            Text(shortTitle).font(.callout.weight(.medium))
        }
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(OperationIcon.color(of: operation).opacity(0.12)))
    }

    /// 矢印の中では短い名前にする
    private var shortTitle: String {
        operation == .decrypt ? String(localized: "解除") : operation.title
    }

    /// 札と札の間の矢印
    static var arrow: some View {
        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
    }
}
