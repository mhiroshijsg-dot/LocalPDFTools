import PDFEngine
import SwiftUI

/// 図を選ぶシート: 入れた全ファイルの重い図を、ファイルごとに区切って並べ、画像にする図にチェックを付ける
struct FigureListSheet: View {
    @Bindable var workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    private var model: CompressionModel { workspace.compression }

    var body: some View {
        let dpi = model.settings.figures.dpi
        let heavy = model.heavyFigures(in: workspace.files)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                OperationIcon(operation: .compress, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("図を画像にする").font(.title3.weight(.semibold))
                    Text("チェックした図を、同じ位置・同じ大きさの画像に置き換えます")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    heavy.forEach { model.setSelected($0.figure, $0.figure.isEffective(dpi: dpi)) }
                } label: {
                    Label("効果のある図をすべて選ぶ", systemImage: "checkmark.circle")
                }
                Button {
                    heavy.forEach { model.setSelected($0.figure, false) }
                } label: {
                    Label("すべて外す", systemImage: "circle")
                }
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(workspace.files) { file in
                        let figures = model.figureReports[file.id]?.heavyFigures ?? []
                        if !figures.isEmpty {
                            section(file, figures: figures, dpi: dpi)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            footer(heavy.map(\.figure), dpi: dpi)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private func section(_ file: WorkFile, figures: [HeavyFigure], dpi: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(file.fileName).font(.headline)
                if model.loadingThumbnails.contains(file.id) {
                    ProgressView().controlSize(.small)
                    Text("図を描いています…").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(figures) { figure in
                FigureRowView(figure: figure, thumbnail: model.figureThumbnails[figure.id], dpi: dpi,
                              isSelected: Binding(get: { model.isSelected(figure) },
                                                  set: { model.setSelected(figure, $0) }))
            }
        }
        // 縮小表示は、この欄を出したときに初めて作る（図を描くので、点の多い図では数秒かかることがある）
        .task { await model.loadThumbnails(file) }
    }

    private func footer(_ figures: [HeavyFigure], dpi: Int) -> some View {
        @Bindable var model = workspace.compression
        let selected = figures.filter { model.isSelected($0) }
        let saving = selected.reduce(Int64(0)) { $0 + max(0, $1.byteCount - $1.estimatedBytes(dpi: dpi)) }
        return HStack(spacing: 12) {
            Text(selected.isEmpty ? "画像にする図はまだありません"
                 : "\(selected.count) 個を画像にする予定・約 \(FileSize.text(saving)) 減る見込み（目安）")
                .foregroundStyle(.secondary)
            Spacer()
            Text("解像度").foregroundStyle(.secondary)
            Picker("解像度", selection: $model.settings.figures.dpi) {
                ForEach(FigureRasterization.dpiChoices, id: \.self) { Text("\($0) dpi").tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            Button("完了") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(16)
    }
}
