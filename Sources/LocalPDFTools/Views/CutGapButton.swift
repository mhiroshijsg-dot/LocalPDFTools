import SwiftUI

/// 分割のシートの、ページとページの間。切れ目なら桃色の点線とはさみ。押すと切れ目を付け外しする
struct CutGapButton: View {
    let isCut: Bool
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "scissors")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isCut ? Color.pink : Color.secondary)
                    .opacity(isCut || isHovered ? 1 : 0)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2)
                    .overlay(
                        Line()
                            .stroke(isCut ? Color.pink : Color.secondary.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            .opacity(isCut || isHovered ? 1 : 0)
                    )
            }
            .frame(width: 28, height: 144)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = isEnabled && $0 }
        .help(isCut ? "この切れ目を外す" : "ここで切る")
        .padding(.bottom, 26)
    }

    /// 縦の線
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
        }
    }
}
