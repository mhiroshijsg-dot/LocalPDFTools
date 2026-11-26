import Foundation

/// qpdf のコマンドを呼び出す。
/// .app の中で動くときは同梱の qpdf だけを使う（同梱し忘れを Homebrew の qpdf で隠さないため）。
/// テストなど .app の外で動くときは Homebrew の qpdf を使う。
public final class QPDFRunner: @unchecked Sendable {

    /// qpdf を1回走らせた結果
    public struct Output: Sendable {
        public let exitCode: Int32
        /// 標準出力そのもの（画像のデータのように文字でないものもある）
        public let standardOutputData: Data
        public let standardError: String

        public var standardOutput: String { String(decoding: standardOutputData, as: UTF8.self) }

        /// qpdf の終了コード: 0 = 成功、3 = 成功したが警告あり、2 = 失敗
        public var succeeded: Bool { exitCode == 0 || exitCode == 3 }
        public var hasWarnings: Bool { exitCode == 3 }

        /// 警告の行（qpdf は標準エラーに出す）
        public var warningLines: [String] {
            standardError.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        }

        /// パスワードが違う（または要るのに渡していない）ために止まった
        public var isInvalidPassword: Bool {
            exitCode == 2 && standardError.contains("invalid password")
        }
    }

    public let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    /// 使う qpdf を決める
    public static func locate(bundle: Bundle = .main) throws -> QPDFRunner {
        let candidates: [URL]
        if bundle.bundleURL.pathExtension == "app" {
            candidates = [bundle.bundleURL.appendingPathComponent("Contents/Helpers/qpdf")]
        } else {
            candidates = [URL(fileURLWithPath: "/opt/homebrew/bin/qpdf"),
                          URL(fileURLWithPath: "/usr/local/bin/qpdf")]
        }
        guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw EngineError.qpdfNotFound(searched: candidates.map(\.path))
        }
        return QPDFRunner(executableURL: found)
    }

    /// 画面を止めないよう、別のスレッドで走らせる。
    /// input は qpdf の標準入力に渡す（パスワードを `--password-file=-` で渡すときに使う）。
    public func run(_ arguments: [String], input: Data? = nil) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try self.runBlocking(arguments, input: input))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 走らせて、失敗なら EngineError.qpdfFailed を投げる
    public func runChecked(_ arguments: [String], input: Data? = nil) async throws -> Output {
        let output = try await run(arguments, input: input)
        guard output.succeeded else {
            let message = output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            throw EngineError.qpdfFailed(exitCode: output.exitCode, message: message)
        }
        return output
    }

    func runBlocking(_ arguments: [String], input: Data? = nil) throws -> Output {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let inPipe = input.map { _ in Pipe() }
        process.standardInput = inPipe ?? FileHandle.nullDevice
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        try process.run()

        // MEMO(2026-11-25・by claude): パスワードはコマンドの引数に入れない。引数は同じ Mac の他のプログラムから
        // ps で見えてしまうため、標準入力で渡す。パスワードは短いのでパイプが詰まる心配はない。
        if let input, let inPipe {
            inPipe.fileHandleForWriting.write(input)
            try? inPipe.fileHandleForWriting.close()
        }

        // MEMO(2026-11-25・by claude): 出力が多いとパイプが詰まって qpdf が止まるので、
        // 終了を待つ前に標準出力と標準エラーを別々のスレッドで読み切る。
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return Output(exitCode: process.terminationStatus,
                      standardOutputData: outData,
                      standardError: String(decoding: errData, as: UTF8.self))
    }
}
