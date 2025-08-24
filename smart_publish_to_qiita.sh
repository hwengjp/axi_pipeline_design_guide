#!/bin/bash

# Smart Qiita Update & Publish スクリプト
# このスクリプトは、ファイルの修正があった時のみQiitaのファイルを
# アップデートしてpublishします。

set -e  # エラー時に終了

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 設定
CONFIG_FILE="qiita_update_config.yaml"
LOG_FILE="smart_qiita_update.log"
BACKUP_DIR="QiitaDocs/backup"

# 色付き出力用の関数
print_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

print_success() {
    echo -e "\033[36m[SUCCESS]\033[0m $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
Smart Qiita Update & Publish Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -c, --config FILE   設定ファイルを指定（デフォルト: qiita_update_config.yaml）
    -d, --dry-run       実際の更新を行わず確認のみ
    -v, --verbose       詳細なログを出力
    --no-publish        publishを実行しない
    --backup-only       バックアップのみ実行

例:
    $0                    # デフォルト設定で実行
    $0 -c my_config.yaml # カスタム設定ファイルで実行
    $0 --dry-run         # 確認のみ実行
    $0 --no-publish      # 更新のみ実行（publishなし）

EOF
}

# 引数解析
DRY_RUN=false
VERBOSE=false
NO_PUBLISH=false
BACKUP_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-publish)
            NO_PUBLISH=true
            shift
            ;;
        --backup-only)
            BACKUP_ONLY=true
            shift
            ;;
        *)
            print_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 設定ファイルの存在確認
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "設定ファイルが見つかりません: $CONFIG_FILE"
    exit 1
fi

# Pythonの存在確認
if ! command -v python3 &> /dev/null; then
    print_error "Python3がインストールされていません"
    exit 1
fi

# 必要なPythonパッケージの確認
python3 -c "import yaml" 2>/dev/null || {
    print_error "PyYAMLパッケージがインストールされていません"
    print_info "インストール方法: pip3 install PyYAML"
    exit 1
}

# ログ開始
print_info "Smart Qiita Update & Publish 開始"
print_info "設定ファイル: $CONFIG_FILE"
print_info "作業ディレクトリ: $(pwd)"

# 設定ファイルの内容を表示（verboseモード）
if [[ "$VERBOSE" == true ]]; then
    print_info "設定ファイルの内容:"
    cat "$CONFIG_FILE" | sed 's/^/  /'
    echo
fi

# バックアップディレクトリの作成
if [[ "$BACKUP_ONLY" == true ]]; then
    print_info "バックアップのみ実行モード"
    mkdir -p "$BACKUP_DIR"
    
    # Qiitaファイルのバックアップ
    for file in QiitaDocs/public/part*.md QiitaDocs/public/rule*.md; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            timestamp=$(date +"%Y%m%d_%H%M%S")
            backup_file="$BACKUP_DIR/${filename%.*}_${timestamp}.md"
            cp "$file" "$backup_file"
            print_info "バックアップ作成: $backup_file"
        fi
    done
    
    print_success "バックアップ完了"
    exit 0
fi

# 設定ファイルの一時的な修正（オプションに応じて）
TEMP_CONFIG=$(mktemp)
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# dry-runモードの設定
if [[ "$DRY_RUN" == true ]]; then
    print_info "DRY-RUNモード: 実際の更新は行いません"
    # 設定ファイルを一時的に修正（dry-run用）
    sed -i 's/backup_enabled: true/backup_enabled: false/' "$TEMP_CONFIG"
fi

# publish無効化の設定
if [[ "$NO_PUBLISH" == true ]]; then
    print_info "Publish無効化モード: publishは実行しません"
    sed -i 's/auto_publish: true/auto_publish: false/' "$TEMP_CONFIG"
fi

# Smart Qiita Updateスクリプトの実行
print_info "Smart Qiita Updateスクリプトを実行中..."
if python3 smart_update_qiita.py "$TEMP_CONFIG"; then
    print_success "Smart Qiita Update完了"
else
    print_error "Smart Qiita Updateでエラーが発生しました"
    rm -f "$TEMP_CONFIG"
    exit 1
fi

# 一時設定ファイルの削除
rm -f "$TEMP_CONFIG"

# ログファイルの確認
if [[ -f "$LOG_FILE" ]]; then
    print_info "ログファイル: $LOG_FILE"
    if [[ "$VERBOSE" == true ]]; then
        print_info "ログの内容:"
        tail -20 "$LOG_FILE" | sed 's/^/  /'
    fi
fi

# バックアップファイルの確認
if [[ -d "$BACKUP_DIR" ]] && [[ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
    print_info "作成されたバックアップファイル:"
    ls -la "$BACKUP_DIR" | sed 's/^/  /'
fi

print_success "Smart Qiita Update & Publish 完了"
print_info "処理結果の詳細はログファイルを確認してください: $LOG_FILE"
