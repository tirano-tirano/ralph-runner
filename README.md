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

インストーラは以下の2つを配置する:

- `ralph` 本体 → `$HOME/.local/bin/ralph`
- `ralph-init` スキル → `$HOME/.claude/skills/ralph-init/SKILL.md`

PATH が通っていない場合は、以下を `~/.bashrc` に追加:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

インストール先を変えたい場合は環境変数で指定:

| 環境変数 | 用途 | デフォルト |
|---|---|---|
| `RALPH_INSTALL_DIR` | `ralph` コマンドの配置先 | `$HOME/.local/bin` |
| `RALPH_SKILL_DIR` | `ralph-init` スキルの配置先 | `$HOME/.claude/skills/ralph-init` |

```bash
RALPH_INSTALL_DIR=/usr/local/bin curl -fsSL .../install.sh | bash
```

## 使い方

### 1. プロジェクトに PROMPT.md と TODO.md を用意する

プロジェクトのルートで `ralph init` を実行する:

```bash
cd my-project
ralph init
```

`ralph init` はディレクトリの状態を自動判定して、4パターンのいずれかで動く。

#### パターンI: 初回（PROMPT.md も TODO.md もない）

```
AI で生成しますか？(Y/n):
```

**Y（またはEnter）**: Claude Code が起動。`ralph-init` スキルが走って、プロジェクトを調査して質問してから `PROMPT.md` と `TODO.md` を生成する。

**n**: 固定テンプレが書き出される。`TODO.md` を手で編集する。

#### パターンII: 前サイクル完了（全タスク `[x]`）

前サイクルの `TODO.md` と `SCRATCH.md` が `.ralph-archive/` にタイムスタンプ付きで移動される。そのあと:

```
AI で次サイクルの TODO.md を作成しますか？(Y/n):
```

**Y**: Claude Code が起動。`.ralph-archive/` の最新アーカイブを読んで、次サイクルで取り組むタスクを対話で決める。`PROMPT.md` は触らない。

**n**: 固定テンプレの `TODO.md` が書き出される。

#### パターンIII: `PROMPT.md` だけある（`TODO.md` がない）

パターンII と同じ動作。

#### パターンIV: 未完了タスクが残っている状態

```
未完了タスクが 3 件残っています。
  (1) 新しい TODO.md に引き継ぐ
  (2) そのままアーカイブして新規作成
  (3) 中止
選択 [1/2/3]:
```

- **(1) 引き継ぎ**: 現 `TODO.md` のスナップショットを `.ralph-archive/TODO-*-inherited.md` に保存。AI が未完了タスクを整理して新 `TODO.md` を作る。
- **(2) アーカイブ**: パターンII と同じ動作。未完了含めてアーカイブ。
- **(3) 中止**: 何もせず終了。

どのパターンでも最後に `.gitignore` に `.ralph-archive/` / `.ralph-logs/` を追加するか確認される。

### 2. ralph を実行する

```bash
ralph
```

これだけで、TODO.md の全タスクが完了するまで Claude Code がループ実行される。

### 運用サイクル

1サイクル終わったら、同じコマンドで次に進める:

```
ralph init → ralph → （完了） → ralph init → ralph → ...
```

`ralph init` は前サイクルの成果物を `.ralph-archive/` に残すので、後から履歴を追える。

### 3. オプション

| サブコマンド / オプション | 説明 | デフォルト |
|---|---|---|
| `init` | `PROMPT.md` と `TODO.md` を生成（対話で AI/固定テンプレを選択）| - |
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

## ralph-init スキルについて

`ralph init` で `Y` を選ぶと、Claude Code の対話セッションが起動し、`ralph-init` スキルが走る。このスキルは3つのモードを持つ:

- **新規モード**: プロジェクトを調査 → 質問 → `PROMPT.md` と `TODO.md` を提案 → 承認後に書き出し
- **サイクル継続モード**: `.ralph-archive/` の前サイクル成果を読んで、次サイクルの `TODO.md` を対話で作成（`PROMPT.md` は触らない）
- **引き継ぎモード**: 未完了タスクを整理して新 `TODO.md` を作成（`PROMPT.md` は触らない）

どのモードでも、`PROMPT.md` の骨格（手順・制約）はスキルが触らないため、Ralph Loop の動作は保たれる。

スキルは `$HOME/.claude/skills/ralph-init/SKILL.md` に配置される。手動で更新したい場合はこのファイルを編集する。

## 注意事項

- **`--dangerously-skip-permissions` を使用する**: Ralph は Claude Code の権限確認をすべてバイパスして自律実行する。そのため、DevContainer などの隔離された環境でのみ使用すること。
- **git リポジトリ内で使用を推奨**: git 管理下でないディレクトリで実行すると警告が出る。事故時にファイルを元に戻せるよう、git で管理された環境で使うこと。
- **ログは `.ralph-logs/` に保存される**: 各実行のログがタイムスタンプ付きで保存される。
- **Claude Code が必要**: 実行環境に `claude` コマンドがインストールされていること。`ralph init` の AI モードも claude を使う。
- **認証が必要**: Claude Max プランなどで `claude` コマンドが認証済みであること。
- **非対話環境での `ralph init`**: パイプ経由など非対話で実行した場合、AI プロンプトは出ずに固定テンプレートのみが書き出される。

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
