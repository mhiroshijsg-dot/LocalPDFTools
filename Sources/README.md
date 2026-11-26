# Sources の中身

どのファイルが何をしているかの一覧。ファイルを足したり役割を変えたりしたら、ここも直す。

## 開き方

`LocalPDFTools.xcodeproj` を Xcode で開く。⌘R でアプリが起動し、⌘U で検査（テスト）が走る。
フォルダの中のファイルは Xcode に自動で入る（ファイルを足しても、プロジェクトの設定を直す必要はない）。

## 3 つのフォルダ（Xcode では 3 つの「ターゲット」）

| フォルダ | 何か | アプリに入るか |
|---|---|---|
| `Sources/LocalPDFTools/` | アプリ本体（画面とボタンの動き） | 入る |
| `Sources/PDFEngine/` | PDF の処理（qpdf の呼び出し・保存）。画面を持たない部品（フレームワーク） | 入る（本体から使う） |
| `Tests/PDFEngineTests/` | `PDFEngine` の検査。合成した PDF で結合・回転・暗号化の解除などを確かめる | 入らない |

## ビルドと .app

| ファイル | 役割 |
|---|---|
| `LocalPDFTools.xcodeproj` | Xcode のプロジェクト。バージョン番号（MARKETING_VERSION）もここ |
| `scripts/bundle_qpdf.sh` | Xcode のビルドの最後に毎回走り、Homebrew の qpdf とそのライブラリを .app に入れて署名する。⌘R でも配る形と同じ中身になる |
| `scripts/make_app.sh` | 配る形（Release）の .app を `build/LocalPDFTools.app` に作り、Releases に載せる zip（`build/LocalPDFTools-<バージョン>.zip`）も作る |
| `scripts/make_icon.swift` | アプリのアイコンを図形で描いて `Sources/LocalPDFTools/Assets.xcassets/AppIcon.appiconset/` に書き出す（`swift scripts/make_icon.swift`）。色や形はこのファイルの数値で決まる |

覚え方: **見た目は `Views`、ボタンを押したあとの動きは `Models`、PDF そのものの処理は `PDFEngine`**。
こう分けておくと、見た目を変えても PDF の処理を壊さない。

## 動く順番

```
LocalPDFToolsApp.swift          起動の入口。作業台の窓 1 つと、設定の窓（⌘,）を作る
   ↓
Views/WorkspaceView.swift       作業台（窓全体）。左に PDF の並び、右にやること（操作のカード）、下に保存
   ↓ 「実行して保存…」が押されたら
Models/WorkspaceRunner.swift    保護を外す確認 → 保存ダイアログ → 処理 → 結果
   ↓
PDFEngine/PDFPipeline.swift     解除 → 回転 → 結合 → 圧縮 を指定の順に続けて行う（パスワードは要る時点で聞く）
   ↓
PDFEngine/PDFDecryptor・PDFRotator・PDFMerger・PDFCompressor   それぞれ qpdf を呼ぶ
   ↓
PDFEngine/OutputWriter.swift    一時フォルダで作ってから保存先へ移す（入力と同じ場所には保存させない）
```

## LocalPDFTools/（アプリ本体）

### 入口と全体

| ファイル | 役割 |
|---|---|
| `LocalPDFToolsApp.swift` | 起動の入口。作業台の窓を 1 つと設定の窓を作る。作業台の状態（`Workspace`）を 1 組だけ持つ |
| `AppDelegate.swift` | SwiftUI だけでは決められない振る舞い。窓を閉じたらアプリも終わる |
| `AppInfo.swift` | アプリ名 |
| `Assets.xcassets` | アプリのアイコン（AppIcon）。中の PNG は `scripts/make_icon.swift` が作るので、手で描き換えない |

### Views/（画面の見た目）

| ファイル | 役割 |
|---|---|
| `WorkspaceView.swift` | 窓全体（作業台）。左にファイルの並び、右にやること、下に結果と保存の欄。上のツールバーに「PDF を追加」（⌘O）と「すべて外す」。回転のシートを開く |
| `FileListView.swift` | 入れた PDF の並び（ドラッグで並べ替え）と合計。空のときは大きな「ここにドロップ」 |
| `FileRowView.swift` | 並びの 1 行（番号・1 ページ目の絵・名前・ページ数と大きさ・「制限あり」「要パスワード」「しおりあり」「○ ページ回転」の色付きの札・外すボタン） |
| `OperationListView.swift` | やること＝操作のカードの並び（暗号化の解除・回転・結合・圧縮。文字の抽出は「今後のバージョンで追加」）。設定の順に並ぶ |
| `CompressionDetailsView.swift` | 圧縮のカードの中身（構造の圧縮・解像度・JPEG の画質・図の線を減らす・大きさの内訳・目安・目標の大きさ・試算） |
| `SaveBar.swift` | これから行うこと（`PlanSummaryView`）・保存名（結合のとき・1 ファイルのとき）・保存先と「変更…」・「実行して保存…」とできない理由 |
| `PlanSummaryView.swift` | 「解除 → 回転 → 結合 → 1 つの PDF にして保存」のように、オンにした操作を実行する順に矢印でつないで見せる |
| `RotatePagesSheet.swift` | 回転のシート。全ファイルのページを並べ、「すべて右に 90°」など |
| `FilePagesSection.swift` | 回転のシートのファイル 1 つ分（ページの縮小表示。クリックで回す） |
| `PageThumbnailView.swift` | 縮小表示 1 枚分（画像・ページ番号・「右に 90°」の札・回すページは青い枠） |
| `SettingsView.swift` | 設定の窓（⌘,）。操作を行う順番（解除はいつも最初・残りはドラッグか右クリックで並べ替え・順番の見本・おすすめの順に戻す） |

`WorkspaceView.swift`・`RotatePagesSheet.swift` の末尾の `#Preview` は、Xcode のプレビュー（右側にその場で描かれる画面）の設定。

### Views/Previews/（プレビュー用。配る .app には入らない）

| ファイル | 役割 |
|---|---|
| `PreviewSamples.swift` | プレビューに使う見本のデータ（架空のファイル名を並べた作業台・番号入りの見本 PDF を回した作業台） |

### Views/Common/（いくつかの画面で使う部品）

| ファイル | 役割 |
|---|---|
| `DropZone.swift` | PDF がまだ無いときの大きな案内（「ここにドロップ」・「ファイルを選ぶ…」・この Mac の中だけで処理する旨） |
| `OutputNameField.swift` | 保存名の入力欄・文字数・文字数の上限（上限を超えると赤字） |
| `OutcomeView.swift` | 保存後の緑のカード（保存した名前と場所・「元 → 新」の大きさ・ファイル名の文字数・Finder で表示） |
| `MessageList.swift` | エラー・警告（赤字）とお知らせの一覧。記号付きの帯で出す。右にコピーボタン |
| `Badge.swift` | ファイル名の横の小さな札（記号と色付き） |
| `OperationIcon.swift` | 操作の印（色の付いた角丸の四角に白い記号）。解除は橙・回転は青・結合は紫など、操作ごとの色もここで決める |
| `OperationCard.swift` | 操作 1 つ分のカード（印・名前・一言・スイッチ。オンのときだけ詳しい内容） |
| `FirstPageThumbnail.swift` | ファイルの行に出す 1 ページ目の小さな絵（パスワードが要る PDF は鍵の印） |

### Models/（画面の状態と、ボタンを押したときの動き）

| ファイル | 役割 |
|---|---|
| `Workspace.swift` | 作業台の状態（ファイルの並び・チェックした操作・保存名・保存先・結果）と、実行できない理由・保護が外れるファイル |
| `WorkspaceRunner.swift` | 「実行して保存…」の流れ。結合ありなら保存ダイアログ 1 回、結合なしならファイルごとに保存ダイアログ（キャンセルしたものは飛ばして最後に知らせる） |
| `WorkFile.swift` | 入れた PDF 1 つ分（情報・暗号化の状態・ページの回し方・縮小表示・圧縮の分析の結果）。パスワードは持たない |
| `CompressionModel.swift` | 圧縮のやり方の選択・分析（圧縮をオンにしたときに初めて行う）・目安・試算（押したときだけ。中止できる） |
| `Operation.swift` | 操作の名前とアイコン（まだ作っていない圧縮・文字の抽出も） |
| `OperationOrder.swift` | 操作の順番の設定（解除はいつも最初・おすすめは 回転 → 結合 → 圧縮） |
| `SuggestedName.swift` | 保存名の初期値（`一番上の名前_merge.pdf`・`元の名前_unlocked_rotated_compressed.pdf` など） |
| `ThumbnailCache.swift` | 縮小表示を作って覚えておく（同じページを何度も描かない） |
| `OutputName.swift` | 保存名に `.pdf` を付ける・文字数を数える・上限を超えたかを判定する |
| `UserMessage.swift` | 画面に出すお知らせ 1 件（エラー・警告・お知らせの区別と文） |

### Services/（Mac の機能を呼ぶ部品）

| ファイル | 役割 |
|---|---|
| `FilePanels.swift` | 「開く」「フォルダを選ぶ」「保存」のダイアログ |
| `PasswordPrompt.swift` | パスワードが要る時点で 1 回聞く小窓。読んだらすぐ入力欄を空にし、どこにも保存しない |
| `UnlockConfirmation.swift` | 「PDF の保護を外します。よろしいですか？」の確認 |
| `DesktopActions.swift` | Finder でファイルを表示する・文字をコピーする |

## PDFEngine/（PDF の処理。画面を持たない）

| ファイル | 役割 |
|---|---|
| `QPDFRunner.swift` | qpdf のコマンドを呼ぶ。.app の中（Xcode の ⌘R も含む）では同梱の qpdf、テストでは Homebrew の qpdf を使う |
| `QPDFPassword.swift` | qpdf にパスワードを渡す方法。引数ではなく標準入力で渡す（引数は他のプログラムから見えるため） |
| `PDFPipeline.swift` | 解除 → 回転 → 結合 → 圧縮 を指定の順に続けて行い、最後の 1 つだけ保存先へ置く。パスワードは要る時点で聞き（違えば聞き直す）、そのまま qpdf に渡す。結合の後に回すときは通しのページ番号に直す |
| `PipelineStep.swift` | 続けて行える操作（解除・回転・結合・圧縮） |
| `PDFCompressor.swift` | 圧縮。画像を取り出して縮小・再圧縮し、`qpdf --update-from-json` で差し戻す。構造の圧縮は `--object-streams=generate --recompress-flate --compression-level=9`。中止できる |
| `ImageRecompressor.swift` | 画像 1 つの作り直し（Mac 標準の画像処理）。JPEG は縮小・画質、可逆の画像は縮小だけ。小さくならなければ作り直さない |
| `CompressionSettings.swift` | 圧縮のやり方（構造の圧縮・目標の dpi・JPEG の画質・図の線を減らす） |
| `VectorThinning.swift` | 図の線を減らすやり方（補助グリッド線・補助目盛を消す・曲線の点を間引く。既定はすべてオフ） |
| `VectorThinningReport.swift` | 図の線を減らすと減る数（消せる線の本数・間引く前後の点の数・小さくなる大きさの目安） |
| `ContentStreamThinner.swift` | 描画の命令の書き換え。`make_compact_pdf.py` の判定を移したもの（20 本以上の繰り返し・文書全体で一番短い目盛・Ramer–Douglas–Peucker で 0.1pt 以内） |
| `PDFVectorThinner.swift` | ページと図（Form XObject）の描画の命令を集めて ContentStreamThinner をかけ、qpdf で差し戻す指定を作る |
| `JPEGQuality.swift` | JPEG の画質の段階（高 0.85・中 0.75・低 0.6・最低 0.5）と目安の割合 |
| `CompressionResult.swift` | 圧縮した結果の数（縮めた画像・画質を下げた画像・元のまま残した画像・消した線と間引いた点） |
| `PDFContentAnalyzer.swift` | 大きさの内訳（画像・フォント・その他）と画像の一覧を作る。触れない画像（白黒スキャン・CMYK など）は理由を付ける |
| `PDFContentReport.swift` | 内訳 1 ファイル分と、目安の計算（式による見積もり） |
| `PDFImageInfo.swift` | 画像 1 つ分（形式・ピクセル数・ページ上の大きさと解像度・触れない理由） |
| `ImagePlacementScanner.swift` | ページの描画の命令を読み、画像がページ上でどの大きさに描かれているかを調べる（図の中の画像もたどる） |
| `QPDFObjectTable.swift` | `qpdf --json` の部品の一覧の読み取り（参照のたどり方・ページの資源） |
| `PipelineFile.swift` | 続けて処理するファイル 1 つ分（場所・暗号化の状態・回し方） |
| `PDFMerger.swift` | 結合。`qpdf --empty --pages a.pdf b.pdf -- 出力.pdf` |
| `PDFRotator.swift` | 回転。`qpdf 入力 出力 --rotate=+90:1,3` |
| `RotationPlan.swift` | ページごとに「時計回りに何回 90° 回すか」と、それを qpdf の引数にする処理 |
| `OutputWriter.swift` | 保存の共通処理。入力と同じファイルには保存させない・一時ファイルに作ってから保存先へ移す（失敗しても既存のファイルを壊さない） |
| `PDFDecryptor.swift` | 暗号化の解除。`qpdf --decrypt`。保存先へ移す前に、出力が本当に暗号化なしかを確かめる |
| `PDFEncryptionInspector.swift` | 暗号化の状態を調べる。`qpdf --requires-password` と `qpdf --json --json-key=encrypt` |
| `EncryptionReport.swift` | 調べた結果 1 ファイル分（暗号化なし／制限付き／パスワードが要る・方式・禁止されている操作） |
| `PDFPermission.swift` | 禁止できる操作の一覧と日本語の名前（印刷・コピー・編集など） |
| `QPDFEncryptionJSON.swift` | qpdf の JSON の読み取り（使う部分だけ） |
| `PDFInspector.swift` | PDF を開いてページ数・大きさ・暗号化・しおりの有無を読む（中身は変えない） |
| `PDFFileInfo.swift` | `PDFInspector` が読んだ情報 1 ファイル分 |
| `OperationOutcome.swift` | 保存の結果（保存先・元と新の大きさ・qpdf の警告） |
| `FileSize.swift` | ファイルの大きさの取得と「4.9 MB」のような表示 |
| `EngineError.swift` | エラーの種類と、画面に出す日本語の説明文 |

## Tests/PDFEngineTests/（検査。アプリには入らない）

Xcode では ⌘U。結果は左の「テスト」の欄（◇ の印）に、1 件ごとに ✔ / ✘ で出る。
ターミナルなら `xcodebuild -project LocalPDFTools.xcodeproj -scheme LocalPDFTools test`。
.app に同梱した qpdf で確かめるときは、頭に `TEST_RUNNER_LOCALPDFTOOLS_QPDF=build/LocalPDFTools.app/Contents/Helpers/qpdf` を付ける。

| ファイル | 役割 |
|---|---|
| `MergeTests.swift` | 結合（順番・制限付きの混在・しおりが消えること） |
| `RotateTests.swift` | 回転（ページごと・足し算・大きさ・暗号化を保つこと） |
| `OutputSafetyTests.swift` | 保存の安全（入力と同じ保存先を止める・失敗しても既存のファイルを壊さない） |
| `PDFInspectorTests.swift` | 読み込み（制限付き・パスワードが要る・PDF でない） |
| `EncryptionTests.swift` | 暗号化の判定と解除（ETS 型・パスワード・日本語のパスワード・間違ったパスワード） |
| `VectorThinningTests.swift` | 図の線を減らす（数える・全部・グリッド線だけ・オフなら変わらない・ずれ 0.1pt を超える点は残す） |
| `CompressTests.swift` | 圧縮（解像度の判定・図の中の画像・目安・150/72 dpi・画質だけ・構造だけ・暗号化を保つ・続けて処理・中止） |
| `PipelineTests.swift` | 続けて処理（一度にした結果 = 1 つずつ・結合の後に回す・パスワードは要るときだけ聞く・やめたら何も残らない） |
| `TestWorkspace.swift` | テスト 1 件分の作業場所（一時フォルダ・見本の PDF・使う qpdf）。終わったら消す |
| `SamplePDFFactory.swift` | 検査に使う PDF を合成する（個人の書類は使わない）。画像入り（300 ppi の JPEG・150 ppi の灰色）と、それを縮めて図として置いたもの、matplotlib の対数軸の図に似せたものも |
| `SampleError.swift` | 見本の PDF を作れなかったときのエラー |
