# GitHub Actions Windows Desktop

## xみれない。とても不便

>
>










































1. このリポジトリをFork（フォーク）する
2. [Windows Desktopワークフロー](../../actions/workflows/desktop.yml)を開く
3. ワークフローを実行し、ログに表示されたDesktopのURLを開く
4. `x` または `x/` をアドレスバーに入力してセッションを停止する

各ワークフローは `windows-latest` runner 上で 1500×937 の Windows デスクトップを起動し、noVNC と Cloudflare Tunnel 経由でブラウザーから接続します。runner がこの解像度に対応していない場合は、利用可能な近い解像度にフォールバックします。通常のワークフローには VNC パスワードがありません。`Windows Desktop Password` では ASCII 英数字1〜8文字の VNC パスワードを指定できます。

ブラウザーを起動するワークフローは Chrome のみです。`AI Desktop Apps` ワークフローでは Visual Studio Code for Windows、ChatGPT for Windows、Claude Desktop をインストールしてからデスクトップを起動します。

## noVNCで日本語を入力する

デスクトップ起動時に日本語言語機能とMicrosoft IMEをインストールし、Windowsの表示言語・入力言語・地域設定を日本語にします。ユーザーの言語リストには日本語のみを設定します。言語変更はWindowsの仕様上、サインアウトまたは再起動後にすべての画面へ反映されます。日本語入力にはMicrosoft IMEを利用できます。必要に応じてnoVNCツールバーのClipboardからテキストを貼り付けてください。

## デスクトップデータの引き継ぎ

GitHub-hosted runner は毎回新しいWindows環境なので、デスクトップを正常に停止（`x` または `x/`）するか、ワークフロー開始から約5時間30分後に自動停止すると、次回実行用に `Desktop`、`Documents`、`Downloads`、`Pictures`、`Videos`、`Music`、Chromeプロファイル、およびアプリのファイルを暗号化してActions artifactへ保存します。既定では `%LOCALAPPDATA%\Programs`（VS Codeのユーザー単位インストール先など）を保存します。ほかのアプリのインストール先も保存するには、ワークフローの `with:` に `application-dirs: 'C:\Program Files\MyApp;D:\Apps'` のようにセミコロン区切りで指定してください。同じ保存先を次回以降も指定してください。アプリのファイルは復元されますが、Windowsのレジストリ登録、サービス、ドライバーやMicrosoft Storeアプリの登録状態までは復元されないため、これらに依存するアプリは動作しないことがあります。アプリの保存先を増やすとartifactのサイズと保存・復元時間も増えます。

Xのログイン状態を引き継ぐには、Chromeを起動する `Chrome` ワークフローを使ってログインし、デスクトップを正常に停止してください。自動停止はrunnerの6時間制限前に保存処理を実行するためのものです。Actionsの「Confirm desktop files saved」ステップと実行サマリーに保存完了メッセージが表示されたら、保存成功です。手動でワークフローをキャンセルした場合、その回の変更は保存されません。artifactの保持期間は90日です。保存データが競合しないよう、デスクトップのワークフローは同時に複数起動しないでください。

Chromeのプロファイル（ブックマークや設定など）は保存・復元されます。`profile-dir` を指定した場合もその保存先を引き継ぎます。ただし、GitHub-hosted runner は毎回別のWindows環境のため、Windowsの暗号化で保護されたCookieは復元できず、Xなどのサービスには毎回再ログインが必要です。ログイン状態を維持するには、同じWindows環境を使い続けるセルフホストランナーが必要です。

公開リポジトリでもファイルを平文で公開しないよう、暗号化キーの登録が必要です。

1. ローカルで `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"` を実行してキーを生成する
2. リポジトリの **Settings → Secrets and variables → Actions** で、`WINDOWS_DESKTOP_STATE_ENCRYPTION_KEY` というRepository secretを作り、生成したキーを登録する
3. 以降のデスクトップ起動ワークフローでは、同じSecretが使われます。キーを紛失・変更すると、保存済みデータを復号できません
