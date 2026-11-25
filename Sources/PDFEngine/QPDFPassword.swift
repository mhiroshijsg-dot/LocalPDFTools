import Foundation

/// qpdf にパスワードを渡す方法。コマンドの引数ではなく標準入力で渡す（他のプログラムから見えないように）
enum QPDFPassword {
    /// 「パスワードは標準入力の 1 行目」という qpdf の指定
    static let arguments = ["--password-file=-"]

    static func input(_ password: String?) -> Data {
        Data((password ?? "").utf8)
    }
}
