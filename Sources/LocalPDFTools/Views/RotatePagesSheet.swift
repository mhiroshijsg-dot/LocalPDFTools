import PDFEngine
import SwiftUI

/// 回転のシート: 入れた全ファイルのページを、ファイルごとに区切って並べ、クリックで 90° ずつ回す
struct RotatePagesSheet: View {
    @Bindable var workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                OperationIcon(operation: .rotate, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ページを回す").font(.title3.weight(.semibold))
                    Text("クリックで右に 90°。右クリックで左回り・180°")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { workspace.files.forEach { $0.rotateAll(by: -1) } } label: {
                    Label("すべて左に 90°", systemImage: "rotate.left")
                }
                Button { workspace.files.forEach { $0.rotateAll(by: 1) } } label: {
                    Label("すべて右に 90°", systemImage: "rotate.right")
                }
                Button { workspace.files.forEach { $0.resetRotation() } } label: {
                    Label("すべて元に戻す", systemImage: "arrow.uturn.backward")
                }
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                        FilePagesSection(number: index + 1, file: file)
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            HStack {
                let pages = workspace.files.reduce(0) { $0 + $1.rotatedPageCount }
                Text(pages == 0 ? "回すページはまだありません" : "\(pages) ページを回す予定")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("完了") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(16)
        }
        .frame(minWidth: 780, minHeight: 560)
    }
}

#if DEBUG
#Preview {
    RotatePagesSheet(workspace: PreviewSamples.rotatingWorkspace())
}
#endif
