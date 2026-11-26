import SwiftUI

/// ページの縮小表示。これから回す分だけ傾けて見せる
struct PageThumbnailView: View {
    /// まだ作っていなければ nil（くるくるを出す）
    let image: NSImage?
    let pageNumber: Int
    /// 保存される向き（0〜3 回の 90°）。下の文字と枠に使う
    let quarterTurns: Int
    /// 画面で傾ける角度（90° 単位・丸めない）。回る方向を押した向きと合わせるため
    let displayTurns: Int
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .frame(width: 118, height: 118)
                        .rotationEffect(.degrees(Double(displayTurns) * 90))
                        .animation(.spring(duration: 0.3, bounce: 0.15), value: displayTurns)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 144, height: 144)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: quarterTurns == 0 ? 0 : 2.5)
            )
            HStack(spacing: 6) {
                Text("\(pageNumber)").font(.callout.weight(.medium)).monospacedDigit()
                if quarterTurns != 0 {
                    Text(turnLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                }
            }
            .frame(height: 18)
        }
        .animation(.snappy(duration: 0.2), value: quarterTurns)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var turnLabel: String {
        switch quarterTurns {
        case 1: return "右に 90°"
        case 2: return "180°"
        case 3: return "左に 90°"
        default: return ""
        }
    }
}
