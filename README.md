# GitHub Actions Windows Desktop

## 使用方法

1. このリポジトリをFork（フォーク）する
2. [Windows Desktopワークフロー](../../actions/workflows/desktop.yml)を開く
3. ワークフローを実行し、ログに表示されたDesktopのURLを開く
4. `x` または `x/` をアドレスバーに入力してセッションを停止する

各ワークフローは `windows-latest` runner 上で 1500×937 の Windows デスクトップを起動し、noVNC と Cloudflare Tunnel 経由でブラウザーから接続します。runner がこの解像度に対応していない場合は、利用可能な近い解像度にフォールバックします。通常のワークフローには VNC パスワードがありません。`Windows Desktop Password` では ASCII 英数字1〜8文字の VNC パスワードを指定できます。

ブラウザーを起動するワークフローは Chrome のみです。`AI Desktop Apps` ワークフローでは ChatGPT for Windows と Claude Desktop をインストールしてからデスクトップを起動します。

## noVNCでの日本語入力

デスクトップ起動時に日本語言語機能とMicrosoft IMEを設定します。noVNC内のWindows画面で、タスクバーの入力表示（`ENG`、`A`、`あ`など）をクリックして日本語 Microsoft IMEに切り替えます。ChromebookなどWindowsキーがない端末でも、この方法で切り替えられます。入力表示が見つからない場合やキー入力で変換できない場合は、noVNCのClipboardボタンから日本語テキストを貼り付けてください。

## デスクトップデータの引き継ぎ

GitHub-hosted runner は毎回新しいWindows環境なので、デスクトップを正常に停止（`x` または `x/`）すると、次回実行用に `Desktop`、`Documents`、`Downloads`、`Pictures`、`Videos`、`Music` とChromeプロファイルを暗号化してActions artifactへ保存します。Actionsの「Confirm desktop files saved」ステップと実行サマリーに保存完了メッセージが表示されたら、保存成功です。停止せずにワークフローをキャンセルした場合、その回の変更は保存されません。artifactの保持期間は90日です。保存データが競合しないよう、デスクトップのワークフローは同時に複数起動しないでください。アプリ本体は保存されず、ワークフローで指定されたアプリは起動ごとに再インストールされます。

公開リポジトリでもファイルを平文で公開しないよう、暗号化キーの登録が必要です。

1. ローカルで `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"` を実行してキーを生成する
2. リポジトリの **Settings → Secrets and variables → Actions** で、`WINDOWS_DESKTOP_STATE_ENCRYPTION_KEY` というRepository secretを作り、生成したキーを登録する
3. 以降のデスクトップ起動ワークフローでは、同じSecretが使われます。キーを紛失・変更すると、保存済みデータを復号できません

