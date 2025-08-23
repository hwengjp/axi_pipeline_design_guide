#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AXI Testbench Function Accuracy Checker
元のファイルと分割後のファイルの関数を比較して正確性をチェックします
"""

import os
import re
import difflib
from pathlib import Path

class FunctionChecker:
    def __init__(self):
        self.source_file = "axi_simple_dual_port_ram_tb.sv"
        self.functions_to_check = {
            # テスト刺激生成系
            "generate_write_addr_payloads": "axi_stimulus_functions.svh",
            "generate_write_addr_payloads_with_stall": "axi_stimulus_functions.svh",
            "generate_write_data_payloads": "axi_stimulus_functions.svh",
            "generate_write_data_payloads_with_stall": "axi_stimulus_functions.svh",
            "generate_read_addr_payloads": "axi_stimulus_functions.svh",
            "generate_read_addr_payloads_with_stall": "axi_stimulus_functions.svh",
            
            # 検証・期待値生成系
            "generate_read_data_expected": "axi_verification_functions.svh",
            "generate_write_resp_expected": "axi_verification_functions.svh",
            "initialize_ready_negate_pulses": "axi_verification_functions.svh",
            
            # ユーティリティ関数系
            "get_burst_type_value": "axi_utility_functions.svh",
            "size_to_bytes": "axi_utility_functions.svh",
            "size_to_string": "axi_utility_functions.svh",
            "align_address_to_boundary": "axi_utility_functions.svh",
            "check_read_data": "axi_utility_functions.svh",
            "get_burst_type_string": "axi_utility_functions.svh",
            "generate_strobe_pattern": "axi_utility_functions.svh",
            "generate_fixed_strobe_pattern": "axi_utility_functions.svh",
            
            # 重み付き乱数生成系
            "calculate_total_weight_generic": "axi_random_generation.svh",
            "generate_weighted_random_index_generic": "axi_random_generation.svh",
            "generate_weighted_random_index_burst_config": "axi_random_generation.svh",
            "generate_weighted_random_index": "axi_random_generation.svh",
            "calculate_total_weight": "axi_random_generation.svh",
            
            # ログ・監視・表示系
            "write_log": "axi_monitoring_functions.svh",
            "write_debug_log": "axi_monitoring_functions.svh",
            "display_write_addr_payloads": "axi_monitoring_functions.svh",
            "display_write_addr_payloads_with_stall": "axi_monitoring_functions.svh",
            "display_write_data_payloads": "axi_monitoring_functions.svh",
            "display_write_data_payloads_with_stall": "axi_monitoring_functions.svh",
            "display_read_addr_payloads": "axi_monitoring_functions.svh",
            "display_read_addr_payloads_with_stall": "axi_monitoring_functions.svh",
            "display_read_data_expected": "axi_monitoring_functions.svh",
            "display_write_resp_expected": "axi_monitoring_functions.svh",
            "display_all_arrays": "axi_monitoring_functions.svh"
        }
        
        self.results = {
            "exact_match": [],
            "different": [],
            "missing_in_source": [],
            "missing_in_split": [],
            "error": []
        }

    def extract_function(self, func_name, file_path):
        """指定されたファイルから関数を抽出"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 関数の開始パターンを検索
            start_pattern = rf"function\s+automatic\s+.*\b{re.escape(func_name)}\b"
            start_match = re.search(start_pattern, content)
            
            if not start_match:
                return None
            
            start_pos = start_match.start()
            
            # 関数の終了位置を検索（次の関数またはファイル終端）
            # 関数の終了は "endfunction" で判断
            remaining_content = content[start_pos:]
            end_pos = remaining_content.find("endfunction")
            
            if end_pos == -1:
                return None
            
            # endfunctionを含む
            function_content = remaining_content[:end_pos + len("endfunction")]
            return function_content.strip()
            
        except Exception as e:
            print(f"Error extracting {func_name} from {file_path}: {e}")
            return None

    def compare_functions(self, func_name, source_content, split_content):
        """2つの関数の内容を比較"""
        if source_content is None and split_content is None:
            return "both_missing"
        elif source_content is None:
            return "missing_in_source"
        elif split_content is None:
            return "missing_in_split"
        
        # 空白と改行を正規化して比較
        source_normalized = re.sub(r'\s+', ' ', source_content.strip())
        split_normalized = re.sub(r'\s+', ' ', split_content.strip())
        
        if source_normalized == split_normalized:
            return "exact_match"
        else:
            return "different"

    def generate_diff(self, source_content, split_content, func_name):
        """差分を生成"""
        if not source_content or not split_content:
            return "Cannot generate diff: missing content"
        
        source_lines = source_content.splitlines()
        split_lines = split_content.splitlines()
        
        diff = difflib.unified_diff(
            source_lines, split_lines,
            fromfile=f"Original {func_name}",
            tofile=f"Split {func_name}",
            lineterm=''
        )
        
        return '\n'.join(diff)

    def check_all_functions(self):
        """全ての関数をチェック"""
        print("=== AXI Testbench Function Accuracy Checker ===\n")
        
        for func_name, target_file in self.functions_to_check.items():
            print(f"Checking: {func_name} -> {target_file}")
            
            # 元のファイルから関数を抽出
            source_content = self.extract_function(func_name, self.source_file)
            
            # 分割後のファイルから関数を抽出
            split_content = self.extract_function(func_name, target_file)
            
            # 比較
            result = self.compare_functions(func_name, source_content, split_content)
            
            # 結果を記録
            if result == "exact_match":
                self.results["exact_match"].append(func_name)
                print(f"  ✅ {func_name}: EXACT MATCH")
            elif result == "different":
                self.results["different"].append(func_name)
                print(f"  ❌ {func_name}: DIFFERENT")
                
                # 差分を表示
                diff = self.generate_diff(source_content, split_content, func_name)
                print(f"  Diff for {func_name}:")
                print("  " + "="*50)
                for line in diff.splitlines():
                    print(f"  {line}")
                print("  " + "="*50)
                
            elif result == "missing_in_source":
                self.results["missing_in_source"].append(func_name)
                print(f"  ⚠️  {func_name}: MISSING IN SOURCE")
            elif result == "missing_in_split":
                self.results["missing_in_split"].append(func_name)
                print(f"  ⚠️  {func_name}: MISSING IN SPLIT")
            else:
                self.results["error"].append(func_name)
                print(f"  💥 {func_name}: ERROR")
            
            print()

    def print_summary(self):
        """結果のサマリーを表示"""
        print("=== CHECK SUMMARY ===")
        print(f"Total functions checked: {len(self.functions_to_check)}")
        print(f"✅ Exact matches: {len(self.results['exact_match'])}")
        print(f"❌ Different: {len(self.results['different'])}")
        print(f"⚠️  Missing in source: {len(self.results['missing_in_source'])}")
        print(f"⚠️  Missing in split: {len(self.results['missing_in_split'])}")
        print(f"💥 Errors: {len(self.results['error'])}")
        
        if self.results["exact_match"]:
            print(f"\n✅ Exact matches:")
            for func in self.results["exact_match"]:
                print(f"  - {func}")
        
        if self.results["different"]:
            print(f"\n❌ Different functions (need attention):")
            for func in self.results["different"]:
                print(f"  - {func}")
        
        if self.results["missing_in_source"]:
            print(f"\n⚠️  Missing in source:")
            for func in self.results["missing_in_source"]:
                print(f"  - {func}")
        
        if self.results["missing_in_split"]:
            print(f"\n⚠️  Missing in split:")
            for func in self.results["missing_in_split"]:
                print(f"  - {func}")

def main():
    checker = FunctionChecker()
    checker.check_all_functions()
    checker.print_summary()

if __name__ == "__main__":
    main()

