/// 続けて行える操作 1 つ分。rawValue は設定（順番）を覚えるときの名前
public enum PipelineStep: String, CaseIterable, Sendable {
    /// 暗号化の解除。常に最初に行う（後の操作がパスワードを引数で渡さずに済むように）
    case decrypt
    case rotate
    case merge
    case compress
}
