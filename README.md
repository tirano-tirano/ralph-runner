# Ralph Runner

Claude Code に同じプロンプトを繰り返し実行させ、タスクが完了するまで自動的に作業を続けさせるツール。

Geoffrey Huntley 氏が考案した「Ralph Loop」パターンを、オプション付きのスクリプトとして使いやすくしたもの。

## 仕組み

1. `PROMPT.md`（指示書）と `TODO.md`（タスクリスト）を用意する
2. `ralph` を実行すると、Claude Code が 1 周ごとに PROMPT.md を読み、TODO.md の未完了タスクを 1 つ処理する
3. TODO.md のすべてのタスクが完了（`[x]`）になるとループが自動終了する

毎回新しい Claude Code プロセスが起動するため、コンテキストが肥大化しない。状態は TODO.md や SCRATCH.md などの外部ファイルで引き継ぐ。

## インストール

```bash
curl -fsSL https://raw.githubusercontent.com/tirano-tirano/ralph-runner/main/install.sh | bash
```

`$HOME/.local/bin` にインストールされる。PATH が通っていない場合は、以下を `~/.bashrc` に追加:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

インストール先を変えたい場合は環境変数 `RALPH_INSTALL_DIR` を指定:

```bash
RALPH_INSTALL_DIR=/usr/local/bin curl -fsSL .../install.sh | bash
```

## 使い方

### 1. プロジェクトに PROMPT.md と TODO.md を用意する

テンプレートは `templates/` ディレクトリにある。これをプロジェクトのルートにコピーして編集する:

```bash
cp templates/PROMPT.md ./PROMPT.md
cp templates/TODO.md ./TODO.md
```

TODO.md にやりたいタスクを書く:

```markdown
# やることリスト

- [ ] ユーザー認証のAPIエンドポイントを作成
- [ ] バリデーションを追加
- [ ] テストを書く
```

### 2. ralph を実行する

```bash
ralph
```

これだけで、TODO.md の全タスクが完了するまで Claude Code がループ実行される。

### 3. オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `--prompt FILE` | 指示書ファイルを指定 | `PROMPT.md` |
| `--todo FILE` | 進捗ファイルを指定 | `TODO.md` |
| `--max N` | 最大繰り返し回数 | `20` |
| `--sleep N` | 周回間の待機秒数 | `60` |
| `--version` | バージョン表示 | - |
| `--help` | ヘルプ表示 | - |

環境変数でも指定可能（引数が優先）:

| 環境変数 | 対応するオプション |
|---|---|
| `PROMPT_FILE` | `--prompt` |
| `TODO_FILE` | `--todo` |
| `MAX_ITERATIONS` | `--max` |
| `SLEEP_SECONDS` | `--sleep` |

### 例

```bash
# タスクを最大10回まで、30秒間隔で実行
ralph --max 10 --sleep 30

# 別のファイル名を使う
ralph --prompt instructions.md --todo tasks.md
```

## 注意事項

- **`--dangerously-skip-permissions` を使用する**: Ralph は Claude Code の権限確認をすべてバイパスして自律実行する。そのため、DevContainer などの隔離された環境でのみ使用すること。
- **git リポジトリ内で使用を推奨**: git 管理下でないディレクトリで実行すると警告が出る。事故時にファイルを元に戻せるよう、git で管理された環境で使うこと。
- **ログは `.ralph-logs/` に保存される**: 各実行のログがタイムスタンプ付きで保存される。
- **Claude Code が必要**: 実行環境に `claude` コマンドがインストールされていること。
- **認証が必要**: Claude Max プランなどで `claude` コマンドが認証済みであること。

## DevContainer での利用

DevContainer 環境で自動インストールするには、`.devcontainer/devcontainer.json` に以下を追加:

```json
{
  "postCreateCommand": ".devcontainer/setup.sh"
}
```

`.devcontainer/setup.sh` を作成:

```bash
#!/bin/bash
set -e
curl -fsSL https://raw.githubusercontent.com/tirano-tirano/ralph-runner/main/install.sh | bash
if ! grep -q '/.local/bin' ~/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi
```

```bash
chmod +x .devcontainer/setup.sh
```

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。
