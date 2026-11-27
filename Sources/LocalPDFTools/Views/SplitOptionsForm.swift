import SwiftUI

/// 分け方の選ぶ欄（カードではメニュー、シートでは丸いボタンの並び）と、分け方ごとの指定
struct SplitOptionsForm: View {
    @Bindable var split: SplitModel
    let fileCount: Int
    /// シートでは丸いボタンを縦に並べる
    var usesRadio = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            picker
            switch split.mode {
            case .eachPage:
                EmptyView()
            case .everyPages:
                Stepper(value: $split.pagesPerFile, in: 1...9999) {
                    HStack(spacing: 4) {
                        TextField("", value: $split.pagesPerFile, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 56)
                        Text("ページごと")
                    }
                }
            case .ranges:
                TextField("例: 1-3, 4-7, 8-", text: $split.rangeText)
                    .textFieldStyle(.roundedBorder)
            case .cuts:
                Text(split.cuts.isEmpty ? "「ページを見て分ける…」で、ページの間をクリックして切ります"
                                        : "切れ目 \(split.cuts.count) か所")
                    .foregroundStyle(.secondary)
            }
            if split.mode.needsSingleFile && fileCount > 1 {
                Text("この分け方は PDF が 1 つのときだけ使えます").foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        let picker = Picker("分け方", selection: $split.mode) {
            ForEach(SplitMode.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden()
        if usesRadio {
            picker.pickerStyle(.radioGroup)
        } else {
            picker.pickerStyle(.menu).fixedSize()
        }
    }
}
