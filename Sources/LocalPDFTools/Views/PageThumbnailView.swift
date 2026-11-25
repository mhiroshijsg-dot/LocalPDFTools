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

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(radius: 1)
                        .rotationEffect(.degrees(Double(displayTurns) * 90))
                        .animation(.easeInOut(duration: 0.15), value: displayTurns)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 140, height: 140)
            .background(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(quarterTurns == 0 ? Color.clear : Color.accentColor, lineWidth: 2))
            Text("\(pageNumber)").monospacedDigit()
            Text(turnLabel).font(.caption).foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
    }

    private var turnLabel: String {
        switch quarterTurns {
        case 1: return "右に 90°"
        case 2: return "180°"
        case 3: return "左に 90°"
        default: return " "
        }
    }
}
