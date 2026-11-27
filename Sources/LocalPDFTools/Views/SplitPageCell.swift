import SwiftUI

/// 分割のシートの縮小表示 1 枚分（画像・ページ番号・何番目のファイルに入るか）。
/// 入るファイルで背景の濃さを交互に変え、どのファイルにも入らないページは薄くする
struct SplitPageCell: View {
    let image: NSImage?
    let pageNumber: Int
    /// このページが入るファイルの番号（1 から。範囲を重ねて書けば 2 つ以上）
    let pieces: [Int]
    /// 回転もオンのとき、保存される向き（0〜3 回の 90°）
    let quarterTurns: Int

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
                        .rotationEffect(.degrees(Double(quarterTurns) * 90))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 144, height: 144)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.pink.opacity(pieces.first.map { $0 % 2 == 1 ? 0.12 : 0.05 } ?? 0))
            )
            HStack(spacing: 6) {
                Text("\(pageNumber)").font(.callout.weight(.medium)).monospacedDigit()
                Text(pieceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(pieces.isEmpty ? Color.gray : Color.pink))
            }
            .frame(height: 18)
        }
        .opacity(pieces.isEmpty ? 0.4 : 1)
    }

    private var pieceLabel: String {
        pieces.isEmpty ? "入れない" : pieces.map { "\($0) つ目" }.joined(separator: "・")
    }
}
