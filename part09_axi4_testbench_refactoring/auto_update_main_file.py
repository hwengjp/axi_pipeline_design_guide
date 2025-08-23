#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AXI Testbench Main File Auto-Updater
メインファイルを自動更新して、分割されたヘッダファイルを使用するようにします
"""

import os
import re
from pathlib import Path

class MainFileUpdater:
    def __init__(self):
        self.source_file = "axi_simple_dual_port_ram_tb.sv"
        self.target_file = "axi_simple_dual_port_ram_tb_refactored.sv"
        
        # 削除対象の関数リスト（自動分割で移動済み）
        self.functions_to_remove = [
            # テスト刺激生成系
            "generate_write_addr_payloads",
            "generate_write_addr_payloads_with_stall",
            "generate_write_data_payloads",
            "generate_write_data_payloads_with_stall",
            "generate_read_addr_payloads",
            "generate_read_addr_payloads_with_stall",
            
            # 検証・期待値生成系
            "generate_read_data_expected",
            "generate_write_resp_expected",
            "initialize_ready_negate_pulses",
            
            # ユーティリティ関数系
            "get_burst_type_value",
            "size_to_bytes",
            "size_to_string",
            "align_address_to_boundary",
            "check_read_data",
            "get_burst_type_string",
            "generate_strobe_pattern",
            "generate_fixed_strobe_pattern",
            
            # 重み付き乱数生成系
            "calculate_total_weight_generic",
            "generate_weighted_random_index_generic",
            "generate_weighted_random_index_burst_config",
            "generate_weighted_random_index",
            "calculate_total_weight",
            
            # ログ・監視・表示系
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
        
        # 削除対象のパラメータ・typedef
        self.definitions_to_remove = [
            "parameter MEMORY_SIZE_BYTES",
            "parameter AXI_DATA_WIDTH",
            "parameter AXI_ID_WIDTH",
            "parameter TOTAL_TEST_COUNT",
            "parameter PHASE_TEST_COUNT",
            "parameter TEST_COUNT_ADDR_SIZE_BYTES",
            "parameter CLK_PERIOD",
            "parameter CLK_HALF_PERIOD",
            "parameter RESET_CYCLES",
            "parameter AXI_ADDR_WIDTH",
            "parameter AXI_STRB_WIDTH",
            "parameter READY_NEGATE_ARRAY_LENGTH",
            "parameter LOG_ENABLE",
            "parameter DEBUG_LOG_ENABLE",
            "typedef struct",
            "burst_config_t burst_config_weights",
            "bubble_weight_t write_addr_bubble_weights",
            "bubble_weight_t write_data_bubble_weights",
            "bubble_weight_t read_addr_bubble_weights",
            "bubble_weight_t axi_r_ready_negate_weights",
            "bubble_weight_t axi_b_ready_negate_weights",
            "write_addr_payload_t write_addr_payloads",
            "write_addr_payload_t write_addr_payloads_with_stall",
            "write_data_payload_t write_data_payloads",
            "write_data_payload_t write_data_payloads_with_stall",
            "read_addr_payload_t read_addr_payloads",
            "read_addr_payload_t read_addr_payloads_with_stall",
            "read_data_expected_t read_data_expected",
            "write_resp_expected_t write_resp_expected",
            "logic current_phase",
            "logic write_addr_phase_start",
            "logic read_addr_phase_start",
            "logic write_data_phase_start",
            "logic write_resp_phase_start",
            "logic read_data_phase_start",
            "logic clear_phase_latches",
            "logic write_addr_phase_done",
            "logic read_addr_phase_done",
            "logic write_data_phase_done",
            "logic write_resp_phase_done",
            "logic read_data_phase_done",
            "logic write_addr_phase_done_latched",
            "logic read_addr_phase_done_latched",
            "logic write_data_phase_done_latched",
            "logic write_resp_phase_done_latched",
            "logic read_data_phase_done_latched",
            "logic generate_stimulus_expected_done",
            "logic test_execution_completed",
            "logic axi_r_ready_negate_pulses",
            "logic axi_b_ready_negate_pulses",
            "logic ready_negate_index"
        ]
        
        # 追加するinclude文
        self.includes_to_add = [
            '`include "axi_common_defs.svh"',
            '`include "axi_stimulus_functions.svh"',
            '`include "axi_verification_functions.svh"',
            '`include "axi_utility_functions.svh"',
            '`include "axi_random_generation.svh"',
            '`include "axi_monitoring_functions.svh"'
        ]

    def remove_function(self, content, func_name):
        """指定された関数を削除"""
        # 関数の開始パターンを検索
        start_pattern = rf"function\s+automatic\s+.*\b{re.escape(func_name)}\b"
        start_match = re.search(start_pattern, content)
        
        if not start_match:
            return content, False
        
        start_pos = start_match.start()
        
        # 関数の終了位置を検索
        remaining_content = content[start_pos:]
        end_pos = remaining_content.find("endfunction")
        
        if end_pos == -1:
            return content, False
        
        # endfunctionを含む
        end_pos = start_pos + end_pos + len("endfunction")
        
        # 関数を削除
        new_content = content[:start_pos] + content[end_pos:]
        return new_content, True

    def remove_definition(self, content, definition_pattern):
        """指定された定義を削除"""
        # パラメータ定義を検索
        if definition_pattern.startswith("localparam"):
            pattern = rf"{re.escape(definition_pattern)}.*?;"
        elif definition_pattern.startswith("typedef struct"):
            pattern = r"typedef\s+struct\s*\{.*?\}\s+\w+_t\s*;"
        else:
            pattern = rf"{re.escape(definition_pattern)}.*?;"
        
        matches = re.findall(pattern, content, re.DOTALL)
        if matches:
            for match in matches:
                content = content.replace(match, "")
            return content, True
        
        return content, False

    def add_includes(self, content):
        """include文を追加"""
        # モジュール宣言の直後に追加
        module_pattern = r"(module\s+\w+.*?;)"
        module_match = re.search(module_pattern, content, re.DOTALL)
        
        if module_match:
            module_end = module_match.end()
            include_text = "\n\n// Include split function files\n" + "\n".join(self.includes_to_add) + "\n"
            content = content[:module_end] + include_text + content[module_end:]
        
        return content

    def update_main_file(self):
        """メインファイルを更新"""
        print("=== AXI Testbench Main File Auto-Updater ===\n")
        
        # 元のファイルを読み込み
        try:
            with open(self.source_file, 'r', encoding='utf-8') as f:
                source_content = f.read()
            print(f"✅ Loaded source file: {self.source_file}")
        except Exception as e:
            print(f"❌ Error loading source file: {e}")
            return
        
        # 関数を削除
        print("\n--- Removing Functions ---")
        removed_functions = 0
        for func_name in self.functions_to_remove:
            print(f"  Removing: {func_name}")
            source_content, removed = self.remove_function(source_content, func_name)
            if removed:
                removed_functions += 1
                print(f"    ✅ Removed")
            else:
                print(f"    ⚠️  Not found")
        
        # 定義を削除
        print("\n--- Removing Definitions ---")
        removed_definitions = 0
        for definition in self.definitions_to_remove:
            print(f"  Removing: {definition}")
            source_content, removed = self.remove_definition(source_content, definition)
            if removed:
                removed_definitions += 1
                print(f"    ✅ Removed")
            else:
                print(f"    ⚠️  Not found")
        
        # include文を追加
        print("\n--- Adding Include Statements ---")
        source_content = self.add_includes(source_content)
        print(f"  ✅ Added {len(self.includes_to_add)} include statements")
        
        # 更新されたファイルを保存
        try:
            with open(self.target_file, 'w', encoding='utf-8') as f:
                f.write(source_content)
            print(f"\n✅ Updated main file: {self.target_file}")
        except Exception as e:
            print(f"❌ Error saving updated file: {e}")
            return
        
        # 結果を表示
        self.print_summary(removed_functions, removed_definitions)

    def print_summary(self, removed_functions, removed_definitions):
        """結果のサマリーを表示"""
        print("\n=== UPDATE SUMMARY ===")
        print(f"Total functions removed: {removed_functions}")
        print(f"Total definitions removed: {removed_definitions}")
        print(f"Include statements added: {len(self.includes_to_add)}")
        print(f"Source file: {self.source_file}")
        print(f"Target file: {self.target_file}")
        
        if removed_functions > 0:
            print(f"\n✅ Functions removed:")
            for func in self.functions_to_remove[:10]:  # 最初の10個を表示
                print(f"  - {func}")
            if len(self.functions_to_remove) > 10:
                print(f"  ... and {len(self.functions_to_remove) - 10} more")
        
        if removed_definitions > 0:
            print(f"\n✅ Definitions removed:")
            for def_item in self.definitions_to_remove[:5]:  # 最初の5個を表示
                print(f"  - {def_item}")
            if len(self.definitions_to_remove) > 5:
                print(f"  ... and {len(self.definitions_to_remove) - 5} more")

def main():
    updater = MainFileUpdater()
    updater.update_main_file()

if __name__ == "__main__":
    main()
