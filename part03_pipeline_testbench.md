# AXIバスのパイプライン回路の設計ガイド ～ 第3回 パイプライン動作を確認するテストベンチ

## 目次

- [AXIバスのパイプライン回路の設計ガイド ～ 第3回 パイプライン動作を確認するテストベンチ](#axiバスのパイプライン回路の設計ガイド--第3回-パイプライン動作を確認するテストベンチ)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. テストベンチの設計方針](#2-テストベンチの設計方針)
    - [2.1 テスト記述の構成](#21-テスト記述の構成)
    - [2.2 テストパターン生成回路](#22-テストパターン生成回路)
    - [2.3 下流側Ready制御回路](#23-下流側ready制御回路)
    - [2.4 テスト結果確認回路](#24-テスト結果確認回路)
    - [2.5 シーケンス確認回路](#25-シーケンス確認回路)
    - [2.6 デルタ遅延問題の回避](#26-デルタ遅延問題の回避)
    - [2.7 その他](#27-その他)
  - [3. テストベンチの実装](#3-テストベンチの実装)
  - [4. 実行用スクリプトの生成](#4-実行用スクリプトの生成)
  - [5. デルタ遅延](#5-デルタ遅延)
    - [5.1 デルタ遅延とは](#51-デルタ遅延とは)
    - [5.2 回避方法](#52-回避方法)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

パイプライン回路の設計において、テストベンチは動作確認とデバッグの重要な要素です。本ドキュメントでは、パイプライン回路の動作を確実に検証するためのテストベンチ設計手法について説明します。

パイプライン回路のテストでは、以下の点が重要です：
- **Ready/Validハンドシェイクの動作確認**
- **ストール動作の検証**
- **バブル動作の検証**
- **データの整合性確認**

## 2. テストベンチの設計方針

### 2.1 テスト記述の構成

テスト回路は以下の構成で実装されます：

- **テストパターン生成回路**
  上流側からテストパターンを流し込む回路
- **下流側Ready制御回路**
  最も下流のReady信号をランダムに制御してストールを発生させる回路
- **テスト結果確認回路**
  下流の回路を模擬しかつ流れてきたデータを確認する回路
- **シーケンス確認回路**
  Ready、Valid、Dataのシーケンス異常をチェックする回路

### 2.2 テストパターン生成回路

- Dataと入力するDataの数はパラメータ指定とします。
- Dataは0から始まって指定された数までインクリメントするデータを順番に流すものとします。
- Dataと次のデータの間にランダムにバブルが入ります。バブルの期間のValidはL、データは不定とします。バブルのサイクル数は0~3の乱数とします。0の頻度を高くしたいので、-N~3の乱数を発生させて0未満の時は0とします。Nはパラメータとします。まずこのデータとValidを配列の初期値として用意します。配列の全体の長さはデータの個数+バブルの合計個数となります。配列はSystemVerilogの記述を使ってください。
- 先の配列で用意したデータをReadyの状態にしたがって流します。ひとつづ出力します。ReadyがLになると、データをホールドして次のサイクルの値が現在のサイクルの値と同じになります。
- 期待値データは有効データのみを配列に格納し、バブルは含めません。

### 2.3 下流側Ready制御回路

- 最も下流のReadyをランダムにネゲートしてストールさせます。ストールのサイクル数は0~3の乱数とします。0の頻度を高くしたいので、-N~3の乱数を発生させて0未満の時は0とします。Nはパラメータとします。
- リセット解除後5クロック間はReadyをLに保持します。

### 2.4 テスト結果確認回路

- ReadyがHかつValidがHの時が有効なデータです。上流側から流したデータが最下流で同じか確認します。
- 期待値は配列から取得し、テストカウントが最大値に達したら成功メッセージを表示してシミュレーションを終了します。

### 2.5 シーケンス確認回路

- ReadyがLの場合その次のサイクルのデータの値が同じになっているか確認します。
- ReadyがHかつValidがHの時にデータに不定値が無いことを確認します
- この回路を２つ用意して、上流側のpipeline_insertの入力と下流側のpipeline_insertの出力のシーケンス確認を行います

### 2.6 デルタ遅延問題の回避

シミュレーションにおいて、複数の`initial`文で信号の生成とチェックを行った場合、デルタ遅延と呼ばれる問題が発生することがあります。これは、同じシミュレーション時間内での信号の変化順序が不定になることで、予期しない動作を引き起こす原因となります。

この問題を回避するため、以下の設計方針を採用しています：

- **信号出力の`always`文使用**: 信号を出力する記述には`always`文を使用し、`initial`文での信号出力を避けています。
- **配列初期化以外の分離**: 配列の初期化以外は、同じ信号の値を別の`initial`文や別の`always`文で値の代入を行わないようにしています。
- **モジュール化された制御**: 各機能（クロック生成、リセット生成、テストパターン生成、Ready制御、結果チェック）を独立した`initial`文や`always`文に分離し、信号の競合を防いでいます。

この設計により、シミュレーションの再現性が向上し、デバッグが容易になります。

### 2.7 その他

- クロックは10nsサイクル100MHzとします。
- リセットは5クロックとします
- DUT(Design Under Test)はパイプラインの上流から下流にpipeline_insert->pipeline->pipeline_insertの接続とします。
- テストでエラーを見つけた場合はエラーの箇所から1クロック実行して停止しします
- エラー発生時は時刻と信号名を表示し、ストールエラーの場合は期待値と実際の値を表示します。

## 3. テストベンチの実装

```verilog
module pipeline_tb;
    // Parameters
    parameter DATA_WIDTH = 32;
    parameter PIPELINE_STAGES = 4;
    parameter TEST_DATA_COUNT = 100;
    parameter BUBBLE_N = 2;
    parameter STALL_N = 2;
    
    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Test pattern generation signals
    reg [DATA_WIDTH-1:0] test_data;
    reg test_valid;
    wire test_ready;
    
    // Test control variables
    integer bubble_cycles;
    integer stall_cycles;
    
    // Test pattern arrays
    reg [DATA_WIDTH-1:0] test_data_array [0:TEST_DATA_COUNT*4-1];
    reg test_valid_array [0:TEST_DATA_COUNT*4-1];
    reg [DATA_WIDTH-1:0] expected_data_array [0:TEST_DATA_COUNT*4-1];
    integer array_index;
    integer array_size;
    
    // DUT signals
    wire [DATA_WIDTH-1:0] dut_data;
    wire dut_valid;
    wire dut_ready;
    
    // Result checker signals
    wire [DATA_WIDTH-1:0] result_data;
    wire result_valid;
    wire result_ready;
    integer expected_data_index;
    
    // Final output signals
    wire [DATA_WIDTH-1:0] final_data;
    wire final_valid;
    reg final_ready;
    
    // Sequence checker signals
    reg [DATA_WIDTH-1:0] prev_test_data;
    reg prev_test_valid;
    reg [DATA_WIDTH-1:0] prev_result_data;
    reg prev_result_valid;
    
    // Test control
    integer test_count;
    
    // DUT instance: pipeline_insert -> pipeline -> pipeline_insert
    pipeline_insert #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_insert1 (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(test_data),
        .u_valid(test_valid),
        .u_ready(test_ready),
        .d_data(dut_data),
        .d_valid(dut_valid),
        .d_ready(dut_ready)
    );
    
    pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIPELINE_STAGES(PIPELINE_STAGES)
    ) dut_pipeline (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(dut_data),
        .u_valid(dut_valid),
        .u_ready(dut_ready),
        .d_data(result_data),
        .d_valid(result_valid),
        .d_ready(result_ready)
    );
    
    pipeline_insert #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut_insert2 (
        .clk(clk),
        .rst_n(rst_n),
        .u_data(result_data),
        .u_valid(result_valid),
        .u_ready(result_ready),
        .d_data(final_data),
        .d_valid(final_valid),
        .d_ready(final_ready)
    );
    
    // Clock generation (10ns cycle, 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end
    
    // Test data initialization
    initial begin
        // Variable declarations
        integer expected_index;
        integer i, j;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_index = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_DATA_COUNT; i = i + 1) begin
            // Add valid data
            test_data_array[array_size] = i;
            test_valid_array[array_size] = 1;
            expected_data_array[expected_index] = i;
            array_size = array_size + 1;
            expected_index = expected_index + 1;
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles (only to test arrays, not to expected array)
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_data_array[array_size] = {DATA_WIDTH{1'bx}};
                test_valid_array[array_size] = 0;
                array_size = array_size + 1;
            end
        end
    end
    
    // Test pattern generator (always block)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state - hold current data
            test_data <= {DATA_WIDTH{1'bx}};
            test_valid <= 0;
            array_index <= 0;
        end else begin
            if (array_index < array_size) begin
                if (test_ready) begin
                    // Ready is high, send next data
                    test_data <= test_data_array[array_index];
                    test_valid <= test_valid_array[array_index];
                    array_index <= array_index + 1;
                end
                // If Ready is low, hold current data (no change)
            end else begin
                // All data sent, stop sending
                test_valid <= 0;
            end
        end
    end
    
    // Downstream Ready control circuit
    reg [2:0] stall_counter;
    reg stall_active;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
        end else begin
            if (stall_counter == 0 && !stall_active) begin
                // Generate new stall cycles
                stall_cycles = $random % (STALL_N + 4) - STALL_N;
                if (stall_cycles < 0) stall_cycles = 0;
                
                if (stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= stall_cycles;
                    stall_active <= 1;
                end else begin
                    final_ready <= 1;
                end
            end else if (stall_active) begin
                // Stall is active, count down
                if (stall_counter > 1) begin
                    stall_counter <= stall_counter - 1;
                end else begin
                    // Stall complete
                    final_ready <= 1;
                    stall_counter <= 0;
                    stall_active <= 0;
                end
            end
        end
    end
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            test_count <= 0;
            expected_data_index <= 0;
        end else begin
            // Check if test count reached maximum
            if (test_count >= TEST_DATA_COUNT) begin
                $display("Test completed:");
                $display("  Total tests: %0d", test_count);
                $display("PASS: All tests passed");
                // Stop after 1 clock cycle on success
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output data
            if (final_valid && final_ready) begin
                test_count <= test_count + 1;
                
                // Check if data matches expected value from array
                if (final_data !== expected_data_array[expected_data_index]) begin
                    $display("ERROR: Data mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    $display("  Expected: %0d, Got: %0d", expected_data_array[expected_data_index], final_data);
                    
                    // Stop after 1 clock cycle on error
                    repeat (1) @(posedge clk);
                    $finish;
                end else begin
                    $display("PASS: Test %0d, Data: %0d", test_count, final_data);
                end
                
                expected_data_index <= expected_data_index + 1;
            end
        end
    end
    
    // Sequence checker circuit - Input side
    reg prev_test_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_data <= {DATA_WIDTH{1'bx}};
            prev_test_valid <= 0;
            prev_test_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_ready && test_valid) begin
                // Check if data value is same as previous cycle
                if (test_data !== prev_test_data || test_valid != prev_test_valid) begin
                    $display("ERROR: Input data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_data");
                    $display("  Should be held: %0d", prev_test_data);
                    $display("  Actual value: %0d", test_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (test_valid && test_ready) begin
                if (test_data === {DATA_WIDTH{1'bx}}) begin
                    $display("ERROR: Undefined value detected in input data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_data <= test_data;
            prev_test_valid <= test_valid;
            prev_test_ready <= test_ready;
        end
    end
    
    // Sequence checker circuit - Output side
    reg prev_final_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_result_data <= 0;
            prev_result_valid <= 0;
            prev_final_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_final_ready && final_valid) begin
                // Check if data value is same as previous cycle
                if (final_data !== prev_result_data || final_valid != prev_result_valid) begin
                    $display("ERROR: Output data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    $display("  Should be held: %0d", prev_result_data);
                    $display("  Actual value: %0d", final_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (final_valid && final_ready) begin
                if (final_data === {DATA_WIDTH{1'bx}}) begin
                    $display("ERROR: Undefined value detected in output data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: final_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_result_data <= final_data;
            prev_result_valid <= final_valid;
            prev_final_ready <= final_ready;
        end
    end
    
endmodule
```

## 4. 実行用スクリプトの生成

シミュレータのコンパイル・実行スクリプトは以下のように指示して自動生成させます
```
modelsim用にコンパイルと実行を行うスクリプトを作成してください。スクリプト名はテストベンチ名に合わせます。
```

## 5. デルタ遅延

### 5.1 デルタ遅延とは
デルタ遅延（Delta Delay）で発生する問題の解析は人もAIも苦手とするところです。デルタ遅延は、Verilog/SystemVerilogシミュレーションにおいて、同じシミュレーション時間内で複数の信号変化が発生する際の同一時刻での代入順序が不定になる問題です。複数のinitial文で'='によるブロッキング代入を行った場合、シミュレータがどちらのinitial文から実行するかは事前に特定できません。この問題は、テストベンチの設計において予期しない動作を引き起こす原因となり、シミュレーションの再現性を損なう可能性があります。そのため、最初からルールで問題が発生しないようにしておく必要があります。

### 5.2 回避方法

デルタ遅延問題は、テストベンチの設計において重要な考慮事項です。以下の原則に従うことで、この問題を効果的に回避できます：

1. **信号出力には`always`文を使用**
2. **非ブロッキング代入（<=）を活用**
3. **テストベンチを機能別に構造化**
4. **信号の変化を段階的に行う**
5. **シミュレーション結果の再現性を確認**

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details. 