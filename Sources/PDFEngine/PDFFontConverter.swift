import Foundation

/// 圧縮の段の 1 つ: PDF の中の Type1 フォント（/FontFile）を CFF（/FontFile3 /Type1C）に作り直す（いつも行う）。
/// フォントの説明（FontDescriptor）の /FontFile を外して /FontFile3 に新しい部品を指させる。
/// 元の /FontFile はどこからも使われなくなり、qpdf が書き出すときに捨てる。
/// 作り直せなかったフォント・作り直しても小さくならないフォントは、元のまま残す。
struct PDFFontConverter {
    let runner: QPDFRunner

    struct Output {
        var updates: [String: Any] = [:]
        var converted = 0
    }

    /// duplicates: 重複の対応（同じフォントは残す方だけを作り直す）。nextObjectID: 新しい部品に使い始める番号
    func apply(_ input: URL, table: QPDFObjectTable, duplicates: [String: String], nextObjectID: Int,
               workDirectory: URL) async throws -> Output {
        // フォントの説明 → 指している Type1 フォント（重複は残す方に読み替える）
        var descriptors: [(ref: String, dictionary: [String: Any], fontFile: String)] = []
        for (ref, object) in table.objects {
            guard let dictionary = object["value"] as? [String: Any],
                  (dictionary["/Type"] as? String) == "/FontDescriptor",
                  let fontFile = dictionary["/FontFile"] as? String, QPDFObjectTable.isReference(fontFile) else { continue }
            descriptors.append((ref, dictionary, duplicates[fontFile] ?? fontFile))
        }
        let fontFiles = Array(Set(descriptors.map(\.fontFile)))
        guard !fontFiles.isEmpty else { return Output() }

        let prefix = workDirectory.appendingPathComponent("font").path
        let arguments = ["--json", "--json-key=qpdf", "--json-stream-data=file", "--json-stream-prefix=" + prefix,
                         "--decode-level=generalized"]
            + fontFiles.map { "--json-object=" + DuplicateObjectFinder.objectArgument($0) } + [input.path]
        let result = try await runner.runChecked(arguments)
        guard let root = try? JSONSerialization.jsonObject(with: result.standardOutputData) as? [String: Any],
              let qpdf = root["qpdf"] as? [Any], qpdf.count >= 2, let entries = qpdf[1] as? [String: Any] else { return Output() }

        var output = Output()
        var nextID = nextObjectID
        var converted: [String: String] = [:] // 元のフォント → 新しい CFF の部品
        for fontFile in fontFiles.sorted(by: DuplicateObjectFinder.objectOrder) {
            try Task.checkCancellation()
            guard let stream = (entries["obj:" + fontFile] as? [String: Any])?["stream"] as? [String: Any],
                  let file = stream["datafile"] as? String,
                  let data = FileManager.default.contents(atPath: file) else { continue }
            // 長さはフォントの部品の辞書から（JSON の辞書は、圧縮を解いた形に合わせて書き換わっていることがあるので元の一覧も見る）
            let original = table.streamDictionary(fontFile) ?? [:]
            let dictionary = stream["dict"] as? [String: Any] ?? original
            let length1 = Int(table.number(dictionary["/Length1"] ?? original["/Length1"]) ?? 0)
            let length2 = Int(table.number(dictionary["/Length2"] ?? original["/Length2"]) ?? 0)
            guard let cff = Type1ToCFFConverter().convert([UInt8](data), length1: length1, length2: length2),
                  cff.count < data.count else { continue }
            let path = workDirectory.appendingPathComponent("font-\(nextID).cff")
            try Data(cff).write(to: path)
            let ref = "\(nextID) 0 R"
            output.updates["obj:" + ref] = ["stream": ["dict": ["/Subtype": "/Type1C"], "datafile": path.path]]
            converted[fontFile] = ref
            nextID += 1
            output.converted += 1
        }
        for descriptor in descriptors {
            guard let cff = converted[descriptor.fontFile] else { continue }
            var dictionary = descriptor.dictionary
            dictionary["/FontFile"] = nil
            dictionary["/FontFile3"] = cff
            output.updates["obj:" + descriptor.ref] = ["value": dictionary]
        }
        return output
    }
}
