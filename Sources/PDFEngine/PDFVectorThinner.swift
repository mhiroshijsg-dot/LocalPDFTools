import Foundation

/// PDF の全ページ（と、ページの中の図 = Form XObject）の描画の命令に ContentStreamThinner をかける。
/// 書き換えた命令は、qpdf の `--update-from-json` で差し戻す（圧縮していない形で渡し、qpdf が圧縮して書く）。
struct PDFVectorThinner {
    let runner: QPDFRunner

    /// 描画の命令 1 つ分（部品の番号・PDF の中の大きさ・圧縮を解いた中身）
    private struct Stream {
        let ref: String
        let storedBytes: Int64
        let data: Data
    }

    /// 実行前に数える（書き換えない）
    func preview(_ url: URL, table: QPDFObjectTable) async throws -> VectorThinningReport {
        let streams = try await contentStreams(url, table: table)
        let classified = streams.map { ContentStreamThinner.classify($0.data) }
        let documentTicks = classified.reduce(into: Set<Double>()) { $0.formUnion(ContentStreamThinner.tickLengths($1.stats)) }
        var report = VectorThinningReport()
        for (stream, item) in zip(streams, classified) {
            // 圧縮を解いた中身で減る分を、PDF の中の圧縮後の大きさに直す
            let ratio = stream.data.isEmpty ? 0 : Double(stream.storedBytes) / Double(stream.data.count)
            for signature in ContentStreamThinner.removable(item.stats, grid: true, ticks: true,
                                                             documentTickLengths: documentTicks) {
                guard let stat = item.stats[signature] else { continue }
                if signature.isGrid {
                    report.gridLines += stat.count
                    report.gridBytes += Int64(Double(stat.bytes) * ratio)
                } else {
                    report.tickMarks += stat.count
                    report.tickBytes += Int64(Double(stat.bytes) * ratio)
                }
            }
            let simplified = ContentStreamThinner.simplifyCurves(item.text as String, tolerance: VectorThinning.tolerance)
            report.pointsBefore += simplified.before
            report.pointsAfter += simplified.after
            let shrink = item.text.length - (simplified.text as NSString).length
            report.curveBytes += Int64(Double(max(0, shrink)) * ratio)
        }
        return report
    }

    /// 書き換えた命令を作業用のフォルダに書き、qpdf の差し戻しの指定（"obj:N 0 R" → 中身）と、減らした数を返す
    func apply(_ url: URL, table: QPDFObjectTable, thinning: VectorThinning,
               workDirectory: URL) async throws -> (updates: [String: Any], report: VectorThinningReport) {
        let streams = try await contentStreams(url, table: table)
        let classified = streams.map { ContentStreamThinner.classify($0.data) }
        let documentTicks = classified.reduce(into: Set<Double>()) { $0.formUnion(ContentStreamThinner.tickLengths($1.stats)) }
        var updates: [String: Any] = [:]
        var report = VectorThinningReport()
        for (index, (stream, item)) in zip(streams, classified).enumerated() {
            try Task.checkCancellation()
            let removing = ContentStreamThinner.removable(item.stats, grid: thinning.removeMinorGrid,
                                                          ticks: thinning.removeMinorTicks, documentTickLengths: documentTicks)
            var (text, grid, ticks) = ContentStreamThinner.strip(item, removing: removing)
            report.gridLines += grid
            report.tickMarks += ticks
            if thinning.simplifyCurves {
                let simplified = ContentStreamThinner.simplifyCurves(text, tolerance: VectorThinning.tolerance)
                text = simplified.text
                report.pointsBefore += simplified.before
                report.pointsAfter += simplified.after
            }
            let newData = ContentStreamThinner.data(text)
            guard newData != stream.data, var dictionary = table.streamDictionary(stream.ref) else { continue }
            let file = workDirectory.appendingPathComponent("content-\(index).bin")
            try newData.write(to: file)
            dictionary["/Filter"] = nil
            dictionary["/DecodeParms"] = nil
            dictionary["/Length"] = nil
            updates["obj:" + stream.ref] = ["stream": ["dict": dictionary, "datafile": file.path]]
        }
        return (updates, report)
    }

    /// ページの命令と、そこから資源をたどって見つかる図（Form XObject）の命令（同じものは 1 回だけ）
    private func contentStreams(_ url: URL, table: QPDFObjectTable) async throws -> [Stream] {
        var refs: [String] = []
        var seen = Set<String>()
        func walk(_ resources: [String: Any]?, depth: Int) {
            guard depth <= 4 else { return }
            for (_, ref) in table.xObjects(in: resources).sorted(by: { $0.key < $1.key }) where !seen.contains(ref) {
                seen.insert(ref)
                guard let dictionary = table.streamDictionary(ref), (dictionary["/Subtype"] as? String) == "/Form" else { continue }
                refs.append(ref)
                walk(table.dictionary(dictionary["/Resources"]), depth: depth + 1)
            }
        }
        for pageRef in table.pageRefs {
            let contents = table.dictionary(pageRef)?["/Contents"]
            let list = (contents as? [Any]) ?? (table.resolve(contents) as? [Any]) ?? [contents as Any]
            for case let ref as String in list where QPDFObjectTable.isReference(ref) && !seen.contains(ref) {
                seen.insert(ref)
                refs.append(ref)
            }
            walk(table.pageResources(pageRef), depth: 0)
        }

        var streams: [Stream] = []
        for ref in refs {
            try Task.checkCancellation()
            let parts = ref.split(separator: " ")
            guard parts.count >= 2 else { continue }
            let output = try await runner.run(["--show-object=\(parts[0]),\(parts[1])", "--filtered-stream-data", url.path])
            // 圧縮を解けない命令（qpdf が扱えない形式）は触らない
            guard output.succeeded else { continue }
            let stored = Int64(table.number(table.streamDictionary(ref)?["/Length"]) ?? 0)
            streams.append(Stream(ref: ref, storedBytes: stored, data: output.standardOutputData))
        }
        return streams
    }
}
