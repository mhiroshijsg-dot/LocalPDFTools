import PDFEngine
import SwiftUI

/// 暗号化の解除の画面: PDF の暗号化の状態を見せ、制限（とパスワード）を外して保存する
struct EncryptionView: View {
    @Bindable var model: EncryptionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自分が権利を持つ書類（自分の成績証明書やスコアレポートなど）の制限を外すための機能です。他人の書類や、制限を外すことが許されていない書類には使わないでください。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let url = model.fileURL, let report = model.report {
                HStack {
                    Image(systemName: "doc").foregroundStyle(.secondary)
                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Text(FileSize.text(model.fileBytes)).monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Button("別の PDF を開く…") {
                        let urls = FilePanels().choosePDFs(allowsMultiple: false)
                        if !urls.isEmpty { Task { await model.load(urls) } }
                    }
                    Button("閉じる") { model.close() }
                }
                EncryptionStatusView(report: report)

                if report.status != .notEncrypted {
                    if model.needsPassword {
                        HStack {
                            Text("パスワード")
                            SecureField("開くときのパスワード", text: $model.password)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 260)
                                .onSubmit { if model.canSave { Task { await model.decryptAndSave() } } }
                        }
                        Text("パスワードはこの Mac の中で qpdf に渡すだけで、保存も送信もしません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    OutputNameField(name: $model.outputName)
                    HStack {
                        Button(model.needsPassword ? "パスワードを外して保存…" : "制限を外して保存…") {
                            Task { await model.decryptAndSave() }
                        }
                        .keyboardShortcut("s")
                        .disabled(!model.canSave)
                        if model.isWorking { ProgressView().controlSize(.small) }
                    }
                }
            } else {
                DropZone(prompt: "暗号化を調べる PDF をここにドロップ", allowsMultiple: false) { urls in
                    Task { await model.load(urls) }
                }
                if model.isWorking { ProgressView().controlSize(.small) }
            }

            MessageList(messages: model.messages)
            if let outcome = model.outcome { OutcomeView(outcome: outcome) }
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("暗号化の解除")
        .dropDestination(for: URL.self) { urls, _ in
            Task { await model.load(urls) }
            return true
        }
    }
}

#if DEBUG
#Preview("開けるが制限付き") {
    EncryptionView(model: PreviewSamples.encryptionModel(.restricted))
        .frame(width: 720, height: 560)
}

#Preview("パスワードが要る") {
    EncryptionView(model: PreviewSamples.encryptionModel(.passwordRequired))
        .frame(width: 720, height: 560)
}

#Preview("空") {
    EncryptionView(model: EncryptionModel())
        .frame(width: 720, height: 560)
}
#endif
