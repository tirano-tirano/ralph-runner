# Ralph Runner

Claude Code に同じプロンプトを繰り返し実行させ、タスクが完了するまで自動的に作業を続けさせるツール。

Geoffrey Huntley 氏が考案した「Ralph Loop」パターンを、オプション付きのスクリプトとして使いやすくしたもの。

## 仕組み

1. `PROMPT.md`（指示書）と進捗ファイル（`TODO.md` または `docs/features/` の feature ファイル）を用意する
2. `ralph` を実行すると、Claude Code が 1 周ごとに PROMPT.md を読み、進捗ファイルの未完了タスクを 1 つ処理する
3. すべてのタスクが完了（`[x]`）になるとループが自動終了する
4. feature ファイルが複数ある場合は、F-xxx の番号順に自動で順次処理する

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
| `--todo FILE` | 進捗ファイルを指定（省略時は feature 自動検出） | `TODO.md` |
| `--features-dir D` | feature ファイルのディレクトリ | `docs/features` |
| `--todo-pattern P` | 完了判定の grep パターンを指定 | `^- \[ \]` |
| `--max N` | 最大繰り返し回数（feature ファイルごと） | `20` |
| `--sleep N` | 周回間の待機秒数 | `60` |
| `--version` | バージョン表示 | - |
| `--help` | ヘルプ表示 | - |

環境変数でも指定可能（引数が優先）:

| 環境変数 | 対応するオプション |
|---|---|
| `PROMPT_FILE` | `--prompt` |
| `TODO_FILE` | `--todo` |
| `FEATURES_DIR` | `--features-dir` |
| `TODO_PATTERN` | `--todo-pattern` |
| `MAX_ITERATIONS` | `--max` |
| `SLEEP_SECONDS` | `--sleep` |

### 例

```bash
# feature ファイルを自動検出して順次処理（TODO.md 不要）
ralph

# タスクを最大10回まで、30秒間隔で実行
ralph --max 10 --sleep 30

# 別のファイル名を使う
ralph --prompt instructions.md --todo tasks.md

# feature ファイルを1つだけ指定する
ralph --todo docs/features/F-001_user-registration.md

# feature ディレクトリを変更する
ralph --features-dir src/docs/features
```

### feature ファイル連携

ドキュメント駆動開発の feature ファイル（要求・要件・技術仕様・タスクを1ファイルにまとめた形式）を Ralph Loop の進捗ファイルとして直接使える。**TODO.md の代わりに feature ファイルだけで運用可能。**

#### 基本: TODO.md なしで実行

`docs/features/` に feature ファイルを配置して `ralph` を実行するだけ。TODO.md は不要。

```bash
# docs/features/ に feature ファイルがある場合、自動検出して順次処理
ralph
```

Ralph は以下の優先順位で進捗ファイルを決定する:

1. `--todo` で明示指定されたファイル → そのファイルだけ処理
2. `TODO.md` が存在する → 従来通り TODO.md を処理
3. どちらもない → `docs/features/` を自動スキャンして複数 feature を順次処理

#### 複数 feature ファイルの自動処理

`docs/features/` にある feature ファイルは、ファイル名のソート順（= F-xxx の番号順）に自動で処理される。1つの feature の全タスクが完了したら、次の feature に自動的に移行する。

```
docs/features/
├── F-001_user-registration.md    ← 最初に処理
├── F-002_search.md               ← F-001 完了後に処理
├── F-003_notification.md         ← F-002 完了後に処理
└── F-004_admin-dashboard.md      ← status: done ならスキップ
```

以下の feature ファイルはスキップされる:

- frontmatter に `status: done` が設定されているファイル
- 未完了のタスク行（`- [ ] F-xxx-Txx`）がないファイル

起動時のログに処理対象の feature ファイル一覧が表示される:

```
===== Ralph 0.2.0 起動 =====
PROMPT:  PROMPT.md
SLEEP:   60 秒
MODE:    feature ファイル自動検出
DIR:     docs/features
FILES:   3 件の未完了 feature
  - docs/features/F-001_user-registration.md
  - docs/features/F-002_search.md
  - docs/features/F-003_notification.md
```

#### feature ファイル1つだけ指定する場合

従来通り `--todo` で1ファイルを指定することもできる:

```bash
ralph --todo docs/features/F-001_user-registration.md
```

#### 完了判定

feature ファイル内に `- [ ] F-xxx-Txx` 形式のタスク行が見つかると、タスク行のみを完了判定の対象にする。要求・要件セクションのチェックボックスは追跡用として無視される。

#### feature ディレクトリの変更

デフォルトは `docs/features` だが、`--features-dir` で変更できる:

```bash
ralph --features-dir src/docs/features
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
