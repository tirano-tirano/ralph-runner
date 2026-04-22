# Ralph Runner

Claude Code に同じプロンプトを繰り返し実行させ、タスクが完了するまで自動的に作業を続けさせるツール。

Geoffrey Huntley 氏が考案した「Ralph Loop」パターンを、オプション付きのスクリプトとして使いやすくしたもの。

## 仕組み

1. `PROMPT.md`（指示書）と進捗ファイル（`TODO.md`、`docs/features/` の feature ファイルなど）を用意する
2. `ralph` を実行すると、Claude Code が 1 周ごとに PROMPT.md を読み、進捗ファイルの未完了タスクを 1 つ処理する
3. すべての対象ファイルのタスクが完了（`[x]`）になるとループが自動終了する
4. 対象ファイルは PROMPT.md 内の `ralph-config` 設定で柔軟に指定できる（ディレクトリ単位、個別ファイル単位、除外ディレクトリ）

毎回新しい Claude Code プロセスが起動するため、コンテキストが肥大化しない。状態は進捗ファイルや SCRATCH.md などの外部ファイルで引き継ぐ。

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

これだけで、ralph-config で指定された全対象ファイルのタスクが完了するまで Claude Code がループ実行される。

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
| `--todo FILE` | 進捗ファイルを指定（複数回指定可。省略時は ralph-config で自動検出） | - |
| `--todo-pattern P` | 完了判定の grep パターンを指定 | `^- \[ \]` |
| `--max N` | 最大繰り返し回数（全ファイル合計） | `50` |
| `--sleep N` | 周回間の待機秒数 | `60` |
| `--version` | バージョン表示 | - |
| `--help` | ヘルプ表示 | - |

環境変数でも指定可能（引数が優先）:

| 環境変数 | 対応するオプション |
|---|---|
| `PROMPT_FILE` | `--prompt` |
| `TODO_PATTERN` | `--todo-pattern` |
| `MAX_ITERATIONS` | `--max` |
| `SLEEP_SECONDS` | `--sleep` |

### 例

```bash
# ralph-config に従って対象ファイルを自動検出し、順次処理
ralph

# 特定のファイルだけ処理（ralph-config を無視）
ralph --todo docs/features/F-001_user-registration.md

# 複数ファイルを明示指定
ralph --todo docs/features/F-001_user-registration.md --todo docs/features/F-002_search.md

# 最大10回まで、30秒間隔で実行
ralph --max 10 --sleep 30

# 別の指示書ファイルを使う
ralph --prompt instructions.md
```

### ralph-config（対象ファイルの設定）

PROMPT.md の `# このプロジェクト固有のルール` セクション内に、`<!-- ralph-config -->` 構造化コメントを記述することで、Ralph が処理する対象ファイルを柔軟に設定できる。

```markdown
<!-- ralph-config
TODO_DIRS=docs/features docs/nfr
TODO_FILES=docs/architecture.md
EXCLUDE_DIRS=docs/legacy docs/notes
-->
```

| 設定項目 | 説明 | 例 |
|---|---|---|
| `TODO_DIRS` | スキャン対象ディレクトリ（スペース区切り、再帰的にスキャン） | `docs/features docs/nfr` |
| `TODO_FILES` | 個別の対象ファイル（スペース区切り） | `TODO.md docs/architecture.md` |
| `EXCLUDE_DIRS` | 除外ディレクトリ（スペース区切り） | `docs/legacy docs/notes` |

`ralph init` の AI モードを使うと、プロジェクトを調査したうえで ralph-config を自動生成してくれる。

#### 対象ファイルの決定順序

Ralph は以下の優先順位で処理対象を決定する:

1. `--todo` で明示指定されたファイル → そのファイルだけ処理（ralph-config は無視）
2. `--todo` 未指定 → PROMPT.md 内の ralph-config を解析して自動検出

自動検出では、`TODO_DIRS` 内の `.md` ファイルと `TODO_FILES` で指定された個別ファイルを収集し、`EXCLUDE_DIRS` に該当するものを除外する。さらに以下の条件でスキップされる:

- frontmatter に `status: done` が設定されているファイル
- 未完了のタスク行（`- [ ]`）がないファイル

#### feature ファイル連携

ドキュメント駆動開発の feature ファイル（要求・要件・技術仕様・タスクを1ファイルにまとめた形式）を Ralph Loop の進捗ファイルとして直接使える。

```
docs/features/
├── F-001_user-registration.md    ← 最初に処理
├── F-002_search.md               ← F-001 完了後に処理
├── F-003_notification.md         ← F-002 完了後に処理
└── F-004_admin-dashboard.md      ← status: done ならスキップ
```

feature ファイル内に `- [ ] F-xxx-Txx` 形式のタスク行がある場合、そのタスク行のみが完了判定の対象になる。要求・要件セクションのチェックボックスは追跡用として無視される。

#### 繰り返し回数

`--max`（デフォルト: 50）は**全ファイル合計**でカウントされる。たとえば `--max 50` の場合、F-001 で 30 回、F-002 で 20 回使うと上限に達してループが終了する。

## ralph-init スキルについて

`ralph init` で `Y` を選ぶと、Claude Code の対話セッションが起動し、`ralph-init` スキルが走る。このスキルは3つのモードを持つ:

- **新規モード**: プロジェクトを調査 → 質問 → `PROMPT.md`（ralph-config 含む）と `TODO.md` を提案 → 承認後に書き出し
- **サイクル継続モード**: `.ralph-archive/` の前サイクル成果を読んで、次サイクルの `TODO.md` を対話で作成（`PROMPT.md` は触らない）
- **引き継ぎモード**: 未完了タスクを整理して新 `TODO.md` を作成（`PROMPT.md` は触らない）

新規モードでは、プロジェクト内のタスクファイル（`docs/features/`、`docs/nfr/` など）を自動探索し、ralph-config 構造化コメントの草案を提示する。どのモードでも、`PROMPT.md` の骨格（参照ファイル・手順・制約）はスキルが触らないため、Ralph Loop の動作は保たれる。

スキルのインストール先は環境変数 `RALPH_SKILL_DIR` で指定できる（デフォルト: `$HOME/.claude/skills/ralph-init`）。DevContainer ではプロジェクト内に配置するのが推奨（後述）。

## 注意事項

- **`--dangerously-skip-permissions` を使用する**: Ralph は Claude Code の権限確認をすべてバイパスして自律実行する。そのため、DevContainer などの隔離された環境でのみ使用すること。
- **git リポジトリ内で使用を推奨**: git 管理下でないディレクトリで実行すると警告が出る。事故時にファイルを元に戻せるよう、git で管理された環境で使うこと。
- **ログは `.ralph-logs/` に保存される**: 各実行のログがタイムスタンプ付きで保存される。
- **Claude Code が必要**: 実行環境に `claude` コマンドがインストールされていること。`ralph init` の AI モードも claude を使う。
- **認証が必要**: Claude Max プランなどで `claude` コマンドが認証済みであること。
- **非対話環境での `ralph init`**: パイプ経由など非対話で実行した場合、AI プロンプトは出ずに固定テンプレートのみが書き出される。

## DevContainer での利用

DevContainer 環境では、コンテナ作成時に自動で ralph 本体とスキルをインストールできます。

### 配置方針（プロジェクトレベル）

- **ralph 本体**: `$HOME/.local/bin/ralph`（コンテナ内。コンテナ再作成のたびに post-create で入れ直す）
- **ralph-init スキル**: `<ワークスペース>/.claude/skills/ralph-init/SKILL.md`（ホストからマウントされているので、コンテナ再作成しても消えない）

これにより、スキルはプロジェクトごとに独立したものになり、VSCode のファイルツリーにも表示されます。

### 手順

`.devcontainer/devcontainer.json` に次を追加:

```json
{
  "postCreateCommand": ".devcontainer/post-create.sh"
}
```

`.devcontainer/post-create.sh` を作成:

```bash
#!/bin/bash
set -e

# ralph-init スキルをワークスペース（プロジェクト）配下に配置する
RALPH_SKILL_DIR="$PWD/.claude/skills/ralph-init" \
  curl -fsSL https://raw.githubusercontent.com/tirano-tirano/ralph-runner/main/install.sh | bash

# PATH に ~/.local/bin を追加
if ! grep -q '/.local/bin' ~/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi
```

```bash
chmod +x .devcontainer/post-create.sh
```

`postCreateCommand` はコンテナ作成直後にワークスペースルートで実行されるため、`$PWD` がそのままプロジェクトルートになります。

### `.gitignore` への追加（推奨）

スキル本体は install.sh が毎回最新版を取得するため、git にはコミットしないのが推奨です。

```gitignore
# ralph-init スキル本体（post-create.sh で自動取得）
.claude/skills/ralph-init/
```

### 既存のインストールを持つ環境のクリーンアップ

以前のバージョンでは `$HOME/.claude/skills/ralph-init/` にインストールしていました。プロジェクトレベル方式に切り替える場合、古いインストールは削除して問題ありません。

```bash
rm -rf "$HOME/.claude/skills/ralph-init"
```

削除しなくても動作に支障はありませんが、同じ名前のスキルが2箇所に存在すると、プロジェクト側が優先される挙動になります。

### 注意: ralph の実行場所

`ralph` と `ralph init` は、生成物（`PROMPT.md`, `TODO.md`, `SCRATCH.md`, `.ralph-archive/`, `.ralph-logs/`）をすべてカレントディレクトリ（相対パス）に書き出します。

DevContainer では、**ホストからマウントされたプロジェクトディレクトリ内で `ralph` を実行してください**。`$HOME` や `/tmp` などコンテナ内のみのパスで実行すると、コンテナを作り直したときに生成物が失われます。

```bash
# 良い例: ホストにマウントされたプロジェクト内
cd /workspaces/my-project
ralph init
ralph

# 悪い例: コンテナ内にしか存在しない場所
cd /tmp
ralph init  # → /tmp/TODO.md はコンテナ再作成時に消える
```

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。
