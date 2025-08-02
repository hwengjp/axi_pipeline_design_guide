#!/usr/bin/env python3
"""
Qiita記事更新スクリプト

このスクリプトは、QiitaDocs/publicディレクトリ内の記事ファイルを
Gitのメインファイルの内容で更新します。
Qiitaのヘッダ部分（---で囲まれた部分）は保持し、
本文部分をGitのファイルの内容で置き換えます。
"""

import os
import re
import sys
from pathlib import Path
import glob

def extract_qiita_header(content):
    """Qiitaのヘッダ部分を抽出する"""
    lines = content.split('\n')
    header_lines = []
    in_header = False
    header_end = -1
    
    for i, line in enumerate(lines):
        if line.strip() == '---':
            if not in_header:
                in_header = True
                header_lines.append(line)
            else:
                header_lines.append(line)
                header_end = i
                break
        elif in_header:
            header_lines.append(line)
    
    if header_end == -1:
        return None, content
    
    header = '\n'.join(header_lines)
    body = '\n'.join(lines[header_end + 1:])
    
    return header, body

def get_git_content(filename):
    """Gitのメインファイルから内容を取得する"""
    git_file = Path(filename)
    if not git_file.exists():
        print(f"警告: {git_file} が見つかりません")
        return None
    
    with open(git_file, 'r', encoding='utf-8') as f:
        return f.read()

def update_qiita_article(qiita_file, git_content):
    """Qiita記事を更新する"""
    with open(qiita_file, 'r', encoding='utf-8') as f:
        qiita_content = f.read()
    
    # Qiitaヘッダを抽出
    header, _ = extract_qiita_header(qiita_content)
    if header is None:
        print(f"警告: {qiita_file} にQiitaヘッダが見つかりません")
        return False
    
    # Gitファイルの内容全体を本文として使用（Gitファイルにはヘッダがないため）
    git_body = git_content
    
    # 新しい内容を作成
    new_content = header + '\n' + git_body
    
    # ファイルを更新
    with open(qiita_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"更新完了: {qiita_file}")
    return True

def find_target_files(qiita_dir):
    """QiitaDocs/publicディレクトリ内のpart*とrule*ファイルを検出する"""
    target_files = []
    
    # part*とrule*ファイルを検索
    patterns = ['part*.md', 'rule*.md']
    
    for pattern in patterns:
        files = list(qiita_dir.glob(pattern))
        target_files.extend(files)
    
    return target_files

def main():
    """メイン処理"""
    qiita_dir = Path("QiitaDocs/public")
    
    if not qiita_dir.exists():
        print("エラー: QiitaDocs/publicディレクトリが見つかりません")
        sys.exit(1)
    
    # 更新対象のファイルを動的に検出
    target_files = find_target_files(qiita_dir)
    
    if not target_files:
        print("警告: QiitaDocs/publicディレクトリにpart*またはrule*ファイルが見つかりません")
        return
    
    print(f"検出されたファイル: {len(target_files)}個")
    for file in target_files:
        print(f"  - {file.name}")
    
    updated_count = 0
    
    for qiita_file in target_files:
        # 対応するルートディレクトリのファイル名
        git_file = Path(qiita_file.name)
        
        if not git_file.exists():
            print(f"警告: ルートディレクトリに {git_file} が見つかりません")
            continue
        
        # Gitの内容を取得
        git_content = get_git_content(git_file)
        if git_content is None:
            continue
        
        # Qiita記事を更新
        if update_qiita_article(qiita_file, git_content):
            updated_count += 1
    
    print(f"\n更新完了: {updated_count}個のファイルを更新しました")

if __name__ == "__main__":
    main() 