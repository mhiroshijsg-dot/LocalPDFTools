import SwiftUI

/// 保存名の入力欄と文字数。上限を入れると、超えたら赤字になる
struct OutputNameField: View {
    @Binding var name: String
    /// 上限はすべての機能で共通にして、アプリを閉じても覚えておく（0 は上限なし）
    @AppStorage("fileNameLimit") private var limit = 0

    var body: some View {
        let fullName = OutputName.withPDFExtension(name)
        HStack {
            Text("保存名")
            TextField("output.pdf", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 200)
            Text("\(OutputName.length(fullName)) 文字")
                .monospacedDigit()
                .foregroundStyle(OutputName.exceeds(fullName, limit: limit) ? Color.red : Color.secondary)
                .help("拡張子 .pdf も含めた文字数")
            Text("上限")
            TextField("なし", value: $limit, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .help("提出先の文字数の上限（0 は上限なし）")
        }
    }
}
