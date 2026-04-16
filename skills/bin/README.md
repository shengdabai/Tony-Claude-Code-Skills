# bin/ - ユーティリティスクリプト集

このディレクトリには、開発作業を効率化するためのスクリプトが配置されています。

## 📂 ディレクトリ構成

```
bin/
├── clean-old-branches.sh      # 古いGitブランチの安全な削除
├── gwte.sh                    # Git Worktree一括コマンド実行
├── sample-script.sh           # gwte.sh用のテストスクリプト
├── setup-scripts/
│   └── subtree-manager.sh     # Git subtreeの設定駆動管理
└── claude-utils/
    ├── debug-hook.sh          # Claude Codeフックのデバッグ
    └── duration-logic-hooks/  # Claude Codeセッション時間計測
        ├── user-prompt-submit-hook.sh
        ├── agent-in-progress-hook.sh
        └── finished-responding-hook.sh
```

## 🔧 Git管理ツール

### clean-old-branches.sh - 古いブランチの削除

🎯 **用途**: 指定日数より古いローカルブランチを安全に削除する

📋 **使用場面**: 
- ブランチが溜まりすぎてリポジトリが重くなった時
- 定期的なブランチクリーンアップ作業
- マージ済みの古いブランチを一括削除したい時

🚀 **基本的な使い方**:
```bash
./clean-old-branches.sh [days] [--force]
```

💡 **使用例**:
```bash
# 30日より古いブランチを対話的に削除
./clean-old-branches.sh

# 60日より古いブランチを対話的に削除  
./clean-old-branches.sh 60

# 確認なしで強制削除
./clean-old-branches.sh 30 --force
```

⚠️ **注意事項**:
- `main`, `master`, `develop`, `dev`, `staging`, `production`ブランチは保護される
- マージされていないブランチは削除されない（安全機能）
- worktreeでチェックアウト中のブランチは保護される

---

### gwte.sh - Git WorkTree Executor

🎯 **用途**: 複数のGit worktreeに対して同じコマンドを一括実行する

📋 **使用場面**:
- 複数ブランチで同じテストを実行したい時
- 全ワークツリーでビルド状況を確認したい時
- 複数環境での動作確認を一括で行いたい時

🚀 **基本的な使い方**:
```bash
./gwte.sh [OPTIONS]
```

💡 **使用例**:
```bash
# 対話的にworktreeを選択してコマンド実行
./gwte.sh --interactive --command "git status"

# 全worktreeでテスト実行（ドライラン）
./gwte.sh --all --command "npm test" --dry-run

# 全worktreeで実際にビルド実行
./gwte.sh --all --command "npm run build"

# sample-script.shを全worktreeで実行
./gwte.sh --all --command "./bin/sample-script.sh"
```

⚠️ **注意事項**:
- `--all`または`--interactive`のいずれかが必須
- `--dry-run`で事前確認を推奨
- worktreeディレクトリが存在しない場合はエラー

---

### subtree-manager.sh - Git Subtree管理

🎯 **用途**: Git subtreeを設定ファイル駆動で管理する

📋 **使用場面**:
- 外部リポジトリをsubtreeとして取り込みたい時
- subtreeの更新を定期的に行いたい時
- 複数のsubtreeを統一的に管理したい時

🚀 **基本的な使い方**:
```bash
./setup-scripts/subtree-manager.sh <command> [arguments]
```

💡 **使用例**:
```bash
# 設定済みsubtreeの一覧表示
./setup-scripts/subtree-manager.sh list

# 特定のsubtreeを追加
./setup-scripts/subtree-manager.sh add claude-agents-wshobson

# 全subtreeを追加（既存は無視）
./setup-scripts/subtree-manager.sh add-all

# 特定のsubtreeを更新
./setup-scripts/subtree-manager.sh update claude-agents-wshobson

# 全subtreeを更新
./setup-scripts/subtree-manager.sh update-all
```

⚠️ **注意事項**:
- SUBTREE_CONFIGS配列での事前設定が必要
- 設定済みのsubtreeのみ操作可能
- 更新時は上流の変更が自動でマージされる

## 🤖 Claude Code関連ツール

### debug-hook.sh - フックデバッグ

🎯 **用途**: Claude Codeのフック実行時の入力データをJSONファイルに出力してデバッグする

📋 **使用場面**:
- Claude Codeフックが期待通りに動作しない時
- フックに渡されるデータ構造を確認したい時
- フック開発・デバッグ時

🚀 **基本的な使い方**:
```bash
# ~/.claude/CLAUDE.md のhook設定に追加
# user-prompt-submit-hook = "~/dotfiles/bin/claude-utils/debug-hook.sh"
```

💡 **出力ファイル**:
```
debug-claude-hook-{sessionId}.json
```

⚠️ **注意事項**:
- 実行ディレクトリにJSONファイルが作成される
- セッションごとに配列形式で履歴が蓄積される

---

### duration-logic-hooks/ - セッション時間計測

🎯 **用途**: Claude Codeセッションの開始から終了までの時間を計測・記録し、statuslineで表示するためのデータを生成する

📋 **使用場面**:
- Claude Codeの使用時間をstatuslineに表示したい時
- セッション単位の作業時間を記録したい時
- パフォーマンス分析やログ取りが必要な時
- **注意**: 基本的にClaude Code hooks経由でのみ使用し、手動実行することはほぼない

🚀 **基本的な使い方**:
```bash
# ~/.claude/CLAUDE.md のhook設定に追加
# user-prompt-submit-hook = "~/dotfiles/bin/claude-utils/duration-logic-hooks/user-prompt-submit-hook.sh"
# agent-in-progress-hook = "~/dotfiles/bin/claude-utils/duration-logic-hooks/agent-in-progress-hook.sh"
# finished-responding-hook = "~/dotfiles/bin/claude-utils/duration-logic-hooks/finished-responding-hook.sh"
```

💡 **出力ファイル**:
```
${TMPDIR}/claude-code-duration-{sessionId}.json
```

⚠️ **注意事項**:
- 3つのフックスクリプトをセットで設定する必要がある
- 中断されたセッション（interrupt）も正しく処理される
- 時間はUTC形式で記録、ミリ秒単位で計測

## 🧪 テスト・サンプル

### sample-script.sh - テスト用サンプル

🎯 **用途**: gwte.shの動作確認用のサンプルスクリプト

📋 **使用場面**:
- gwte.shが正しく動作するかテストしたい時
- 新しいworktreeでの動作確認
- スクリプトのテンプレートとして使用したい時

🚀 **基本的な使い方**:
```bash
./sample-script.sh
```

💡 **実行内容**:
- 現在のディレクトリパス表示
- 現在日時表示
- 現在のGitブランチ表示
- ディレクトリ内容の表示

## 🔗 関連ドキュメント

- Claude Codeフック: [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- Git subtree: [Git Subtree Manual](https://git-scm.com/docs/git-subtree)
- Git worktree: [Git Worktree Manual](https://git-scm.com/docs/git-worktree)