import SwiftUI

/// 設定の窓の「言語」の欄（Mac に合わせる・日本語・English）
struct LanguageSettingsSection: View {
    @State private var choice = AppLanguage.saved

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("言語").font(.title3.weight(.semibold))
            Picker("言語", selection: $choice) {
                ForEach(AppLanguage.allCases) { language in
                    Text(verbatim: language.title).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: choice) { _, language in AppLanguage.save(language) }
            if choice != AppLanguage.atLaunch {
                Label("アプリを終了して開き直すと、この言語になります", systemImage: "arrow.clockwise")
                    .font(.callout).foregroundStyle(.orange)
            }
        }
    }
}
