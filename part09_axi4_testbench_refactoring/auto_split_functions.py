#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AXI Testbench Function Auto-Splitter
元のファイルから関数を正確に抽出して、新しいヘッダファイルに自動生成します
"""

import os
import re
from pathlib import Path

class FunctionAutoSplitter:
    def __init__(self):
        self.source_file = "axi_simple_dual_port_ram_tb.sv"
        
        # 分割先ファイルと関数のマッピング
        self.function_mapping = {
            # テスト刺激生成系
            "axi_stimulus_functions.svh": [
                "generate_write_addr_payloads",
                "generate_write_addr_payloads_with_stall",
                "generate_write_data_payloads",
                "generate_write_data_payloads_with_stall",
                "generate_read_addr_payloads",
                "generate_read_addr_payloads_with_stall"
            ],
            
            # 検証・期待値生成系
            "axi_verification_functions.svh": [
                "generate_read_data_expected",
                "generate_write_resp_expected",
                "initialize_ready_negate_pulses"
            ],
            
            # ユーティリティ関数系
            "axi_utility_functions.svh": [
                "get_burst_type_value",
                "size_to_bytes",
                "size_to_string",
                "align_address_to_boundary",
                "check_read_data",
                "get_burst_type_string",
                "generate_strobe_pattern",
                "generate_fixed_strobe_pattern"
            ],
            
            # 重み付き乱数生成系
            "axi_random_generation.svh": [
                "calculate_total_weight_generic",
                "generate_weighted_random_index_generic",
                "generate_weighted_random_index_burst_config",
                "generate_weighted_random_index",
                "calculate_total_weight"
            ],
            
            # ログ・監視・表示系
            "axi_monitoring_functions.svh": [
                "write_log",
                "write_debug_log",
                "display_write_addr_payloads",
                "display_write_addr_payloads_with_stall",
                "display_write_data_payloads",
                "display_write_data_payloads_with_stall",
                "display_read_addr_payloads",
                "display_read_addr_payloads_with_stall",
                "display_read_data_expected",
                "display_write_resp_expected",
                "display_all_arrays"
            ]
        }
        
        # 共通定義ファイル
        self.common_defs_file = "axi_common_defs.svh"
        
        # 結果の記録
        self.results = {
            "extracted": [],
            "failed": [],
            "files_created": []
        }

    def extract_function(self, func_name, content):
        """指定された関数を抽出"""
        try:
            # 関数の開始パターンを検索
            start_pattern = rf"function\s+automatic\s+.*\b{re.escape(func_name)}\b"
            start_match = re.search(start_pattern, content)
            
            if not start_match:
                return None
            
            start_pos = start_match.start()
            
            # 関数の終了位置を検索
            remaining_content = content[start_pos:]
            end_pos = remaining_content.find("endfunction")
            
            if end_pos == -1:
                return None
            
            # endfunctionを含む
            function_content = remaining_content[:end_pos + len("endfunction")]
            return function_content.strip()
            
        except Exception as e:
            print(f"Error extracting {func_name}: {e}")
            return None

    def extract_common_definitions(self, content):
        """共通の定義（パラメータ、typedef、配列）を抽出"""
        common_defs = []
        
        # パラメータ定義を抽出
        param_pattern = r"localparam\s+.*?;"
        params = re.findall(param_pattern, content, re.DOTALL)
        common_defs.extend(params)
        
        # typedef定義を抽出
        typedef_pattern = r"typedef\s+struct\s*\{.*?\}\s+\w+_t\s*;"
        typedefs = re.findall(typedef_pattern, content, re.DOTALL)
        common_defs.extend(typedefs)
        
        # 配列定義を抽出
        array_pattern = r"(\w+_t|int|string)\s+\w+\[\]\s*=\s*\{.*?\};"
        arrays = re.findall(array_pattern, content, re.DOTALL)
        common_defs.extend(arrays)
        
        return common_defs

    def create_header_file(self, filename, functions, common_defs=None):
        """ヘッダファイルを作成"""
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                # ファイルヘッダー
                f.write(f"// {filename}\n")
                f.write("// Auto-generated from axi_simple_dual_port_ram_tb.sv\n")
                f.write("// DO NOT MODIFY - This file is auto-generated\n\n")
                
                # インクルードガード
                guard_name = filename.replace('.', '_').upper()
                f.write(f"`ifndef {guard_name}\n")
                f.write(f"`define {guard_name}\n\n")
                
                # 共通定義のインクルード
                if common_defs:
                    f.write("// Include common definitions\n")
                    f.write('`include "axi_common_defs.svh"\n\n')
                
                # 関数を追加
                for func_name in functions:
                    if func_name in self.results["extracted"]:
                        f.write(f"// Function: {func_name}\n")
                        f.write(f"// Extracted from original testbench\n\n")
                        # 関数の内容は後で追加
                    else:
                        f.write(f"// Function: {func_name} - EXTRACTION FAILED\n\n")
                
                # インクルードガード終了
                f.write(f"`endif // {guard_name}\n")
            
            self.results["files_created"].append(filename)
            print(f"✅ Created header file: {filename}")
            
        except Exception as e:
            print(f"❌ Error creating {filename}: {e}")

    def populate_header_file(self, filename, functions_content):
        """ヘッダファイルに関数の内容を追加"""
        try:
            # 既存のファイルを読み込み
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 関数の内容を挿入
            for func_name, func_content in functions_content.items():
                if func_content:
                    # プレースホルダーを実際の関数内容で置換
                    placeholder = f"// Function: {func_name}\n// Extracted from original testbench\n\n"
                    replacement = f"// Function: {func_name}\n// Extracted from original testbench\n\n{func_content}\n\n"
                    content = content.replace(placeholder, replacement)
            
            # ファイルを書き込み
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✅ Populated {filename} with function content")
            
        except Exception as e:
            print(f"❌ Error populating {filename}: {e}")

    def auto_split(self):
        """自動分割を実行"""
        print("=== AXI Testbench Function Auto-Splitter ===\n")
        
        # 元のファイルを読み込み
        try:
            with open(self.source_file, 'r', encoding='utf-8') as f:
                source_content = f.read()
            print(f"✅ Loaded source file: {self.source_file}")
        except Exception as e:
            print(f"❌ Error loading source file: {e}")
            return
        
        # 共通定義を抽出
        print("\n--- Extracting Common Definitions ---")
        common_defs = self.extract_common_definitions(source_content)
        print(f"Found {len(common_defs)} common definitions")
        
        # 各関数を抽出
        print("\n--- Extracting Functions ---")
        all_functions = {}
        
        for target_file, func_list in self.function_mapping.items():
            print(f"\nProcessing {target_file}:")
            functions_content = {}
            
            for func_name in func_list:
                print(f"  Extracting: {func_name}")
                func_content = self.extract_function(func_name, source_content)
                
                if func_content:
                    functions_content[func_name] = func_content
                    self.results["extracted"].append(func_name)
                    print(f"    ✅ Success")
                else:
                    self.results["failed"].append(func_name)
                    print(f"    ❌ Failed")
            
            all_functions[target_file] = functions_content
        
        # ヘッダファイルを作成
        print("\n--- Creating Header Files ---")
        for target_file, func_list in self.function_mapping.items():
            self.create_header_file(target_file, func_list, common_defs)
        
        # 関数の内容を追加
        print("\n--- Populating Header Files ---")
        for target_file, functions_content in all_functions.items():
            self.populate_header_file(target_file, functions_content)
        
        # 結果を表示
        self.print_summary()

    def print_summary(self):
        """結果のサマリーを表示"""
        print("\n=== AUTO-SPLIT SUMMARY ===")
        print(f"Total functions processed: {len(self.results['extracted']) + len(self.results['failed'])}")
        print(f"✅ Successfully extracted: {len(self.results['extracted'])}")
        print(f"❌ Failed to extract: {len(self.results['failed'])}")
        print(f"📁 Files created: {len(self.results['files_created'])}")
        
        if self.results["extracted"]:
            print(f"\n✅ Extracted functions:")
            for func in self.results["extracted"]:
                print(f"  - {func}")
        
        if self.results["failed"]:
            print(f"\n❌ Failed functions:")
            for func in self.results["failed"]:
                print(f"  - {func}")
        
        if self.results["files_created"]:
            print(f"\n📁 Created files:")
            for file in self.results["files_created"]:
                print(f"  - {file}")

def main():
    splitter = FunctionAutoSplitter()
    splitter.auto_split()

if __name__ == "__main__":
    main()
