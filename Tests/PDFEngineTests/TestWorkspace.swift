import CryptoKit
import Foundation
import PDFEngine
import PDFKit

/// テスト 1 件分の作業場所。一時フォルダに合成した PDF を置き、テストが終わったら消す。
/// テストは並んで走るので、1 件ごとに別のフォルダを使う。
///
/// 使う qpdf: 普段は Homebrew のもの。.app に同梱した qpdf で確かめたいときは、
/// `TEST_RUNNER_LOCALPDFTOOLS_QPDF=build/LocalPDFTools.app/Contents/Helpers/qpdf xcodebuild test …` のように渡す。
final class TestWorkspace {
    let directory: URL
    let qpdf: QPDFRunner
    let factory: SamplePDFFactory
    /// 縦長 2 ページ（名前に空白と日本語を入れて、パスの扱いも確かめる）
    let fileA: URL
    /// 横長 3 ページ
    let fileB: URL

    static let portrait = CGSize(width: 300, height: 400)
    static let landscape = CGSize(width: 400, height: 300)

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalPDFTools-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let path = ProcessInfo.processInfo.environment["LOCALPDFTOOLS_QPDF"], !path.isEmpty {
            qpdf = QPDFRunner(executableURL: URL(fileURLWithPath: path))
        } else {
            qpdf = try QPDFRunner.locate()
        }
        factory = SamplePDFFactory(directory: directory)
        fileA = try factory.make(name: "成績 A.pdf", pageSizes: [Self.portrait, Self.portrait])
        fileB = try factory.make(name: "成績 B.pdf", pageSizes: [Self.landscape, Self.landscape, Self.landscape])
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    func url(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// ファイルの中身の指紋（1 バイトでも変わったら違う値になる）
    func sha(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    func document(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw SampleError("開けない: \(url.lastPathComponent)") }
        return document
    }

    func pageWidths(_ url: URL) throws -> [CGFloat] {
        let document = try document(url)
        return (0..<document.pageCount).map { document.page(at: $0)!.bounds(for: .mediaBox).width }
    }

    func pageRotations(_ url: URL) throws -> [Int] {
        let document = try document(url)
        return (0..<document.pageCount).map { document.page(at: $0)!.rotation }
    }

    /// PDF ではないファイル
    func brokenFile() throws -> URL {
        let url = url("壊れた.pdf")
        try Data("これは PDF ではない".utf8).write(to: url)
        return url
    }

    /// 開けるが編集・印刷などが制限された PDF（ETS のスコアレポート型・AES-256）
    func restrictedFile() throws -> URL {
        try factory.encrypt(fileA, name: "制限付き.pdf", userPassword: "", qpdf: qpdf.executableURL)
    }

    /// 開くのにパスワードが要る PDF
    func lockedFile(password: String = "user-secret") throws -> URL {
        try factory.encrypt(fileA, name: "要パスワード.pdf", userPassword: password, qpdf: qpdf.executableURL)
    }
}
