#!/usr/bin/env python3
"""
Smart Qiita Update Script

このスクリプトは、ファイルの修正があった時のみQiitaのファイルを
アップデートしてpublishします。
QiitaDocs/publicのpart*.md、rule*.mdとカレントフォルダの同名のファイルの
ヘッダを除いた本文を比較して、変更があったファイルのみを処理します。
"""

import os
import re
import sys
import yaml
import hashlib
import subprocess
from pathlib import Path
from datetime import datetime
import logging

class SmartQiitaUpdater:
    def __init__(self, config_file="qiita_update_config.yaml"):
        """初期化"""
        self.config = self.load_config(config_file)
        self.setup_logging()
        self.qiita_dir = Path(self.config.get('directories', {}).get('qiita_dir', 'QiitaDocs/public'))
        self.git_dir = Path(self.config.get('directories', {}).get('git_dir', '.'))
        
    def load_config(self, config_file):
        """設定ファイルを読み込む"""
        default_config = {
            'directories': {
                'qiita_dir': 'QiitaDocs/public',
                'git_dir': '.'
            },
            'file_patterns': ['part*.md', 'rule*.md'],
            'comparison': {
                'ignore_headers': True,
                'ignore_whitespace': True,
                'ignore_line_endings': True
            },
            'update': {
                'backup_enabled': True,
                'backup_dir': 'QiitaDocs/backup'
            },
            'publish': {
                'auto_publish': True,
                'publish_delay': 1
            },
            'logging': {
                'level': 'INFO',
                'file': 'smart_qiita_update.log',
                'console_output': True
            }
        }
        
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    user_config = yaml.safe_load(f)
                    # デフォルト設定とユーザー設定をマージ
                    self.merge_config(default_config, user_config)
            except Exception as e:
                print(f"設定ファイルの読み込みエラー: {e}")
                print("デフォルト設定を使用します")
        
        return default_config
    
    def merge_config(self, default, user):
        """設定をマージする"""
        for key, value in user.items():
            if key in default and isinstance(default[key], dict) and isinstance(value, dict):
                self.merge_config(default[key], value)
            else:
                default[key] = value
    
    def setup_logging(self):
        """ログ設定"""
        log_config = self.config.get('logging', {})
        log_level = getattr(logging, log_config.get('level', 'INFO').upper())
        
        # ログフォーマット
        formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        )
        
        # ファイルハンドラー
        if log_config.get('file'):
            file_handler = logging.FileHandler(log_config['file'], encoding='utf-8')
            file_handler.setFormatter(formatter)
            logging.getLogger().addHandler(file_handler)
        
        # コンソールハンドラー
        if log_config.get('console_output', True):
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(formatter)
            logging.getLogger().addHandler(console_handler)
        
        logging.getLogger().setLevel(log_level)
    
    def find_target_files(self):
        """対象ファイルを検索"""
        target_files = []
        
        for pattern in self.config.get('file_patterns', ['part*.md', 'rule*.md']):
            files = list(self.qiita_dir.glob(pattern))
            target_files.extend(files)
        
        return sorted(target_files)
    
    def extract_body_content(self, file_path):
        """ファイルからヘッダを除いた本文を抽出"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Qiitaヘッダを除去
            if file_path.parent == self.qiita_dir:
                # Qiitaファイルの場合
                lines = content.split('\n')
                body_start = -1
                header_count = 0
                
                for i, line in enumerate(lines):
                    if line.strip() == '---':
                        header_count += 1
                        if header_count == 2:
                            body_start = i + 1
                            break
                
                if body_start != -1:
                    body = '\n'.join(lines[body_start:])
                else:
                    body = content
            else:
                # Gitファイルの場合
                lines = content.split('\n')
                body_start = -1
                
                for i, line in enumerate(lines):
                    if line.strip().startswith('# '):
                        body_start = i + 1
                        break
                
                if body_start != -1:
                    body = '\n'.join(lines[body_start:])
                else:
                    body = content
            
            return body.strip()
            
        except Exception as e:
            logging.error(f"ファイル読み込みエラー {file_path}: {e}")
            return None
    
    def normalize_content(self, content):
        """コンテンツを正規化（空白、改行コードの統一）"""
        if not content:
            return ""
        
        # 改行コードを統一
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        
        # 空白文字の正規化
        if self.config.get('comparison', {}).get('ignore_whitespace', True):
            # 行末の空白を削除
            lines = [line.rstrip() for line in content.split('\n')]
            content = '\n'.join(lines)
        
        return content
    
    def calculate_content_hash(self, content):
        """コンテンツのハッシュ値を計算"""
        normalized = self.normalize_content(content)
        return hashlib.md5(normalized.encode('utf-8')).hexdigest()
    
    def has_content_changed(self, qiita_file, git_file):
        """コンテンツに変更があるかを確認"""
        qiita_body = self.extract_body_content(qiita_file)
        git_body = self.extract_body_content(git_file)
        
        if qiita_body is None or git_body is None:
            return False
        
        qiita_hash = self.calculate_content_hash(qiita_body)
        git_hash = self.calculate_content_hash(git_body)
        
        return qiita_hash != git_hash
    
    def backup_qiita_file(self, qiita_file):
        """Qiitaファイルをバックアップ"""
        if not self.config.get('update', {}).get('backup_enabled', True):
            return True
        
        try:
            backup_dir = Path(self.config.get('update', {}).get('backup_dir', 'QiitaDocs/backup'))
            backup_dir.mkdir(parents=True, exist_ok=True)
            
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_file = backup_dir / f"{qiita_file.stem}_{timestamp}{qiita_file.suffix}"
            
            import shutil
            shutil.copy2(qiita_file, backup_file)
            logging.info(f"バックアップ作成: {backup_file}")
            return True
            
        except Exception as e:
            logging.error(f"バックアップ作成エラー: {e}")
            return False
    
    def update_qiita_file(self, qiita_file, git_file):
        """Qiitaファイルを更新"""
        try:
            # バックアップ作成
            if not self.backup_qiita_file(qiita_file):
                return False
            
            # 既存のQiitaヘッダを抽出
            with open(qiita_file, 'r', encoding='utf-8') as f:
                qiita_content = f.read()
            
            # ヘッダ部分を抽出
            lines = qiita_content.split('\n')
            header_lines = []
            header_end = -1
            header_count = 0
            
            for i, line in enumerate(lines):
                if line.strip() == '---':
                    header_count += 1
                    header_lines.append(line)
                    if header_count == 2:
                        header_end = i
                        break
                elif header_count > 0:
                    header_lines.append(line)
            
            if header_end == -1:
                logging.error(f"Qiitaヘッダが見つかりません: {qiita_file}")
                return False
            
            # Gitファイルからタイトルを抽出
            with open(git_file, 'r', encoding='utf-8') as f:
                git_content = f.read()
            
            title_match = re.search(r'^# (.+)$', git_content, re.MULTILINE)
            if not title_match:
                logging.error(f"タイトルが見つかりません: {git_file}")
                return False
            
            title = title_match.group(1)
            
            # ヘッダを更新
            header = '\n'.join(header_lines)
            updated_header = self.update_qiita_header(header, title)
            
            # Gitファイルの本文からタイトルを削除
            git_body = self.remove_title_from_body(git_content)
            
            # 新しい内容を作成
            new_content = updated_header + '\n' + git_body
            
            # ファイルを更新
            with open(qiita_file, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            logging.info(f"更新完了: {qiita_file}")
            return True
            
        except Exception as e:
            logging.error(f"更新エラー {qiita_file}: {e}")
            return False
    
    def update_qiita_header(self, header, title):
        """Qiitaヘッダを更新"""
        lines = header.split('\n')
        new_lines = []
        title_updated = False
        tags_updated = False
        in_tags_section = False
        
        for line in lines:
            if line.strip() == '---':
                new_lines.append(line)
            elif line.strip().startswith('title:'):
                new_lines.append(f'title: {title}')
                title_updated = True
            elif line.strip().startswith('tags:'):
                new_lines.append('tags:')
                new_lines.append('  - Verilog')
                new_lines.append('  - FPGA')
                new_lines.append('  - AXI')
                new_lines.append('  - テストベンチ')
                new_lines.append('  - ハードウェア設計')
                tags_updated = True
                in_tags_section = True
            elif in_tags_section and (line.strip().startswith('  - ') or line.strip().startswith('- ')):
                continue
            elif in_tags_section and not (line.strip().startswith('  - ') or line.strip().startswith('- ')):
                in_tags_section = False
                new_lines.append(line)
            else:
                new_lines.append(line)
        
        # titleが更新されていない場合は追加
        if not title_updated:
            for i, line in enumerate(new_lines):
                if line.strip() == '---':
                    new_lines.insert(i + 1, f'title: {title}')
                    break
        
        # tagsが更新されていない場合は追加
        if not tags_updated:
            for i, line in enumerate(new_lines):
                if line.strip().startswith('title:'):
                    new_lines.insert(i + 1, 'tags:')
                    new_lines.insert(i + 2, '  - Verilog')
                    new_lines.insert(i + 3, '  - FPGA')
                    new_lines.insert(i + 4, '  - AXI')
                    new_lines.insert(i + 5, '  - テストベンチ')
                    new_lines.insert(i + 6, '  - ハードウェア設計')
                    break
        
        return '\n'.join(new_lines)
    
    def remove_title_from_body(self, content):
        """本文からタイトル行を削除"""
        lines = content.split('\n')
        new_lines = []
        title_removed = False
        
        for line in lines:
            if not title_removed and line.strip().startswith('# '):
                title_removed = True
                continue
            new_lines.append(line)
        
        return '\n'.join(new_lines)
    
    def publish_to_qiita(self, qiita_file):
        """Qiitaにpublish"""
        if not self.config.get('publish', {}).get('auto_publish', True):
            return True
        
        try:
            # publish_to_qiita.shスクリプトを実行
            # スクリプトのディレクトリからの相対パスを使用
            script_path = Path(__file__).parent / 'publish_to_qiita.sh'
            if script_path.exists():
                # スクリプトのディレクトリに移動してから実行
                script_dir = script_path.parent
                result = subprocess.run(
                    [str(script_path), str(qiita_file)],
                    capture_output=True,
                    text=True,
                    timeout=300,
                    cwd=str(script_dir)
                )
                
                # 実行結果のログ出力
                if result.stdout:
                    logging.info(f"Publish実行出力: {result.stdout.strip()}")
                if result.stderr:
                    logging.warning(f"Publish実行警告: {result.stderr.strip()}")
                
                if result.returncode == 0:
                    logging.info(f"Publish成功: {qiita_file}")
                    return True
                else:
                    logging.error(f"Publish失敗: {qiita_file}, エラー: {result.stderr}")
                    return False
            else:
                logging.warning(f"publish_to_qiita.shが見つかりません: {script_path}")
                return False
                
        except Exception as e:
            logging.error(f"Publish実行エラー {qiita_file}: {e}")
            return False
    
    def run(self):
        """メイン処理を実行"""
        logging.info("Smart Qiita Update開始")
        
        # 対象ファイルを検索
        target_files = self.find_target_files()
        if not target_files:
            logging.warning("対象ファイルが見つかりません")
            return
        
        logging.info(f"検出されたファイル: {len(target_files)}個")
        for file in target_files:
            logging.info(f"  - {file.name}")
        
        # 変更されたファイルを特定
        changed_files = []
        for qiita_file in target_files:
            git_file = self.git_dir / qiita_file.name
            
            if not git_file.exists():
                logging.warning(f"ルートディレクトリに {git_file} が見つかりません")
                continue
            
            if self.has_content_changed(qiita_file, git_file):
                changed_files.append((qiita_file, git_file))
                logging.info(f"変更検出: {qiita_file.name}")
            else:
                logging.debug(f"変更なし: {qiita_file.name}")
        
        if not changed_files:
            logging.info("変更されたファイルはありません")
            return
        
        logging.info(f"変更されたファイル: {len(changed_files)}個")
        
        # 変更されたファイルを更新
        updated_count = 0
        for qiita_file, git_file in changed_files:
            if self.update_qiita_file(qiita_file, git_file):
                updated_count += 1
                
                # Publish実行
                if self.config.get('publish', {}).get('auto_publish', True):
                    delay = self.config.get('publish', {}).get('publish_delay', 0)
                    if delay > 0:
                        logging.info(f"{delay}秒待機中...")
                        import time
                        time.sleep(delay)
                    
                    self.publish_to_qiita(qiita_file)
        
        logging.info(f"更新完了: {updated_count}個のファイルを更新しました")
        logging.info("Smart Qiita Update完了")

def main():
    """メイン処理"""
    config_file = "qiita_update_config.yaml"
    
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    
    updater = SmartQiitaUpdater(config_file)
    updater.run()

if __name__ == "__main__":
    main()
