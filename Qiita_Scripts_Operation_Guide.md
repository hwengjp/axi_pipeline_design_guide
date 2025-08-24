# Qiita用スクリプト運用ガイド

## 概要

このドキュメントは、AXIバス設計ガイドのQiita記事を管理するためのスクリプト群の使用方法を説明します。

## スクリプト一覧

### 1. 既存スクリプト

#### `update_qiita_articles.py`
- **目的**: 全ファイルの一括更新
- **特徴**: ファイルの修正の有無に関わらず、すべてのファイルを更新
- **用途**: 初回セットアップ、全ファイルの同期が必要な場合

#### `publish_to_qiita.sh`
- **目的**: 指定されたファイルをQiitaにpublish
- **特徴**: 個別ファイルのpublish処理
- **用途**: 特定ファイルのpublishが必要な場合

### 2. 新規スクリプト

#### `smart_update_qiita.py`
- **目的**: 変更されたファイルのみの選択的更新
- **特徴**: ファイル比較による変更検出、自動publish
- **用途**: 日常的な更新作業、効率的な管理

#### `smart_publish_to_qiita.sh`
- **目的**: Smart Updateスクリプトの実行と制御
- **特徴**: オプション制御、エラーハンドリング、ログ管理
- **用途**: Smart Updateスクリプトの実行制御

#### `qiita_update_config.yaml`
- **目的**: Smart Updateスクリプトの設定
- **特徴**: YAML形式の設定ファイル
- **用途**: スクリプトの動作カスタマイズ

## 使用方法

### 基本的な運用フロー

#### 1. 全ファイル更新（初回・全同期時）
```bash
# 全ファイルを更新
python3 update_qiita_articles.py

# 特定ファイルをpublish
./publish_to_qiita.sh QiitaDocs/public/part01_pipeline_principles.md
```

#### 2. 変更ファイルのみ更新（日常運用）
```bash
# 変更されたファイルのみを更新・publish
./smart_publish_to_qiita.sh

# 確認のみ実行（dry-run）
./smart_publish_to_qiita.sh --dry-run

# 更新のみ実行（publishなし）
./smart_publish_to_qiita.sh --no-publish
```

### 詳細な使用方法

#### `update_qiita_articles.py`
```bash
# 基本的な実行
python3 update_qiita_articles.py

# ヘルプ表示
python3 update_qiita_articles.py --help
```

**処理内容**:
1. QiitaDocs/public内のpart*.md、rule*.mdファイルを検索
2. 対応するルートディレクトリのファイルと比較
3. すべてのファイルを更新（変更の有無に関わらず）

#### `smart_update_qiita.py`
```bash
# デフォルト設定で実行
python3 smart_update_qiita.py

# カスタム設定ファイルで実行
python3 smart_update_qiita.py my_config.yaml
```

**処理内容**:
1. 対象ファイルの検索
2. ヘッダを除いた本文の比較（MD5ハッシュ）
3. 変更されたファイルのみを更新
4. 自動バックアップ作成
5. 自動publish実行

#### `smart_publish_to_qiita.sh`
```bash
# 基本的な実行
./smart_publish_to_qiita.sh

# オプション付き実行
./smart_publish_to_qiita.sh --dry-run --verbose

# バックアップのみ実行
./smart_publish_to_qiita.sh --backup-only
```

**オプション**:
- `-h, --help`: ヘルプ表示
- `-c, --config FILE`: 設定ファイル指定
- `-d, --dry-run`: 確認のみ実行
- `-v, --verbose`: 詳細ログ出力
- `--no-publish`: publish実行なし
- `--backup-only`: バックアップのみ

## 設定ファイル

### `qiita_update_config.yaml`

#### 基本設定
```yaml
# ディレクトリ設定
directories:
  qiita_dir: "QiitaDocs/public"    # Qiitaファイルの場所
  git_dir: "."                      # Gitファイルの場所

# 対象ファイルパターン
file_patterns:
  - "part*.md"                      # partで始まるMarkdownファイル
  - "rule*.md"                      # ruleで始まるMarkdownファイル
```

#### 比較設定
```yaml
# 比較方法の設定
comparison:
  ignore_headers: true              # ヘッダ部分を比較から除外
  ignore_whitespace: true           # 空白文字の違いを無視
  ignore_line_endings: true         # 改行コードの違いを無視
```

#### 更新設定
```yaml
# 更新処理の設定
update:
  backup_enabled: true              # バックアップを作成するか
  backup_dir: "QiitaDocs/backup"   # バックアップディレクトリ
```

#### Publish設定
```yaml
# Publish処理の設定
publish:
  auto_publish: true               # 更新後に自動publishするか
  publish_delay: 5                 # publish実行前の待機時間（秒）
```

#### ログ設定
```yaml
# ログ出力の設定
logging:
  level: "INFO"                    # ログレベル
  file: "smart_qiita_update.log"   # ログファイル名
  console_output: true             # コンソール出力するか
```

## 運用シナリオ

### シナリオ1: 初回セットアップ
```bash
# 1. 全ファイルを更新
python3 update_qiita_articles.py

# 2. 個別にpublish
./publish_to_qiita.sh QiitaDocs/public/part01_pipeline_principles.md
./publish_to_qiita.sh QiitaDocs/public/part02_pipeline_insert.md
# ... 他のファイルも同様
```

### シナリオ2: 日常的な更新
```bash
# 変更されたファイルのみを更新・publish
./smart_publish_to_qiita.sh
```

### シナリオ3: 安全な更新（確認付き）
```bash
# 1. 確認のみ実行
./smart_publish_to_qiita.sh --dry-run --verbose

# 2. 問題なければ実際に実行
./smart_publish_to_qiita.sh
```

### シナリオ4: バックアップのみ
```bash
# 現在のQiitaファイルをバックアップ
./smart_publish_to_qiita.sh --backup-only
```

## トラブルシューティング

### よくある問題と対処法

#### 1. Pythonパッケージの不足
```bash
# エラー: PyYAMLパッケージがインストールされていません
pip3 install PyYAML
```

#### 2. 権限の問題
```bash
# スクリプトに実行権限を付与
chmod +x smart_publish_to_qiita.sh
chmod +x publish_to_qiita.sh
```

#### 3. 設定ファイルの問題
```bash
# 設定ファイルの構文チェック
python3 -c "import yaml; yaml.safe_load(open('qiita_update_config.yaml'))"
```

#### 4. ログファイルの確認
```bash
# ログファイルの内容確認
tail -f smart_qiita_update.log
```

### ログレベルの変更

設定ファイルでログレベルを変更できます：
```yaml
logging:
  level: "DEBUG"  # DEBUG, INFO, WARNING, ERROR
```

## ファイル構成

```
.
├── update_qiita_articles.py          # 既存: 全ファイル更新スクリプト
├── publish_to_qiita.sh              # 既存: publishスクリプト
├── smart_update_qiita.py            # 新規: 選択的更新スクリプト
├── smart_publish_to_qiita.sh        # 新規: Smart Update実行スクリプト
├── qiita_update_config.yaml         # 新規: 設定ファイル
├── QiitaDocs/
│   ├── public/                      # Qiita用ファイル
│   │   ├── part01_pipeline_principles.md
│   │   ├── part02_pipeline_insert.md
│   │   └── ...
│   └── backup/                      # バックアップファイル（自動生成）
└── smart_qiita_update.log           # ログファイル（自動生成）
```

## ベストプラクティス

### 1. 日常運用
- **変更検出**: `smart_publish_to_qiita.sh`を使用
- **確認作業**: `--dry-run`オプションで事前確認
- **ログ管理**: ログファイルの定期的な確認

### 2. 安全な運用
- **バックアップ**: 更新前の自動バックアップ
- **段階的実行**: まず確認、次に実行
- **エラーハンドリング**: エラー時の適切な対処

### 3. 効率的な運用
- **選択的更新**: 変更されたファイルのみ処理
- **自動化**: 更新→publishの自動実行
- **設定管理**: YAMLファイルによる柔軟な設定

## まとめ

このスクリプト群により、Qiita記事の管理が効率化され、安全で確実な更新作業が可能になります。

- **既存スクリプト**: 全ファイル更新、個別publish
- **新規スクリプト**: 選択的更新、自動publish、設定管理
- **運用**: 初回セットアップ、日常更新、トラブル対応

適切なスクリプトを選択して、効率的なQiita記事管理を実現してください。
