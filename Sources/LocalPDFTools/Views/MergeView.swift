import PDFEngine
import SwiftUI

/// 結合の画面: ファイルを並べ、ドラッグで順番を入れ替えて、1 つにまとめる
struct MergeView: View {
    @Bindable var model: MergeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.files.isEmpty {
                DropZone(prompt: "結合する PDF をここにドロップ（複数可）", allowsMultiple: true) { model.add($0) }
            } else {
                fileList
                HStack {
                    Text("\(model.files.count) ファイル・合計 \(model.totalPages) ページ・\(FileSize.text(model.totalBytes))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("PDF を追加…") {
                        let urls = FilePanels().choosePDFs(allowsMultiple: true)
                        if !urls.isEmpty { model.add(urls) }
                    }
                    Button("すべて外す") { model.removeAll() }
                }
            }

            Text("上から順に結合します。行をドラッグすると順番を変えられます。しおり（目次）と文書内のリンクは結合後に残りません（URL のリンクは残ります）。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.anyHasOutline {
                MessageList(messages: [.warning("しおり（目次）のある PDF が含まれています。結合した PDF にはしおりが残りません。")])
            }

            OutputNameField(name: $model.outputName)
            HStack {
                Button("結合して保存…") { Task { await model.mergeAndSave() } }
                    .keyboardShortcut("s")
                    .disabled(!model.canMerge)
                // TODO(2026-11-25・by claude): 圧縮の画面（段階 4）ができたら、保存せずに圧縮の画面へ渡す
                Button("結合して圧縮へ") {}
                    .disabled(true)
                    .help("圧縮の画面（段階 4）ができたら使えます")
                if model.isWorking { ProgressView().controlSize(.small) }
            }

            MessageList(messages: model.messages)
            if let outcome = model.outcome { OutcomeView(outcome: outcome) }
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("結合")
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return true
        }
    }

    private var fileList: some View {
        List {
            ForEach(Array(model.files.enumerated()), id: \.element.id) { index, file in
                HStack {
                    Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                    Text("\(index + 1).").monospacedDigit().frame(width: 28, alignment: .trailing)
                    Text(file.fileName).lineLimit(1).truncationMode(.middle)
                    if file.isEncrypted { Badge(text: "制限あり").help("編集・印刷などの制限付き。結合した PDF では制限は外れます") }
                    if file.hasOutline { Badge(text: "しおりあり") }
                    Spacer()
                    Text("\(file.pageCount) ページ").monospacedDigit().foregroundStyle(.secondary)
                    Text(FileSize.text(file.byteSize)).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Button {
                        model.remove(file)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("この PDF を外す")
                }
            }
            .onMove { model.move(fromOffsets: $0, toOffset: $1) }
        }
        .frame(minHeight: 160)
    }
}

#if DEBUG
#Preview("ファイルあり") {
    MergeView(model: PreviewSamples.mergeModel())
        .frame(width: 720, height: 560)
}

#Preview("空") {
    MergeView(model: MergeModel())
        .frame(width: 720, height: 560)
}
#endif
