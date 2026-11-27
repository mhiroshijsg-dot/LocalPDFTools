import PDFEngine
import SwiftUI

/// 左側: 入れた PDF の並び（上から順・ドラッグで並べ替え）。
/// 「追加」と「すべて外す」は窓の上のツールバーにある（WorkspaceView）
struct FileListView: View {
    @Bindable var workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if workspace.files.isEmpty {
                DropZone(allowsMultiple: true) { urls in
                    Task { await workspace.add(urls) }
                }
                .padding(20)
            } else {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                List {
                    ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                        FileRowView(number: index + 1, file: file) { workspace.remove(file) }
                    }
                    .onMove { workspace.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .disabled(workspace.isWorking)
        .dropDestination(for: URL.self) { urls, _ in
            Task { await workspace.add(urls) }
            return true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("ファイル").font(.title3.weight(.semibold))
            Text("上から順・ドラッグで並べ替え").font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(summary).font(.callout).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        let pages = workspace.totalPages.map { String(localized: "\($0) ページ") } ?? String(localized: "ページ数は一部不明")
        return String(localized: "\(workspace.files.count) ファイル") + " · \(pages) · \(FileSize.text(workspace.totalBytes))"
    }
}
