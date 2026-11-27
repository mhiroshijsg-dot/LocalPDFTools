import SwiftUI

/// 使い方の流れの図: ① PDF を入れる → ② 操作をオンにする → ③ 実行して保存。
/// 作業台の見た目（操作の色の印・スイッチ・青い大きなボタン）を小さくして並べ、画面と結び付けやすくする
struct HelpFlowFigure: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            step(1, title: "PDF を入れる", caption: "ドラッグ＆ドロップ\nまたは「＋」") {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            arrow
            step(2, title: "操作をオンにする", caption: "やりたい操作の\nスイッチをオン") {
                VStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(Operation.allCases) { OperationIcon(operation: $0, size: 16) }
                    }
                    // 見本なので押せないようにする
                    Toggle("オン", isOn: .constant(true))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .allowsHitTesting(false)
                }
            }
            arrow
            step(3, title: "実行して保存", caption: "保存名と保存先を\n確かめて押す（⌘S）") {
                Text("実行して保存…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }

    private func step<Picture: View>(_ number: Int, title: LocalizedStringKey, caption: LocalizedStringKey,
                                     @ViewBuilder picture: () -> Picture) -> some View {
        VStack(spacing: 8) {
            picture()
                .frame(height: 44)
            HStack(spacing: 5) {
                Text("\(number)")
                    .font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.secondary))
                Text(title).font(.callout.weight(.semibold))
            }
            Text(caption)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.body.weight(.bold))
            .foregroundStyle(.tertiary)
            .frame(height: 44)
    }
}
