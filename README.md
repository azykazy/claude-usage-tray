# Claude Usage Tray

Claude Code の使用量を Windows システムトレイに常時表示するツール。

WSL2 上で Claude Code を使っている Windows ユーザー向け。

## 動作環境

- Windows 10 / 11
- WSL2（Ubuntu 等）がインストール済みで、Claude Code を使用していること
- PowerShell 5.1 以上（Windows 標準搭載）
- 追加インストール不要

## 表示内容

トレイアイコンに **使用率（%）** と **リセットまでの残り時間（分）** を直接表示。

```
┌──────┐
│ 42%  │  ← 直近5時間の使用率
│ 23m  │  ← リセットまでの残り分数
└──────┘
```

使用率に応じてアイコンの背景色が変化：

| 色 | 使用率 |
|---|---|
| 緑 | 60% 未満 |
| 橙 | 60〜84% |
| 赤 | 85% 以上 |

その他の操作：

| 操作 | 内容 |
|---|---|
| 左クリック | バルーン通知で詳細を表示 |
| 右クリック → Refresh now | 今すぐ手動更新 |
| 右クリック → Quit | 終了 |

## セットアップ

### 1. ファイルを Windows 側に配置

WSL から Windows のパスにコピーする例：

```bash
cp -r ~/claude-usage-tray /mnt/c/Users/<Windowsユーザー名>/claude-usage-tray
```

または ZIP をダウンロードして任意のフォルダに展開。

### 2. 動作確認

`debug-launch.bat` をダブルクリックして、エラーなく起動できるか確認。

### 3. サイレント起動

`launch-silent.vbs` をダブルクリック → タスクバーの通知領域にアイコンが表示される。

初回は `^`（オーバーフロー）内に隠れていることがある。  
アイコンをドラッグしてタスクバーに固定するか、Windows の設定から常時表示に変更できる。

### 4. Windows 起動時に自動起動（任意）

`setup-autostart.bat` をダブルクリック → スタートアップに登録される。

解除する場合：

```
setup-autostart.bat remove
```

## 設定のカスタマイズ

`claude-usage-tray.ps1` の冒頭で変更できる：

```powershell
$MSG_LIMIT    = 75     # 5時間あたりの上限目安（/usage で確認して調整）
$WINDOW_HOURS = 5      # 集計ウィンドウ（時間）
$UPDATE_MS    = 60000  # 更新間隔（ミリ秒）= 1分
```

WSL のディストリビューション名とユーザー名は**自動検出**される。  
自動検出が失敗する場合は以下のコメントを外して手動指定：

```powershell
# $WSL_DISTRO = "Ubuntu"
# $WSL_USER   = "yourname"
```

### MSG_LIMIT の調整

`MSG_LIMIT` は Claude Pro の非公開制限に基づく推定値。  
Claude Code の `/usage` コマンドで実際の使用率を確認し、表示と合うよう調整してください。

## データソース

`~/.claude/history.jsonl`（WSL ファイルシステム）を読み取り、  
過去 N 時間以内のセッション数をカウントして使用率を算出します。

> **注意**: この使用率はローカルの `history.jsonl` に基づく**推定値**です。  
> Anthropic の公式な使用量は Claude Code の `/usage` コマンドで確認してください。

## ファイル構成

```
claude-usage-tray/
├── README.md
└── windows/
    ├── claude-usage-tray.ps1   本体（トレイアイコン）
    ├── launch-silent.vbs       コンソールなしで PS1 を起動
    ├── setup-autostart.bat     Windows スタートアップへの登録・解除
    └── debug-launch.bat        トラブルシューティング用（エラー表示あり）
```

## ライセンス

MIT
