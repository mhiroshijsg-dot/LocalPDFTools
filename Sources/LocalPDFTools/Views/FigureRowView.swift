import PDFEngine
import SwiftUI

/// 図を選ぶシートの 1 行: チェック・縮小表示・ページ・描く命令の数・今の大きさ → 画像にした場合の目安
struct FigureRowView: View {
    let figure: HeavyFigure
    let thumbnail: CGImage?
    let dpi: Int
    @Binding var isSelected: Bool

    var body: some View {
        let estimate = figure.estimatedBytes(dpi: dpi)
        let isEffective = figure.isEffective(dpi: dpi)
        HStack(spacing: 14) {
            Toggle("画像にする", isOn: $isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            thumbnailView
            VStack(alignment: .leading, spacing: 3) {
                Text("\(figure.pageNumber) ページ目の図").fontWeight(.medium)
                Text("描く命令 \(figure.operationCount.formatted()) 個 · ページ上 \(Int(figure.placedSize.width)) × \(Int(figure.placedSize.height)) ポイント")
                    .font(.callout).foregroundStyle(.secondary)
                if isEffective {
                    Text("\(FileSize.text(figure.byteCount)) → 約 \(FileSize.text(estimate))（目安）")
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.green : Color.secondary)
                } else {
                    Text("\(FileSize.text(figure.byteCount)) · 効果なし（画像にしても小さくならない見込み）")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .opacity(isEffective || isSelected ? 1 : 0.6)
    }

    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white)
            if let thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 120, height: 90)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.secondary.opacity(0.3)))
    }
}
