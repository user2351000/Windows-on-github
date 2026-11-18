# GitHub Actions Windows Desktop

## 自分用です使い方分かる人だけ使っていいよ



































1. このリポジトリをFork（フォーク）する
2. [Windows Desktopワークフロー](../../actions/workflows/desktop.yml)を開く
3. ワークフローを実行し、ログに表示されたDesktopのURLを開く
4. `x` または `x/` をアドレスバーに入力してセッションを停止する

各ワークフローは `windows-latest` runner 上で 1500×937 の Windows デスクトップを起動し、noVNC と Cloudflare Tunnel 経由でブラウザーから接続します。runner がこの解像度に対応していない場合は、利用可能な近い解像度にフォールバックします。通常のワークフローには VNC パスワードがありません。`Windows Desktop Password` では ASCII 英数字1〜8文字の VNC パスワードを指定できます。

ブラウザーを起動するワークフローは Chrome のみです。`AI Desktop Apps` ワークフローでは ChatGPT for Windows と Claude Desktop をインストールしてからデスクトップを起動します。

## noVNCで日本語を入力する

起動時間を短くするため、Windowsの日本語言語機能やMicrosoft IMEはインストールしません。日本語はnoVNCツールバーのClipboardボタンから入力・貼り付けてください。クリップボードの内容を送り、貼り付け先で`Ctrl`+`V`を押します。

## デスクトップデータの引き継ぎ

GitHub-hosted runner は毎回新しいWindows環境なので、デスクトップを正常に停止（`x` または `x/`）するか、ワークフロー開始から約5時間30分後に自動停止すると、次回実行用に `Desktop`、`Documents`、`Downloads`、`Pictures`、`Videos`、`Music` とChromeプロファイルを暗号化してActions artifactへ保存します。Xのログイン状態を引き継ぐには、Chromeを起動する `Chrome` ワークフローを使ってログインし、デスクトップを正常に停止してください。自動停止はrunnerの6時間制限前に保存処理を実行するためのものです。Actionsの「Confirm desktop files saved」ステップと実行サマリーに保存完了メッセージが表示されたら、保存成功です。手動でワークフローをキャンセルした場合、その回の変更は保存されません。artifactの保持期間は90日です。保存データが競合しないよう、デスクトップのワークフローは同時に複数起動しないでください。アプリ本体は保存されず、ワークフローで指定されたアプリは起動ごとに再インストールされます。

Chromeプロファイルは保存されますが、GitHub-hosted runner は毎回別のWindows環境のため、Windowsの暗号化で保護されたCookieを復元できず、Xなどのサービスで再ログインが必要になる場合があります。ログイン状態を確実に維持するには、同じWindows環境を使い続けるセルフホストランナーが必要です。

公開リポジトリでもファイルを平文で公開しないよう、暗号化キーの登録が必要です。

1. ローカルで `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"` を実行してキーを生成する
2. リポジトリの **Settings → Secrets and variables → Actions** で、`WINDOWS_DESKTOP_STATE_ENCRYPTION_KEY` というRepository secretを作り、生成したキーを登録する
3. 以降のデスクトップ起動ワークフローでは、同じSecretが使われます。キーを紛失・変更すると、保存済みデータを復号できません

