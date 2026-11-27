import Foundation

/// `qpdf --json --json-key=encrypt` の出力のうち、使う部分だけ。
/// MEMO(2026-11-25・by claude): `--show-encryption` は人が読む文なので、qpdf の版で言い回しが変わると読み違える。
/// JSON（version 2）なら名前で取り出せる。qpdf 12.4.2 で形を確認した。
struct QPDFEncryptionJSON: Decodable {
    struct Encrypt: Decodable {
        let encrypted: Bool
        let capabilities: [String: Bool]
        let parameters: Parameters
    }

    struct Parameters: Decodable {
        let bits: Int
        let method: String
    }

    let encrypt: Encrypt

    /// 暗号の方式を、よく使われる呼び名にする
    var methodName: String {
        switch encrypt.parameters.method {
        case "AESv3": return "AES-256"
        case "AESv2": return "AES-128"
        case "RC4": return String(localized: "RC4（\(encrypt.parameters.bits) ビット）", bundle: .engine)
        default: return encrypt.parameters.method
        }
    }

    /// 禁止されている操作（qpdf が名前を出さなかったものは数えない）
    var deniedPermissions: [PDFPermission] {
        PDFPermission.allCases.filter { encrypt.capabilities[$0.rawValue] == false }
    }
}
