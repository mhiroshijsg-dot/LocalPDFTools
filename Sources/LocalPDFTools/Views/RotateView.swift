import PDFEngine
import SwiftUI

/// 回転の画面: ページの縮小表示をクリックして 90° ずつ回す
struct RotateView: View {
    @Bindable var model: RotateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let file = model.file, let document = model.document {
                HStack {
                    Text(file.fileName).font(.headline).lineLimit(1).truncationMode(.middle)
                    Text("\(file.pageCount) ページ・\(FileSize.text(file.byteSize))").foregroundStyle(.secondary)
                    if file.isEncrypted { Badge(text: "制限あり") }
                    Spacer()
                    Button("閉じる") { model.close() }
                }
                HStack {
                    Button("すべて左に 90°") { model.rotateAll(by: -1) }
                    Button("すべて右に 90°") { model.rotateAll(by: 1) }
                    Button("元に戻す") { model.reset() }.disabled(!model.plan.hasChanges)
                    Spacer()
                    Text("クリックで右に 90°。右クリックで左回り・180°")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            PageThumbnailView(image: model.thumbnails.images[index],
                                              pageNumber: index + 1,
                                              quarterTurns: model.plan.quarterTurns[index],
                                              displayTurns: model.displayTurns[index])
                                .task { model.thumbnails.load(pageIndex: index, from: document) }
                                .onTapGesture { model.rotate(pageIndex: index, by: 1) }
                                .contextMenu {
                                    Button("右に 90°") { model.rotate(pageIndex: index, by: 1) }
                                    Button("左に 90°") { model.rotate(pageIndex: index, by: -1) }
                                    Button("180°") { model.rotate(pageIndex: index, by: 2) }
                                    Button("このページを元に戻す") { model.resetPage(index) }
                                }
                        }
                    }
                    .padding(4)
                }
                .id(file.id)

                OutputNameField(name: $model.outputName)
                HStack {
                    Button("回転して保存…") { Task { await model.save() } }
                        .keyboardShortcut("s")
                        .disabled(!model.canSave)
                    if !model.plan.hasChanges {
                        Text("回すページを選んでください").font(.caption).foregroundStyle(.secondary)
                    }
                    if model.isWorking { ProgressView().controlSize(.small) }
                }
            } else {
                DropZone(prompt: "回転する PDF をここにドロップ", allowsMultiple: false) { model.load($0) }
            }

            MessageList(messages: model.messages)
            if let outcome = model.outcome { OutcomeView(outcome: outcome) }
            if model.file == nil { Spacer(minLength: 0) }
        }
        .padding()
        .navigationTitle("回転")
        .dropDestination(for: URL.self) { urls, _ in
            model.load(urls)
            return true
        }
    }
}

#if DEBUG
#Preview("PDF あり") {
    RotateView(model: PreviewSamples.rotateModel())
        .frame(width: 720, height: 600)
}

#Preview("空") {
    RotateView(model: RotateModel())
        .frame(width: 720, height: 560)
}
#endif
