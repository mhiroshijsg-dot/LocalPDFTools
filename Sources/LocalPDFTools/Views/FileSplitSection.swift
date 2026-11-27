import PDFEngine
import PDFKit
import SwiftUI

/// 分割のシートの、ファイル 1 つ分（見出しと、ページの縮小表示・ページの間の切れ目）
struct FileSplitSection: View {
    let number: Int
    let file: WorkFile
    @Bindable var workspace: Workspace

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
            }
            if file.isLocked {
                Label("開くのにパスワードが要るので、ページを表示できません。1 ページずつ・N ページごとなら、解除した後に分けます。",
                      systemImage: "lock.fill")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let document = file.document {
                pages(of: document.pageCount, document: document)
            } else {
                ProgressView().controlSize(.small)
                    .task { _ = file.openDocument() }
            }
        }
    }

    @ViewBuilder
    private func pages(of count: Int, document: PDFDocument) -> some View {
        switch workspace.split.ranges(pageCount: count) {
        case .failure(let error):
            Text(error.localizedDescription).foregroundStyle(.red)
            grid(count: count, document: document, ranges: [])
        case .success(let ranges):
            grid(count: count, document: document, ranges: ranges)
        }
    }

    private func grid(count: Int, document: PDFDocument, ranges: [ClosedRange<Int>]) -> some View {
        // 切れ目を選べるのは PDF が 1 つで、範囲を書く分け方でないとき
        let canCut = workspace.files.count == 1 && workspace.split.mode != .ranges
        let turns = workspace.selected.contains(.rotate) ? file.plan.quarterTurns : []
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 0)], spacing: 14) {
            ForEach(0..<count, id: \.self) { index in
                let page = index + 1
                let pieces = ranges.indices.filter { ranges[$0].contains(page) }.map { $0 + 1 }
                HStack(spacing: 0) {
                    SplitPageCell(image: file.thumbnails.images[index], pageNumber: page, pieces: pieces,
                                  quarterTurns: turns.indices.contains(index) ? turns[index] : 0)
                        .task { file.thumbnails.load(pageIndex: index, from: document) }
                    CutGapButton(isCut: page < count && ranges.contains { $0.upperBound == page },
                                 isEnabled: canCut && page < count) {
                        workspace.split.toggleCut(after: page, pageCount: count)
                    }
                    .opacity(page < count ? 1 : 0)
                }
            }
        }
    }
}
