import Foundation
import SwiftUI

/// 同梱した部品のライセンスの文（.app の中の Contents/Resources/ThirdPartyLicenses）を Finder で見せるボタン
struct HelpLicensesButton: View {
    /// ビルドのたびに scripts/bundle_qpdf.sh が置く。無ければ nil（ボタンを押せなくする）
    private let folder: URL? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("ThirdPartyLicenses", isDirectory: true),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if let folder { DesktopActions.revealInFinder(folder) }
            } label: {
                Label("ライセンスの文を Finder で表示", systemImage: "doc.text")
            }
            .disabled(folder == nil)
            if folder == nil {
                Text("ライセンスの文のフォルダが、アプリの中に見つかりませんでした")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }
}
