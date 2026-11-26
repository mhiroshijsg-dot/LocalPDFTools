import Foundation

/// 続けて処理する PDF 1 つ分の指定
public struct PipelineFile: Sendable {
    public let url: URL
    /// 入れたときに調べた暗号化の状態
    public let encryption: EncryptionReport.Status
    /// このファイルのページの回し方（回さないなら変更なしの指定）
    public let rotation: RotationPlan

    public init(url: URL, encryption: EncryptionReport.Status, rotation: RotationPlan) {
        self.url = url
        self.encryption = encryption
        self.rotation = rotation
    }
}
