import PDFEngine
import SwiftUI

/// 設定の窓（⌘,）: 言語と、操作を行う順番。順番は行をドラッグして並べ替える。
/// MEMO(2026-11-26・by claude): 上下の矢印ボタンは使いにくいと言われたので、ドラッグに変えた。
/// 右クリックの「上へ」「下へ」も残す（ドラッグしにくいとき用）。
struct SettingsView: View {
    @AppStorage(OperationOrder.storageKey) private var orderRaw = ""
    private static let rowHeight: CGFloat = 46

    var body: some View {
        let order = OperationOrder.reorderable(from: orderRaw)
        VStack(alignment: .leading, spacing: 14) {
            LanguageSettingsSection()
            Divider()
            VStack(alignment: .leading, spacing: 3) {
                Text("操作を行う順番").font(.title3.weight(.semibold))
                Text("行をドラッグして並べ替えられます。オンにした操作だけを、この順に行います。")
                    .font(.callout).foregroundStyle(.secondary)
            }

            List {
                StepRow(number: 1, operation: .decrypt, isPinned: true)
                    .frame(height: Self.rowHeight)
                ForEach(Array(order.enumerated()), id: \.element) { index, step in
                    StepRow(number: index + 2, operation: Operation(step), isPinned: false)
                        .frame(height: Self.rowHeight)
                        .contextMenu {
                            Button("上へ", systemImage: "arrow.up") { move(order, from: index, by: -1) }
                                .disabled(index == 0)
                            Button("下へ", systemImage: "arrow.down") { move(order, from: index, by: 1) }
                                .disabled(index == order.count - 1)
                        }
                }
                .onMove { source, destination in
                    var moved = order
                    moved.move(fromOffsets: source, toOffset: destination)
                    withAnimation(.snappy(duration: 0.2)) { orderRaw = OperationOrder.raw(moved) }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: false))
            .scrollDisabled(true)
            .frame(height: CGFloat(order.count + 1) * (Self.rowHeight + 8) + 4)

            HStack(spacing: 6) {
                ForEach(Array(([PipelineStep.decrypt] + order).enumerated()), id: \.element) { index, step in
                    if index > 0 {
                        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 4) {
                        OperationIcon(operation: Operation(step), size: 16)
                        Text(step == .decrypt ? String(localized: "解除") : Operation(step).title).font(.callout)
                    }
                }
                Spacer()
                Button("おすすめの順に戻す") {
                    withAnimation(.snappy(duration: 0.2)) { orderRaw = "" }
                }
                .disabled(order == OperationOrder.recommended)
            }

            Label("暗号化の解除がいつも最初なのは、後にすると結合のときにパスワードを他のプログラムから見える形で渡すしかなくなるためです。",
                  systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 480)
    }

    private func move(_ order: [PipelineStep], from index: Int, by offset: Int) {
        var order = order
        order.swapAt(index, index + offset)
        withAnimation(.snappy(duration: 0.2)) { orderRaw = OperationOrder.raw(order) }
    }
}

/// 順番の 1 行: 番号・印・名前と一言・右端に「つかむ所」（解除は鍵）
private struct StepRow: View {
    let number: Int
    let operation: Operation
    let isPinned: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.callout.weight(.bold)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 16)
            OperationIcon(operation: operation, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(operation.title).font(.body.weight(.medium))
                Text(isPinned ? String(localized: "いつも最初（動かせません）") : operation.summary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isPinned ? "lock.fill" : "line.3.horizontal")
                .font(.body.weight(.medium))
                .foregroundStyle(.tertiary)
                .help(isPinned ? "暗号化の解除はいつも最初です" : "ドラッグして並べ替え")
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
