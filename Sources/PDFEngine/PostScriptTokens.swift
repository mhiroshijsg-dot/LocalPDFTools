/// 平文の部分を空白・記号で区切った語の並び（括弧の中の文字列は 1 語にまとめて読み飛ばす）
struct PostScriptTokens {
    let items: [String]

    init(_ text: String) {
        var items: [String] = []
        var current = ""
        var depth = 0
        var inComment = false
        for character in text {
            if inComment {
                if character == "\n" || character == "\r" { inComment = false }
                continue
            }
            if depth > 0 {
                if character == "(" { depth += 1 } else if character == ")" { depth -= 1 }
                if depth == 0 { items.append("(string)") }
                continue
            }
            switch character {
            case "%":
                if !current.isEmpty { items.append(current); current = "" }
                inComment = true
            case "(":
                if !current.isEmpty { items.append(current); current = "" }
                depth = 1
            case " ", "\n", "\r", "\t":
                if !current.isEmpty { items.append(current); current = "" }
            case "[", "]", "{", "}":
                if !current.isEmpty { items.append(current); current = "" }
                items.append(String(character))
            case "/":
                if !current.isEmpty { items.append(current) }
                current = "/"
            default:
                current.append(character)
            }
        }
        if !current.isEmpty { items.append(current) }
        self.items = items
    }

    func index(of key: String) -> Int? { items.firstIndex(of: key) }

    func value(after key: String) -> String? {
        guard let index = index(of: key) else { return nil }
        return items[safe: index + 1]
    }

    /// "[1 2 3]" や "{1 2 3}" の数
    func numbers(after key: String) -> [Double]? {
        guard let index = index(of: key), let open = items[safe: index + 1], open == "[" || open == "{" else { return nil }
        var values: [Double] = []
        var position = index + 2
        while let token = items[safe: position], token != "]" && token != "}" {
            guard let value = Double(token) else { return nil }
            values.append(value)
            position += 1
        }
        return values
    }
}
