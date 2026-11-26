import Foundation

/// `qpdf --json --json-key=qpdf --json-key=pages --json-stream-data=none` の中身（PDF の全部品の一覧。データ本体は含まない）。
/// 部品は "12 0 R" のような番号で引く。値は qpdf の JSON（version 2）の形のまま:
/// 名前は "/Width"、参照は "5 0 R"、数・真偽・配列・辞書はそのまま。
struct QPDFObjectTable {
    /// "12 0 R" → {"value": …} または {"stream": {"dict": …}}
    let objects: [String: [String: Any]]
    /// ページの部品の番号（ページ順）
    let pageRefs: [String]

    static func load(_ url: URL, runner: QPDFRunner) async throws -> QPDFObjectTable {
        let output = try await runner.runChecked(["--json", "--json-key=qpdf", "--json-key=pages",
                                                  "--json-stream-data=none", url.path])
        guard let root = try? JSONSerialization.jsonObject(with: output.standardOutputData) as? [String: Any],
              let qpdf = root["qpdf"] as? [Any], qpdf.count >= 2,
              let entries = qpdf[1] as? [String: Any],
              let pages = root["pages"] as? [[String: Any]] else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        var objects: [String: [String: Any]] = [:]
        for (key, value) in entries where key.hasPrefix("obj:") {
            if let value = value as? [String: Any] {
                objects[String(key.dropFirst(4))] = value
            }
        }
        return QPDFObjectTable(objects: objects, pageRefs: pages.compactMap { $0["object"] as? String })
    }

    /// 参照（"5 0 R"）ならたどった先の値、そうでなければそのまま。流れ（stream）なら辞書を返す
    func resolve(_ value: Any?) -> Any? {
        guard let ref = value as? String, Self.isReference(ref) else { return value }
        guard let object = objects[ref] else { return nil }
        if let stream = object["stream"] as? [String: Any] { return stream["dict"] }
        return object["value"]
    }

    func dictionary(_ value: Any?) -> [String: Any]? {
        resolve(value) as? [String: Any]
    }

    /// 流れ（stream）の辞書。流れでなければ nil
    func streamDictionary(_ ref: String) -> [String: Any]? {
        (objects[ref]?["stream"] as? [String: Any])?["dict"] as? [String: Any]
    }

    func number(_ value: Any?) -> Double? {
        (resolve(value) as? NSNumber)?.doubleValue
    }

    /// ページの /Resources（無ければ親の /Pages から受け継ぐ）
    func pageResources(_ pageRef: String) -> [String: Any]? {
        var node = dictionary(pageRef)
        var depth = 0
        while let current = node, depth < 32 {
            if let resources = dictionary(current["/Resources"]) { return resources }
            node = dictionary(current["/Parent"])
            depth += 1
        }
        return nil
    }

    /// 資源（/Resources）の中の /XObject: 名前（"/Im1"）→ 部品の番号
    func xObjects(in resources: [String: Any]?) -> [String: String] {
        guard let xObjects = dictionary(resources?["/XObject"]) else { return [:] }
        var result: [String: String] = [:]
        for (name, value) in xObjects {
            if let ref = value as? String, Self.isReference(ref) { result[name] = ref }
        }
        return result
    }

    static func isReference(_ text: String) -> Bool {
        text.hasSuffix(" R") && text.first?.isNumber == true
    }
}
