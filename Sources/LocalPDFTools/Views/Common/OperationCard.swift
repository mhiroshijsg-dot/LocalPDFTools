import SwiftUI

/// 操作 1 つ分のカード: 色の印・名前・一言・右にスイッチ。オンのときだけ下に詳しい内容を出す
struct OperationCard<Details: View>: View {
    let operation: Operation
    @Binding var isOn: Bool
    /// まだ作っていない操作は false（スイッチの代わりに「今後のバージョンで追加」を出す）
    var isAvailable = true
    /// ほかの操作と同時に使えないとき、その理由（結合と分割）。オフのときはスイッチを押せなくして理由を出す
    var blockedReason: String? = nil
    @ViewBuilder var details: () -> Details

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                OperationIcon(operation: operation, isEnabled: isAvailable)
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.title).font(.body.weight(.semibold))
                    Text(operation.summary).font(.callout).foregroundStyle(.secondary)
                    if !isAvailable {
                        Text("今後のバージョンで追加").font(.caption).foregroundStyle(.secondary)
                    } else if let blockedReason, !isOn {
                        Text(blockedReason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if isAvailable {
                    Toggle(operation.title, isOn: $isOn.animation(.snappy(duration: 0.2)))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(blockedReason != nil && !isOn)
                }
            }
            if isOn && isAvailable {
                VStack(alignment: .leading, spacing: 6) { details() }
                    .font(.callout)
                    .padding(.leading, 40)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOn && isAvailable ? OperationIcon.color(of: operation).opacity(0.55) : Color.primary.opacity(0.06),
                              lineWidth: 1)
        )
        .opacity(isAvailable ? 1 : 0.55)
        .contentShape(Rectangle())
    }
}
