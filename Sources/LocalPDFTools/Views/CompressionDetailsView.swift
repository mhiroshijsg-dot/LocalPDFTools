import PDFEngine
import SwiftUI

/// 圧縮のカードの中身: やり方の選択・内訳・目安・目標の大きさ・試算
struct CompressionDetailsView: View {
    @Bindable var workspace: Workspace
    /// 提出先の大きさの上限（MB。0 は無し）。アプリを閉じても覚えておく
    @AppStorage("targetSizeMB") private var targetMB = 0.0

    private var model: CompressionModel { workspace.compression }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            choices
            Divider()
            lineThinning
            Divider()
            FigureRasterizationSection(workspace: workspace)
            Divider()
            breakdown
            Divider()
            estimate
            trial
            notes
        }
    }

    // MARK: やり方

    private var choices: some View {
        @Bindable var model = workspace.compression
        return VStack(alignment: .leading, spacing: 6) {
            Toggle("構造の圧縮（見た目は変わらない）", isOn: $model.settings.structural)
                .toggleStyle(.checkbox)
                .help("小さな部品をまとめて圧縮し、データの圧縮をし直します。画像や文字は一切変わりません")
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("解像度").foregroundStyle(.secondary)
                    Picker("解像度", selection: $model.settings.targetDPI) {
                        Text("変えない").tag(Int?.none)
                        ForEach(CompressionSettings.dpiChoices, id: \.self) { Text("\($0) dpi").tag(Int?.some($0)) }
                    }
                    .labelsHidden()
                    .help("選んだ dpi より細かい画像だけを縮めます。それより粗い画像には触りません")
                }
                GridRow {
                    Text("JPEG の画質").foregroundStyle(.secondary)
                    Picker("JPEG の画質", selection: $model.settings.jpegQuality) {
                        Text("変えない").tag(JPEGQuality?.none)
                        ForEach(JPEGQuality.allCases, id: \.self) { Text($0.title).tag(JPEGQuality?.some($0)) }
                    }
                    .labelsHidden()
                    .help("もともと JPEG の画像（写真・カラーのスキャン）だけに効きます。解像度を下げた画像は、ここが「変えない」なら「高」で保存します")
                }
            }
        }
    }

    // MARK: 図の線を減らす（make_compact_pdf.py の移植）

    private var lineThinning: some View {
        @Bindable var model = workspace.compression
        let reports = workspace.files.compactMap(\.thinningReport)
        let total = reports.reduce(VectorThinningReport(), +)
        let counted = !reports.isEmpty
        return VStack(alignment: .leading, spacing: 5) {
            Text("図の線を減らす").fontWeight(.medium)
            Text("matplotlib などで作ったグラフ向け。他の PDF にはほとんど当てはまりません。")
                .font(.caption).foregroundStyle(.secondary)
            thinningToggle("補助グリッド線を消す", isOn: $model.settings.vector.removeMinorGrid,
                           count: counted ? "\(total.gridLines) 本" : nil, changesLook: true,
                           help: "同じ形の破線が 20 本以上繰り返すものを消します（数本の参照線は残します）")
            thinningToggle("補助目盛を消す", isOn: $model.settings.vector.removeMinorTicks,
                           count: counted ? "\(total.tickMarks) 本" : nil, changesLook: true,
                           help: "文書の中で一番短い目盛で、同じ形が 20 本以上繰り返すものを消します（主目盛は残します）")
            thinningToggle("曲線の点を間引く", isOn: $model.settings.vector.simplifyCurves,
                           count: counted ? "\(total.pointsBefore) → \(total.pointsAfter) 点" : nil, changesLook: false,
                           help: "折れ線の点を、元の線からのずれが 0.1 ポイント以内に収まるように減らします。見た目はほぼ変わりません")
            if model.isCountingLines {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("線を数えています…").foregroundStyle(.secondary)
                }
            } else if counted && total.gridLines + total.tickMarks == 0 && total.pointsBefore == total.pointsAfter {
                Text("減らせる線は見つかりませんでした").foregroundStyle(.secondary)
            }
        }
        // 初めてどれかをオンにしたときに数える（数えるのは描画の命令を読むだけ）
        .task(id: model.settings.vector.isActive) {
            if model.settings.vector.isActive { await model.countLines(workspace.files) }
        }
    }

    private func thinningToggle(_ title: String, isOn: Binding<Bool>, count: String?, changesLook: Bool,
                                help: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Toggle(title, isOn: isOn).toggleStyle(.checkbox)
                if let count { Text(count).monospacedDigit().foregroundStyle(.secondary) }
            }
            if changesLook && isOn.wrappedValue {
                Label("見た目が変わります", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                    .padding(.leading, 20)
            }
        }
        .help(help)
    }

    // MARK: 内訳

    @ViewBuilder
    private var breakdown: some View {
        let reports = workspace.files.compactMap(\.contentReport)
        if model.isAnalyzing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("中身を調べています…").foregroundStyle(.secondary)
            }
        } else if reports.isEmpty {
            Text(workspace.files.isEmpty ? "PDF を入れると、大きさの内訳を出します" : "内訳を出せる PDF がありません")
                .foregroundStyle(.secondary)
        } else {
            let images = reports.flatMap(\.images)
            let imageBytes = reports.reduce(0) { $0 + $1.imageBytes }
            let fontBytes = reports.reduce(0) { $0 + $1.fontBytes }
            let otherBytes = reports.reduce(0) { $0 + $1.otherBytes }
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                row("画像", "\(FileSize.text(imageBytes))（\(images.count) 個）")
                row("フォント", FileSize.text(fontBytes))
                row("その他", FileSize.text(otherBytes))
            }
            .monospacedDigit()
            let supported = images.filter(\.isSupported)
            if let dpi = model.settings.targetDPI {
                let shrinking = reports.reduce(0) { $0 + $1.resampledCount(targetDPI: dpi) }
                Text("縮める画像: \(supported.count) 個中 \(shrinking) 個（\(dpi) dpi より細かいもの）")
                    .foregroundStyle(shrinking == 0 ? Color.secondary : Color.green)
            }
            let skipped = images.count - supported.count
            if skipped > 0 {
                Label("触らない画像 \(skipped) 個", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .help(unsupportedHelp(reports))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func unsupportedHelp(_ reports: [PDFContentReport]) -> String {
        var counts: [String: Int] = [:]
        for report in reports {
            for (reason, count) in report.unsupportedSummary { counts[reason, default: 0] += count }
        }
        return "そのまま残す画像:\n" + counts.sorted { $0.key < $1.key }.map { "・\($0.key): \($0.value) 個" }.joined(separator: "\n")
    }

    // MARK: 目安と目標

    private var targetBytes: Int64? {
        targetMB > 0 ? Int64(targetMB * 1_000_000) : nil
    }

    @ViewBuilder
    private var estimate: some View {
        let analyzed = workspace.files.filter { $0.contentReport != nil }
        if !analyzed.isEmpty {
            let before = analyzed.reduce(0) { $0 + ($1.contentReport?.totalBytes ?? 0) }
            let after = analyzed.reduce(0) { $0 + (model.expectedBytes($1)?.bytes ?? 0) }
            let isTrial = model.trialSizes != nil
            let separate = !workspace.merges && workspace.files.count > 1
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text(isTrial ? "試算" : "目安").foregroundStyle(.secondary)
                    Text("\(FileSize.text(before)) → \(isTrial ? "" : "約 ")\(FileSize.text(after))\(separate ? "（合計）" : "")")
                        .monospacedDigit()
                        .fontWeight(.semibold)
                        .foregroundStyle(separate ? Color.primary : color(for: after))
                }
                GridRow {
                    Text("目標").foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("なし", value: $targetMB, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text(separate ? "MB 以下（1 ファイルごと）" : "MB 以下").foregroundStyle(.secondary)
                    }
                    .help("提出先の大きさの上限。入れると、超えそうかを色で示します（0 は無し）")
                }
            }
            if separate, let target = targetBytes {
                let over = analyzed.filter { (model.expectedBytes($0)?.bytes ?? 0) > target }
                Text(over.isEmpty ? "どのファイルも目標以下の見込みです" : "目標を超えそうなファイル: \(over.map(\.fileName).joined(separator: "、"))")
                    .foregroundStyle(over.isEmpty ? Color.green : Color.red)
            }
            if !isTrial {
                Text("目安は式による見積もりで、実際とずれます。正確な数字は「試算する」で出します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func color(for bytes: Int64) -> Color {
        guard let target = targetBytes else { return .primary }
        return bytes <= target ? .green : .red
    }

    // MARK: 試算

    @ViewBuilder
    private var trial: some View {
        if let progress = model.trialProgress {
            HStack(spacing: 8) {
                ProgressView(value: progress).frame(maxWidth: 120)
                Button("中止") { model.cancelTrial() }.controlSize(.small)
            }
        } else if workspace.files.contains(where: { !$0.isLocked }) {
            Button {
                model.startTrial(workspace.files)
            } label: {
                Label("試算する", systemImage: "gauge.with.dots.needle.33percent")
            }
            .help("入れた PDF を実際に圧縮して大きさを測ります（作った PDF はすぐ消します）")
        }
        if let error = model.trialError {
            Text(error).foregroundStyle(.red).textSelection(.enabled)
        }
    }

    // MARK: 注意

    @ViewBuilder
    private var notes: some View {
        if workspace.files.contains(where: \.isLocked) {
            Text("パスワードが要る PDF は、解除するまで中を見られないので、内訳・目安・試算に入りません（圧縮そのものは行います）。")
                .font(.caption).foregroundStyle(.secondary)
        }
        let failed = workspace.files.filter { $0.analysisError != nil }
        if !failed.isEmpty {
            Text("中身を調べられなかった PDF: " + failed.map(\.fileName).joined(separator: "、"))
                .font(.caption).foregroundStyle(.red)
                .help(failed.compactMap(\.analysisError).joined(separator: "\n"))
        }
    }
}
