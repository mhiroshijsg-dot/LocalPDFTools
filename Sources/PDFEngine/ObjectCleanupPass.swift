/// 圧縮の最後に、すべての部品に 2 つのことを重ねる（どちらも見た目は変わらない）。
/// - 重複の部品への参照を、残す方へ付け替える（DuplicateObjectFinder の結果）
/// - 要らないデータを外す（ExtraDataStripper）
/// それまでの段（図・線・画像）で書き換えた部品にも、同じことを重ねる。書き換えたものだけを `--update-from-json` に渡す。
/// 流れ（stream）は辞書だけを渡せば、データはそのまま残る（qpdf 12.4 で確認）。
struct ObjectCleanupPass {
    let table: QPDFObjectTable
    let duplicates: [String: String]

    struct Output {
        var updates: [String: Any]
        /// 外した要らないデータの数（重複としてまとめた部品の中のものは数えない）
        var removedExtras = 0
    }

    func apply(to updates: [String: Any]) -> Output {
        var output = Output(updates: updates)
        let rewriter = ReferenceRewriter(map: duplicates)
        let refs = Set(table.objects.keys).union(updates.keys.compactMap { $0.hasPrefix("obj:") ? String($0.dropFirst(4)) : nil })
        for ref in refs {
            let key = "obj:" + ref
            let wasUpdated = updates[key] != nil
            guard let object = (updates[key] as? [String: Any]) ?? table.objects[ref] else { continue }
            var changed = false
            var result = object
            if var stream = object["stream"] as? [String: Any], let dictionary = stream["dict"] as? [String: Any] {
                let cleaned = clean(dictionary, rewriter: rewriter)
                if cleaned.changed {
                    stream["dict"] = cleaned.dictionary
                    result["stream"] = stream
                    changed = true
                }
                if duplicates[ref] == nil { output.removedExtras += cleaned.removed }
            } else if let value = object["value"] {
                if let dictionary = value as? [String: Any] {
                    let cleaned = clean(dictionary, rewriter: rewriter)
                    if cleaned.changed {
                        result["value"] = cleaned.dictionary
                        changed = true
                    }
                    if duplicates[ref] == nil { output.removedExtras += cleaned.removed }
                } else if rewriter.touches(value) {
                    result["value"] = rewriter.rewrite(value)
                    changed = true
                }
            }
            if changed || wasUpdated { output.updates[key] = result }
        }
        return output
    }

    private func clean(_ dictionary: [String: Any], rewriter: ReferenceRewriter)
        -> (dictionary: [String: Any], changed: Bool, removed: Int) {
        let stripped = ExtraDataStripper.strip(dictionary)
        let touches = rewriter.touches(stripped.dictionary)
        let rewritten = touches ? rewriter.rewrite(stripped.dictionary) as? [String: Any] ?? stripped.dictionary : stripped.dictionary
        return (rewritten, stripped.removed > 0 || touches, stripped.removed)
    }
}
