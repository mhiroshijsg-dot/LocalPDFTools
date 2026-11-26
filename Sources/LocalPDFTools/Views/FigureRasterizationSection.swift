import PDFEngine
import SwiftUI

/// 圧縮のカードの中の「図を画像にする」（段階 5）: スイッチ・重い図の数・目安・解像度・図を選ぶシート。
/// 見た目が変わる（図の中の文字が画像になる）ので既定はオフ。オフでも、重い図が見つかれば数と見込みを知らせる。
struct FigureRasterizationSection: View {
    @Bindable var workspace: Workspace
    @State private var showsSheet = false

    private var model: CompressionModel { workspace.compression }

    var body: some View {
        @Bindable var model = workspace.compression
        let heavy = model.heavyFigures(in: workspace.files)
        let isEnabled = model.settings.figures.isEnabled
        let dpi = model.settings.figures.dpi
        let selected = heavy.filter { model.isSelected($0.figure) }.map(\.figure)
        return VStack(alignment: .leading, spacing: 5) {
            Toggle("図を画像にする", isOn: Binding(
                get: { isEnabled },
                set: { model.setFiguresEnabled($0, files: workspace.files) }
            ))
            .toggleStyle(.checkbox)
            .fontWeight(.medium)
            .help("点や線がとても多いグラフを、同じ位置・同じ大きさの画像に置き換えます。本文の文字はそのまま残ります")
            Text("点や線がとても多いグラフ向け。図の中の文字は画像になります。")
                .font(.caption).foregroundStyle(.secondary)

            if model.isAnalyzing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("図を探しています…").foregroundStyle(.secondary)
                }
            } else if heavy.isEmpty {
                if !workspace.files.isEmpty {
                    Text("重い図は見つかりませんでした").foregroundStyle(.secondary)
                }
            } else if isEnabled {
                enabledDetails(heavy: heavy.map(\.figure), selected: selected, dpi: dpi)
            } else {
                // オフのとき: 見込みだけ知らせる（選ぶのは本人）
                let effective = heavy.map(\.figure).filter { $0.isEffective(dpi: dpi) }
                let saving = effective.reduce(Int64(0)) { $0 + max(0, $1.byteCount - $1.estimatedBytes(dpi: dpi)) }
                Text(effective.isEmpty
                     ? "重い図 \(heavy.count) 個（画像にしても小さくならない見込み）"
                     : "重い図 \(heavy.count) 個（オンにすると約 \(FileSize.text(saving)) 減らせる見込み・目安）")
                    .foregroundStyle(.secondary)
            }
            heavyPagesNote
            errorsNote
        }
        .sheet(isPresented: $showsSheet) {
            FigureListSheet(workspace: workspace)
        }
    }

    @ViewBuilder
    private func enabledDetails(heavy: [HeavyFigure], selected: [HeavyFigure], dpi: Int) -> some View {
        @Bindable var model = workspace.compression
        let before = selected.reduce(Int64(0)) { $0 + $1.byteCount }
        let after = selected.reduce(Int64(0)) { $0 + min($1.byteCount, $1.estimatedBytes(dpi: dpi)) }
        Text("重い図 \(heavy.count) 個のうち \(selected.count) 個を画像にする")
            .foregroundStyle(selected.isEmpty ? Color.secondary : Color.green)
        if !selected.isEmpty {
            Text("選んだ図: \(FileSize.text(before)) → 約 \(FileSize.text(after))（目安）")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
            Text("解像度").foregroundStyle(.secondary)
            Picker("解像度", selection: $model.settings.figures.dpi) {
                ForEach(FigureRasterization.dpiChoices, id: \.self) { Text("\($0) dpi").tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            .help("ページ上に置かれた大きさに対する細かさ。上げるほどきれいで、大きくなります")
            Button {
                showsSheet = true
            } label: {
                Label("図を選ぶ…", systemImage: "square.grid.2x2")
            }
        }
        if !selected.isEmpty {
            Label("見た目が変わります（図の中の文字は選択・検索できなくなります）", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    /// 図として独立しておらず、ページに直接描かれた重い描画（画像にできない）
    @ViewBuilder
    private var heavyPagesNote: some View {
        let notes = workspace.files.compactMap { file -> String? in
            guard let pages = model.figureReports[file.id]?.heavyPages, !pages.isEmpty else { return nil }
            return "\(file.fileName) の \(pages.map(String.init).joined(separator: "・")) ページ"
        }
        if !notes.isEmpty {
            Text("ページと一体で描かれた重い図は画像にできません: " + notes.joined(separator: "、"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var errorsNote: some View {
        let failed = workspace.files.filter { model.figureErrors[$0.id] != nil }
        if !failed.isEmpty {
            Text("図を探せなかった PDF: " + failed.map(\.fileName).joined(separator: "、"))
                .font(.caption).foregroundStyle(.red)
                .help(failed.compactMap { model.figureErrors[$0.id] }.joined(separator: "\n"))
        }
    }
}
