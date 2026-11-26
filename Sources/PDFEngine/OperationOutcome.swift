import Foundation

/// 保存が終わったときの結果（「元 4.9 MB → 新 1.1 MB」の表示に使う）
public struct OperationOutcome: Sendable {
    public let destination: URL
    /// 入力の合計の大きさ（結合なら全ファイルの合計）
    public let inputBytes: Int64
    public let outputBytes: Int64
    /// qpdf が出した警告（成功はしている）
    public let warnings: [String]
    /// 圧縮したときだけ: 作り直した画像の数など
    public let compression: CompressionResult?

    public init(destination: URL, inputBytes: Int64, outputBytes: Int64, warnings: [String],
                compression: CompressionResult? = nil) {
        self.destination = destination
        self.inputBytes = inputBytes
        self.outputBytes = outputBytes
        self.warnings = warnings
        self.compression = compression
    }

    /// 圧縮の結果を付けた写し
    func with(compression: CompressionResult?) -> OperationOutcome {
        OperationOutcome(destination: destination, inputBytes: inputBytes, outputBytes: outputBytes,
                         warnings: warnings, compression: compression)
    }
}
