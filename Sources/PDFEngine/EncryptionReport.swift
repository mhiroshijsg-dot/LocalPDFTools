/// PDF の暗号化の状態
public struct EncryptionReport: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        /// 暗号化されていない
        case notEncrypted
        /// パスワードなしで開けるが、編集・印刷などが制限されている（ETS のスコアレポートなど）
        case restricted
        /// 開くのにパスワードが要る
        case passwordRequired
    }

    public let status: Status
    /// 暗号の方式（例: AES-256）。パスワードが要る PDF は、パスワードを入れるまで分からないので nil
    public let method: String?
    /// 禁止されている操作。分からないとき（パスワードを入れる前）は nil
    public let deniedPermissions: [PDFPermission]?

    public init(status: Status, method: String?, deniedPermissions: [PDFPermission]?) {
        self.status = status
        self.method = method
        self.deniedPermissions = deniedPermissions
    }

    /// 禁止されている操作を「・」でつないだ文。印刷そのものが禁止なら「高画質の印刷」は省く
    public var deniedSummary: String? {
        guard let denied = deniedPermissions else { return nil }
        let shown = denied.contains(.printLow) ? denied.filter { $0 != .printHigh } : denied
        return shown.isEmpty ? "なし" : shown.map(\.title).joined(separator: "・")
    }
}
