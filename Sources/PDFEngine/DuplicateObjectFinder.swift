import CryptoKit
import Foundation

/// 中身がまったく同じ部品を探す（圧縮のときにいつも行う）。
/// - データを持つ部品（画像・フォント・図・色の設定など）: 辞書（長さを除く）と、圧縮を解いたデータがすべて同じもの
/// - データを持たない小さな部品（フォントの辞書・字幅の表・文字の割り当てなど）: 中身がすべて同じもの
/// 結合した PDF や、matplotlib の図をたくさん入れた PDF には、同じフォントや字形が図・ファイルの数だけ入っていて、
/// 1 つにまとめれば見た目を変えずに減らせる。
/// 返すのは「重複の番号 → 残す方の番号」の対応。参照を残す方へ付け替えると、重複はどこからも使われなくなり、qpdf が書き出すときに捨てる。
/// MEMO(2026-11-26・by claude): データを持つ部品は、まず部品の一覧だけで「長さと辞書が同じ」ものを候補にし、
/// 候補のデータだけを qpdf で取り出して比べる（全部を取り出さない）。
/// MEMO(2026-11-27・by claude): 村田さんの指示（案 B）で、データを持たない部品もまとめるようにした。
/// ページ・注釈・しおり・文書の構造・フォームの欄・レイヤーなど、1 つずつ別でなければならない部品はまとめない（`isMergeable`）。
struct DuplicateObjectFinder {
    let runner: QPDFRunner

    func find(_ input: URL, table: QPDFObjectTable, workDirectory: URL) async throws -> [String: String] {
        let digests = try await streamDigests(input, table: table, workDirectory: workDirectory)
        try Task.checkCancellation()

        // まとめる対象: データを持つ部品は指紋が取れたもの、データを持たない部品は辞書か配列で、まとめてよいもの
        var targets: [(ref: String, value: Any, digest: String?)] = []
        for (ref, object) in table.objects {
            if object["stream"] != nil {
                if let digest = digests[ref]?.digest, let dictionary = digests[ref]?.dictionary {
                    targets.append((ref, dictionary, digest))
                }
            } else if let value = object["value"], Self.isMergeable(value) {
                targets.append((ref, value, nil))
            }
        }
        targets.sort { Self.objectOrder($0.ref, $1.ref) }

        // 中身（参照はまとめた先に読み替える）が同じものをまとめる。番号の小さい方を残す。
        // 1 回まとめると、それを指していた部品同士も同じになることがある（同じ字形を指す 2 つのフォントなど）ので、変わらなくなるまで繰り返す
        var duplicates: [String: String] = [:]
        for _ in 0..<12 {
            try Task.checkCancellation()
            let rewriter = ReferenceRewriter(map: duplicates)
            var keeper: [String: String] = [:]
            var found = false
            for target in targets where duplicates[target.ref] == nil {
                var value = rewriter.rewrite(target.value)
                if var dictionary = value as? [String: Any], target.digest != nil {
                    dictionary["/Length"] = nil
                    value = dictionary
                }
                let key = (target.digest.map { "s#" + $0 } ?? "v#") + Self.canonical(value)
                if let kept = keeper[key] {
                    duplicates[target.ref] = kept
                    found = true
                } else {
                    keeper[key] = target.ref
                }
            }
            if !found { break }
        }
        // 残す方が後の回で別の部品にまとめられたときは、最後に残る部品を指すようにする
        return duplicates.mapValues { kept in
            var target = kept
            var depth = 0
            while let next = duplicates[target], depth < 16 {
                target = next
                depth += 1
            }
            return target
        }
    }

    /// データを持つ部品のうち、ほかに同じ長さ・同じ形の辞書のものがある部品の、辞書と指紋（SHA-256）
    private func streamDigests(_ input: URL, table: QPDFObjectTable, workDirectory: URL) async throws
        -> [String: (dictionary: [String: Any], digest: String)] {
        var groups: [String: [String]] = [:]
        for (ref, object) in table.objects {
            guard let dictionary = (object["stream"] as? [String: Any])?["dict"] as? [String: Any],
                  let length = table.number(dictionary["/Length"]), length > 0 else { continue }
            var key = dictionary
            key["/Length"] = nil
            groups[Self.canonical(Self.maskingReferences(key)) + "#\(Int(length))", default: []].append(ref)
        }
        let candidates = groups.values.filter { $0.count > 1 }.flatMap { $0 }
        guard !candidates.isEmpty else { return [:] }

        let prefix = workDirectory.appendingPathComponent("duplicate").path
        let arguments = ["--json", "--json-key=qpdf", "--json-stream-data=file", "--json-stream-prefix=" + prefix,
                         "--decode-level=generalized"]
            + candidates.map { "--json-object=" + Self.objectArgument($0) }
            + [input.path]
        let output = try await runner.runChecked(arguments)
        guard let root = try? JSONSerialization.jsonObject(with: output.standardOutputData) as? [String: Any],
              let qpdf = root["qpdf"] as? [Any], qpdf.count >= 2, let entries = qpdf[1] as? [String: Any] else { return [:] }
        var result: [String: (dictionary: [String: Any], digest: String)] = [:]
        for ref in candidates {
            guard let stream = (entries["obj:" + ref] as? [String: Any])?["stream"] as? [String: Any],
                  let dictionary = stream["dict"] as? [String: Any],
                  let file = stream["datafile"] as? String,
                  let data = FileManager.default.contents(atPath: file) else { continue }
            result[ref] = (dictionary, SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
            try? FileManager.default.removeItem(atPath: file)
        }
        return result
    }

    /// データを持たない部品のうち、まとめてよいもの。
    /// 辞書と配列だけ（数や名前だけの部品はまとめても減らない）。1 つずつ別でなければならない部品は除く
    static func isMergeable(_ value: Any) -> Bool {
        if value is [Any] { return true }
        guard let dictionary = value as? [String: Any] else { return false }
        let excludedTypes: Set<String> = ["/Page", "/Pages", "/Catalog", "/Annot", "/OCG", "/OCMD", "/Outlines",
                                          "/StructTreeRoot", "/StructElem", "/MCR", "/OBJR", "/Sig", "/DocTimeStamp",
                                          "/Filespec", "/EmbeddedFile", "/Thread", "/Bead"]
        if let type = dictionary["/Type"] as? String, excludedTypes.contains(type) { return false }
        // 注釈（/Rect）・ページや親を指すもの（/P・/Parent・/Kids）・フォームの欄（/FT・/T）・しおりのつながり（/First・/Next・/Prev）
        let excludedKeys = ["/Rect", "/P", "/Parent", "/Kids", "/FT", "/T", "/First", "/Next", "/Prev", "/Last"]
        return !excludedKeys.contains { dictionary[$0] != nil }
    }

    /// 辞書や配列を、比べられる 1 つの文字列にする（キーの順をそろえる）
    static func canonical(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ["v": value], options: [.sortedKeys]) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// 参照（"5 0 R"）をすべて "R" に置き換える（候補を広めに取るため）
    static func maskingReferences(_ value: Any) -> Any {
        switch value {
        case let text as String: return QPDFObjectTable.isReference(text) ? "R" : text
        case let array as [Any]: return array.map(maskingReferences)
        case let dictionary as [String: Any]: return dictionary.mapValues(maskingReferences)
        default: return value
        }
    }

    /// qpdf の --json-object に渡す形（"12 0 R" → "12,0"）
    static func objectArgument(_ ref: String) -> String {
        let parts = ref.split(separator: " ")
        return parts.count >= 2 ? "\(parts[0]),\(parts[1])" : ref
    }

    /// 部品の番号の小さい順
    static func objectOrder(_ lhs: String, _ rhs: String) -> Bool {
        let left = Int(lhs.split(separator: " ").first ?? "") ?? 0
        let right = Int(rhs.split(separator: " ").first ?? "") ?? 0
        return left < right
    }
}
