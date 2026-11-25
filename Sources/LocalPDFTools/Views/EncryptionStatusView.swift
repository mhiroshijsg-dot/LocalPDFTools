import PDFEngine
import SwiftUI

/// 暗号化の状態の札: 「暗号化なし」「開けるが制限付き」「開くのにパスワードが要る」と、その中身
struct EncryptionStatusView: View {
    let report: EncryptionReport

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(report.status == .notEncrypted ? Color.green : Color.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                ForEach(details, id: \.self) { line in
                    Text(line).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private var symbolName: String {
        switch report.status {
        case .notEncrypted: return "lock.open"
        case .restricted: return "lock"
        case .passwordRequired: return "lock.fill"
        }
    }

    private var title: String {
        switch report.status {
        case .notEncrypted: return "暗号化なし"
        case .restricted: return "開けるが、編集・印刷などが制限されている"
        case .passwordRequired: return "開くのにパスワードが要る"
        }
    }

    private var details: [String] {
        var lines: [String] = []
        if let method = report.method { lines.append("暗号の方式: \(method)") }
        if report.status != .notEncrypted, let summary = report.deniedSummary {
            lines.append("禁止されている操作: \(summary)")
        }
        if report.status == .passwordRequired && report.method == nil {
            lines.append("パスワードを入れると外せます。")
        }
        return lines
    }
}
