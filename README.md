# GitHub Actions Windows Desktop

## 使用方法

1. このリポジトリをFork（フォーク）する
2. [Windows Desktopワークフロー](../../actions/workflows/desktop.yml)を開く
3. ワークフローを実行し、ログに表示されたDesktopのURLを開く
4. `x` または `x/` をアドレスバーに入力してセッションを停止する

各ワークフローは `windows-latest` runner 上で 1500×937 の Windows デスクトップを起動し、noVNC と Cloudflare Tunnel 経由でブラウザーから接続します。通常のワークフローには VNC パスワードがありません。`Windows Desktop Password` では ASCII 英数字1〜8文字の VNC パスワードを指定できます。

