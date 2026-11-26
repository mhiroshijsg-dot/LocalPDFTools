import SwiftUI

/// 回転のシートの、ファイル 1 つ分（見出しとページの縮小表示）
struct FilePagesSection: View {
    let number: Int
    let file: WorkFile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.callout.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.secondary))
                Text(file.fileName).font(.headline).lineLimit(1).truncationMode(.middle)
                if let count = file.pageCount { Text("\(count) ページ").foregroundStyle(.secondary) }
                Spacer()
                if !file.isLocked {
                    Button {
                        file.resetRotation()
                    } label: {
                        Label("このファイルを元に戻す", systemImage: "arrow.uturn.backward")
                    }
                    .controlSize(.small)
                    .disabled(file.rotatedPageCount == 0)
                }
            }
            if file.isLocked {
                Label("開くのにパスワードが要るので、ページを表示できません（このファイルは回せません）。パスワードは実行中にだけ聞きます。",
                      systemImage: "lock.fill")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let document = file.document {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        PageThumbnailView(image: file.thumbnails.images[index],
                                          pageNumber: index + 1,
                                          quarterTurns: file.plan.quarterTurns[index],
                                          displayTurns: file.displayTurns[index])
                            .task { file.thumbnails.load(pageIndex: index, from: document) }
                            .onTapGesture { file.rotate(pageIndex: index, by: 1) }
                            .contextMenu {
                                Button("右に 90°", systemImage: "rotate.right") { file.rotate(pageIndex: index, by: 1) }
                                Button("左に 90°", systemImage: "rotate.left") { file.rotate(pageIndex: index, by: -1) }
                                Button("180°", systemImage: "arrow.triangle.2.circlepath") { file.rotate(pageIndex: index, by: 2) }
                                Divider()
                                Button("このページを元に戻す", systemImage: "arrow.uturn.backward") { file.resetPage(index) }
                            }
                    }
                }
            } else {
                ProgressView().controlSize(.small)
                    .task { _ = file.openDocument() }
            }
        }
    }
}
