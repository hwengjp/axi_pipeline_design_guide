# AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプラインAXIデータチャネルの模擬

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプラインAXIデータチャネルの模擬](#axiバスのパイプライン回路設計ガイド--第４回-データがn倍に増えるパイプラインaxiデータチャネルの模擬)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 データ増幅とは](#21-データ増幅とは)
    - [2.2 通常のReadyのシーケンス](#22-通常のreadyのシーケンス)
    - [2.3 Payloadが４つに増える場合のシーケンス](#23-payloadが４つに増える場合のシーケンス)
      - [パイプライン構成](#パイプライン構成)
  - [3. サンプルコード](#3-サンプルコード)
    - [3.1 バーストリードパイプラインモジュール](#31-バーストリードパイプラインモジュール)
    - [3.2 バーストリードパイプラインテストベンチ](#32-バーストリードパイプラインテストベンチ)
    - [3.3 実行用スクリプト](#33-実行用スクリプト)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、パイプライン処理においてデータがN倍に増える場合のAXIデータチャネルの動作を模擬します。前回までに学んだパイプライン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「バーストアクセス」シナリオを扱います。

バーストアクセスは、1つのアドレスリクエストに対して複数のデータ応答が返されるシナリオです。パイプラインの途中で1つのPayload（アドレスに対するデータ）がバースト回数分に膨らみます。このような状況では、Payloadの個数が増えるパイプラインステージより上流のパイプラインを停止して待機させる必要があります。できるだけ無駄なサイクルが発生しない実装を考えます。

## 2. 動作原理

### 2.1 データ増幅とは

データ増幅とは、パイプライン処理において1つの入力データが複数の出力データに変換される現象です。特に**バーストアクセス**では、1つのリクエストに対して複数のデータ応答が返されます。

**データ増幅の特徴**:
- **発生箇所**: パイプラインの特定のステージでのみ発生
- **増幅パターン**: 1つの入力がN個の出力に変換（N > 1）
- **制御の重要性**: 増幅が発生するステージより上流のパイプラインを停止させる必要がある

**本設計でのデータ増幅**:
- **T0ステージ**: 1つのバーストリクエスト（アドレス+長さ）→ 複数のメモリアクセス
- **T1ステージ**: データ増幅なし（単純なメモリ読み出し）

### 2.2 通常のReadyのシーケンス

第１回で学んだReadyのシーケンスをおさらいしましょう。
シーケンスチャートを簡便にするためにデータもアドレスもPayloadと呼ぶことにします。
ReadyがHの時はデータを受信し、ReadyがLの時はパイプラインは停止（ストール）します。ValidがHの時はデータが有効、ValidがLの時はデータは無効です。
```
Clock    : 123456789012345678
Payload  : xxxxxx0001222345xx
Valid    : ______HHHHHHHHHH__
Ready    : HHHHHH__HH__HHHHHH
```
下の図は４段パイプラインです。上で説明したReadyとValidのルールはパイプラインのどこを輪切りにしても同じルールになっています。
```
Payload -> [T0] -> [T1] -> [T2] -> [T3] -> Payload
            |       |       |       |
Ready   <- -+-------+-------+-------+-- <- Ready
```

### 2.3 Payloadが４つに増える場合のシーケンス

Payloadが４つに増えるシナリオつまり、バースト長４のリードシーケンスを考えてみます。

#### パイプライン構成

T0はアドレスをカウントする回路。ここで上流に対するReadyの制御を行います。T1は下流のd_readyで制御されると同時に、上流に対するu_Readyを生成します。u_Readyは今までのルールであるd_ReadyがU_Readyに非同期でつながる回路に、T0でバースト中に待たせるためのT0_Readyを非同期で論理ANDした信号です。T0_ReadyはT0ステージで同期回路で生成します。
T1はメモリです。Read Enableとアドレスをラッチして次のクロックでデータを出力します。T1は下流のd_Readyで制御されます。
```
u_Payload -> [T0] -> [T1] -> d_Payload
              ^       ^   
              |       |   
u_Ready   <- [OR]<----+-- <- d_Ready
              ^                    
              |
          [T0_Ready]
```
| 段階 | 機能 | 説明 | データ増幅 |
|------|------|------|------------|
| T0 | アドレスカウンタとRE | バースト転送の制御とアドレス生成 | **1→４個に増加** |
| T1 | メモリアクセス| メモリからのデータ読み出し | **増幅なし**（4個維持） |

#### バースト長４、d_readyがH のシーケンス

アドレスは0から+4インクリメントで送られて、T0でAddress~Address+3の4つのアクセスを生成します。
Lengthはバースト長-1の値です。下流からのd_readyはHの場合です。

T0_Stateは3つのステートで管理されます。

| ステート | 状態名 | 条件 | 動作 |
|----------|--------|------|------|
| 0 | アイドル | T0_Count=F | 新しいバーストリクエストを待機 |
| 1 | バースト中 | T0_CountがFと0以外 | バースト転送を実行中 |
| 2 | 最終サイクル | T0_Count=0 | バースト完了処理 |

**初期値**: ステート=0（アイドル）、T0_Count=F、T0_Mem_Adr=0、T0_Mem_RE=L、T0_LAST=L、T0_Ready=H

**ステート0（アイドル）**: T0_u_Ready && T0_u_ValidでAddressとLengthから以下を生成
- T0_Count ← Lengthの値
- T0_Mem_Adr ← Addressの値  
- T0_Mem_RE ← H
- T0_LAST ← (Length=0) ? H : L
- T0_Ready ← (Length=0) ? H : L

**ステート1（バースト中）**: T0_Countをデクリメントし、アドレスをインクリメント
- T0_Count ← T0_Count - 1
- T0_Mem_Adr ← T0_Mem_Adr + 1
- T0_LAST ← (T0_Count=1) ? H : L

**ステート2（最終サイクル）**: バースト完了後、アイドル状態に戻る
- T0_Count ← F
- T0_Ready ← H
- ステート ← 0
```
Clock       : 123456789012345678901
Address     : xxxxxx044448888xxxxxx
Length      : xxxxxx333333333xxxxxx
Valid       : ______HHHHHHHHHHHH___
Ready       : HHHHHHH___H___H___HHH

T0_State    : 000000011121112111200
T0_Count    : FFFFFFF321032103210FF
T0_Mem_Adr  : xxxxxxx0123456789ABxx
T0_Mem_RE   : _______HHHHHHHHHHHH__
T0_Valid    : _______HHHHHHHHHHHH__
T0_Last     : __________H___H___H__
T0_Ready    : HHHHHHH___H___H___HHH
u_Ready     : HHHHHHH___H___H___HHH

d_Data      : _______0123456789AB__
d_Valid     : _______HHHHHHHHHHHH__
d_Last      : __________H___H___H__
d_Ready     : HHHHHHHHHHHHHHHHHHHHH
```

#### バースト長４、d_readyがトグルするシーケンス
T0とT1はどちらもd_readyで論理全体のイネーブル制御を行います。T0_Readyもこのd_readyでイネーブル制御されます。

```
Clock       : 123456789012345678901234567890123456
Address     : xxxxxx044444444888888888xxxxxxxxxxxx
Length      : xxxxxx333333333333333333xxxxxxxxxxxx
Valid       : ______HHHHHHHHHHHHHHHHHH____________
Ready       : HHHHHHH_______H________H_______HHHHH

T0_Count    : FFFFFFF3322110033322110033221100FFFF
T0_Mem_Adr  : xxxxxxx001122334445566778899AABBxxxx
T0_Mem_RE   : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Valid    : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Last     : _____________HH_______HH______HH____
T0_Ready    : HHHHHHH______HH_______HH______HHHHHH
u_Ready     : HHHHHHH_______H________H_______HHHHH

d_Data      : xxxxxxxxx001122333445566778899AABB__
d_Valid     : _________HHHHHHHHHHHHHH_____________
d_Last      : _______________HHH______HH______HH__
d_Ready     : HHHHHHH_H_H_H_H__H_H_H_H_H_H_H_H_HHH
```

## 3. サンプルコード

以下の指示でコードとテストベンチを生成します。
```
メモリはリードのみ、レイテンシ１、出力のデータ＝アドレスとします。パイプラインの入力アドレスとメモリのアドレスは同じとします。
ポート定義はクロック、リセット、パイプラインの最上流の信号、パイプラインの最下流の信号としてください。
このドキュメントを読んでコードを生成してください。

テストベンチも実装お願いします。テストベンチはpipeline_tb.svを参考にしてください。
テストデータと期待値は最初に配列として用意しておきます。配列はqueue型配列を使用してください。
```
ここまでの説明を読み込ませてAIに自動生成させたコードです。たった２段のパイプラインですので非常ににシンプルです。
このコードはアドレスチャネルと、データチャネルが合体しています。分離する方法として例えば、pipeline_insertモジュールをアドレスチャネルとする方法もあるでしょうし、アドレスチャネルとしてFIFOを使う方法もあるでしょう。

### 3.1 バーストリードパイプラインモジュール

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```systemverilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_read_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_addr,
    input  wire [7:0]              u_length,  // Burst length - 1
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]   d_data,
    output wire                     d_valid,
    output wire                     d_last,
    input  wire                     d_ready
);

    // T0 stage internal signals (Address counter and Read Enable)
    reg [7:0]                      t0_count;
    reg [ADDR_WIDTH-1:0]           t0_mem_addr;
    reg                             t0_mem_read_en;
    reg                             t0_valid;
    reg                             t0_last;
    reg                             t0_ready;
    reg [1:0]                      t0_state;  // 0: Idle, 1: Bursting, 2: Final cycle
    
    // T1 stage internal signals (Memory access)
    reg [DATA_WIDTH-1:0]           t1_data;
    reg                             t1_valid;
    reg                             t1_last;
    reg                             t1_ready;
    
    // Internal memory interface (not exposed externally)
    wire [DATA_WIDTH-1:0]          mem_data;
    wire                            mem_valid;
    
    // Downstream interface assignments
    assign d_data = t1_data;
    assign d_valid = t1_valid;
    assign d_last = t1_last;
    
    // T0 stage u_ready generation (T0_Ready AND d_ready)
    assign u_ready = t0_ready && d_ready;
    
    // T0 stage control (Address counter and Read Enable)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0_count <= 8'hFF;
            t0_mem_addr <= {ADDR_WIDTH{1'b0}};
            t0_mem_read_en <= 1'b0;
            t0_valid <= 1'b0;
            t0_last <= 1'b0;
            t0_ready <= 1'b1;
            t0_state <= 2'b00;
        end else if (d_ready) begin
            case (t0_state)
                2'b00: begin // Idle state
                    if (u_valid && u_ready) begin
                        t0_count <= u_length;
                        t0_mem_addr <= u_addr;
                        t0_mem_read_en <= 1'b1;
                        t0_valid <= 1'b1;
                        t0_last <= (u_length == 8'h00);
                        t0_ready <= (u_length == 8'h00);
                        t0_state <= (u_length == 8'h00) ? 2'b00 : 2'b01;
                    end else begin
                        t0_mem_read_en <= 1'b0;
                        t0_valid <= 1'b0;
                        t0_last <= 1'b0;
                    end
                end
                
                2'b01: begin // Bursting state
                    if (t0_count > 8'h00) begin
                        t0_count <= t0_count - 8'h01;
                        t0_mem_addr <= t0_mem_addr + 1;
                        t0_mem_read_en <= 1'b1;
                        t0_valid <= 1'b1;
                        t0_last <= (t0_count == 8'h01);
                        t0_ready <= 1'b0;
                        t0_state <= (t0_count == 8'h01) ? 2'b10 : 2'b01;
                    end
                end
                
                2'b10: begin // Final cycle
                    t0_count <= 8'hFF;
                    t0_mem_read_en <= 1'b0;
                    t0_valid <= 1'b0;
                    t0_last <= 1'b0;
                    t0_ready <= 1'b1;
                    t0_state <= 2'b00;
                end
                
                default: begin
                    t0_count <= 8'hFF;
                    t0_mem_addr <= {ADDR_WIDTH{1'b0}};
                    t0_mem_read_en <= 1'b0;
                    t0_valid <= 1'b0;
                    t0_last <= 1'b0;
                    t0_ready <= 1'b1;
                    t0_state <= 2'b00;
                end
            endcase
        end
    end
    
    // T1 stage control (Memory access)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_data <= {DATA_WIDTH{1'b0}};
            t1_valid <= 1'b0;
            t1_last <= 1'b0;
            t1_ready <= 1'b1;
        end else if (d_ready) begin
            if (t0_valid) begin
                // Memory latency 1: use address as data
                t1_data <= t0_mem_addr;
                t1_valid <= 1'b1;
                t1_last <= t0_last;
            end else begin
                t1_valid <= 1'b0;
                t1_last <= 1'b0;
            end
        end
    end

endmodule
```

</div>

### 3.2 バーストリードパイプラインテストベンチ

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```systemverilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.
`timescale 1ns / 1ps
module burst_read_pipeline_tb #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 3,   // Maximum burst length for testing
    parameter TEST_COUNT = 1000,      // Number of test
    parameter BUBBLE_N = 2,           // Base number of bubble cycles
    parameter STALL_N = 2             // Base number of stall cycles
)();

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;
    
    // Test pattern generator signals
    reg  [ADDR_WIDTH-1:0]  test_addr;
    reg  [7:0]             test_length;
    reg                     test_valid;
    wire                    test_ready;
    integer                 bubble_cycles;
    integer                 stall_cycles;
    
    // Test pattern arrays (queue arrays)
    reg  [ADDR_WIDTH-1:0]  test_addr_array [$];
    reg  [7:0]             test_length_array [$];
    reg                     test_valid_array [$];
    reg  [DATA_WIDTH-1:0]  expected_data_array [$];
    reg  [2:0]             stall_cycles_array [$];
    integer                 array_index;
    integer                 array_size;
    integer                 expected_data_index;
    integer                 stall_index;
    
    // DUT signals (upstream and downstream only)
    wire [DATA_WIDTH-1:0]  dut_data;
    wire                    dut_valid;
    wire                    dut_last;
    wire                    dut_ready;
    
    // Final output signals
    reg                     final_ready;
    
    // Sequence checker signals
    reg  [ADDR_WIDTH-1:0]  prev_test_addr;
    reg  [7:0]             prev_test_length;
    reg                     prev_test_valid;
    reg  [DATA_WIDTH-1:0]  prev_result_data;
    reg                     prev_result_valid;
    
    // Test control
    integer                 test_count;
    integer                 burst_count;
    integer                 data_count;
    integer                 valid_address_count;  // Valid address count (excluding bubbles)
    integer                 bubble_count;         // Bubble count
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_burst_addr;   // Current burst start address
    reg [7:0]              current_burst_length;  // Current burst length
    integer                 burst_data_count;      // Data count within burst
    
    // Burst tracking circuit - record burst start information
    reg [ADDR_WIDTH-1:0]   burst_addr_queue [$];  // Burst address queue
    reg [7:0]              burst_length_queue [$]; // Burst length queue
    integer                 burst_queue_index;     // Queue index
    
    // DUT instance
    burst_read_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .u_addr(test_addr),
        .u_length(test_length),
        .u_valid(test_valid),
        .u_ready(test_ready),
        .d_data(dut_data),
        .d_valid(dut_valid),
        .d_last(dut_last),
        .d_ready(dut_ready)
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
        integer i, j;
        integer burst_length;
        integer stall_cycles;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_data_index = 0;
        stall_index = 0;
        valid_address_count = 0;  // Valid address count (excluding bubbles)
        bubble_count = 0;         // Bubble count
        burst_data_count = 0;     // Burst data count
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request
            test_addr_array.push_back(i * 16);  // Start address
            test_length_array.push_back(burst_length - 1);  // Length - 1
            test_valid_array.push_back(1);
            array_size = array_size + 1;
            valid_address_count = valid_address_count + 1;
            
            // Generate expected data for this burst
            for (j = 0; j < burst_length; j = j + 1) begin
                expected_data_array.push_back((i * 16) + j);
                expected_data_index = expected_data_index + 1;
            end
            
            // Generate bubble cycles
            bubble_cycles = $random % (BUBBLE_N + 4) - BUBBLE_N;
            if (bubble_cycles < 0) bubble_cycles = 0;
            
            // Add bubbles
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array.push_back({ADDR_WIDTH{1'bx}});
                test_length_array.push_back(8'hxx);
                test_valid_array.push_back(0);
                array_size = array_size + 1;
                bubble_count = bubble_count + 1;
            end
            
            // Generate stall cycles (except for last burst)
            if (i < TEST_COUNT - 1) begin
                stall_cycles = $random % (STALL_N + 4) - STALL_N;
                if (stall_cycles < 0) stall_cycles = 0;
                stall_cycles_array.push_back(stall_cycles);
            end
        end
        
        // Generate additional stall cycles for bubble cycles
        for (i = 0; i < array_size - TEST_COUNT; i = i + 1) begin
            stall_cycles = $random % (STALL_N + 4) - STALL_N;
            if (stall_cycles < 0) stall_cycles = 0;
            stall_cycles_array.push_back(stall_cycles);
        end
    end
    
    // Test pattern generator (always block)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state - hold current data
            test_addr <= {ADDR_WIDTH{1'bx}};
            test_length <= 8'hxx;
            test_valid <= 0;
            array_index <= 0;
        end else begin
            if (array_index < array_size) begin
                if (test_ready) begin
                    // Ready is high, send next data
                    test_addr <= test_addr_array[array_index];
                    test_length <= test_length_array[array_index];
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
    reg [2:0] current_stall_cycles;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
            current_stall_cycles <= 0;
            stall_index <= 0;
        end else begin
            if (stall_counter == 0 && !stall_active) begin
                // Read stall cycles from array
                if (stall_index < stall_cycles_array.size()) begin
                    current_stall_cycles <= stall_cycles_array[stall_index];
                    stall_index <= stall_index + 1;
                end else begin
                    current_stall_cycles <= 0;
                end
                
                if (current_stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= current_stall_cycles;
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
    
    // Connect final ready to dut ready
    assign dut_ready = final_ready;
    
    // Burst tracking circuit - record burst start information
    always @(posedge clk) begin
        if (!rst_n) begin
            current_burst_addr <= {ADDR_WIDTH{1'b0}};
            current_burst_length <= 8'h00;
            burst_queue_index <= 0;
        end else begin
            // Record burst start when valid burst request is sent
            if (test_valid && test_ready && test_valid_array[array_index - 1]) begin
                burst_addr_queue.push_back(test_addr_array[array_index - 1]);
                burst_length_queue.push_back(test_length_array[array_index - 1]);
                $display("Time %0t: Burst queued - addr: 0x%0h, length: %0d, queue_size: %0d", 
                         $time, test_addr_array[array_index - 1], test_length_array[array_index - 1], burst_addr_queue.size());
            end
        end
    end
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            test_count <= 0;
            burst_count <= 0;
            data_count <= 0;
            burst_data_count <= 0;
        end else begin
            // Check if test count reached maximum
            if (data_count >= expected_data_index) begin
                $display("Test completed:");
                $display("  Total address patterns: %0d (including bubbles)", array_size);
                $display("  Valid address patterns: %0d (excluding bubbles)", valid_address_count);
                $display("  Bubble patterns: %0d", bubble_count);
                $display("  Total data: %0d", test_count);
                $display("  Max burst length: %0d", MAX_BURST_LENGTH);
                $display("  Bubble cycles (BUBBLE_N): %0d", BUBBLE_N);
                $display("  Stall cycles (STALL_N): %0d", STALL_N);
                $display("  Total stall cycles generated: %0d", stall_cycles_array.size());
                $display("PASS: All tests passed");
                // Stop after 1 clock cycle on success
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output data
            if (dut_valid && dut_ready) begin
                test_count <= test_count + 1;
                burst_data_count <= burst_data_count + 1;
                
                // Check if data matches expected value from array
                if (dut_data !== expected_data_array[data_count]) begin
                    $display("ERROR: Data mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    $display("  Expected: %0d, Got: %0d", expected_data_array[data_count], dut_data);
                    $display("  Burst: %0d, Data in burst: %0d", burst_count, test_count);
                    
                    // Stop after 1 clock cycle on error
                    repeat (1) @(posedge clk);
                    $finish;
                end
                
                data_count <= data_count + 1;
                
                // Count bursts and report burst information
                if (dut_last) begin
                    burst_count <= burst_count + 1;
                    if (burst_queue_index < burst_addr_queue.size()) begin
                        $display("Time %0t: Burst %0d completed - Start addr: 0x%0h, Length: %0d, Data count: %0d", 
                                 $time, burst_count, burst_addr_queue[burst_queue_index], burst_length_queue[burst_queue_index], burst_data_count + 1);
                        
                        // Check if data count matches expected length
                        if (burst_data_count + 1 !== burst_length_queue[burst_queue_index] + 1) begin
                            $display("ERROR: Data count mismatch at burst %0d", burst_count);
                            $display("  Time: %0t", $time);
                            $display("  Expected data count: %0d (Length: %0d + 1)", 
                                     burst_length_queue[burst_queue_index] + 1, burst_length_queue[burst_queue_index]);
                            $display("  Actual data count: %0d", burst_data_count + 1);
                            $display("  Start addr: 0x%0h", burst_addr_queue[burst_queue_index]);
                            repeat (1) @(posedge clk);
                            $finish;
                        end
                        
                        burst_queue_index <= burst_queue_index + 1;
                    end else begin
                        $display("Time %0t: Burst %0d completed - Queue empty, Data count: %0d", 
                                 $time, burst_count, burst_data_count + 1);
                    end
                    $display("  Debug: array_index=%0d, test_valid=%0d, test_ready=%0d, queue_index=%0d, queue_size=%0d", 
                             array_index, test_valid, test_ready, burst_queue_index, burst_addr_queue.size());
                    burst_data_count <= 0;
                end
            end
        end
    end
    
    // Sequence checker circuit - Input side
    reg prev_test_ready;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prev_test_addr <= {ADDR_WIDTH{1'bx}};
            prev_test_length <= 8'hxx;
            prev_test_valid <= 0;
            prev_test_ready <= 0;
        end else begin
            // Check if data is held when ready is low
            if (!prev_test_ready && test_valid) begin
                // Check if data value is same as previous cycle
                if (test_addr !== prev_test_addr || test_length !== prev_test_length || test_valid != prev_test_valid) begin
                    $display("ERROR: Input data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_addr, test_length, test_valid");
                    $display("  Should be held: addr=%0d, length=%0d, valid=%0d", prev_test_addr, prev_test_length, prev_test_valid);
                    $display("  Actual value: addr=%0d, length=%0d, valid=%0d", test_addr, test_length, test_valid);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (test_valid && test_ready) begin
                if (test_addr === {ADDR_WIDTH{1'bx}} || test_length === 8'hxx) begin
                    $display("ERROR: Undefined value detected in input data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: test_addr or test_length");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_test_addr <= test_addr;
            prev_test_length <= test_length;
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
            if (!prev_final_ready && dut_valid) begin
                // Check if data value is same as previous cycle
                if (dut_data !== prev_result_data || dut_valid != prev_result_valid) begin
                    $display("ERROR: Output data not held during stall");
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    $display("  Should be held: %0d", prev_result_data);
                    $display("  Actual value: %0d", dut_data);
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            // Check for undefined values during valid periods
            if (dut_valid && dut_ready) begin
                if (dut_data === {DATA_WIDTH{1'bx}}) begin
                    $display("ERROR: Undefined value detected in output data");
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_data");
                    repeat (1) @(posedge clk);
                    $finish;
                end
            end
            
            prev_result_data <= dut_data;
            prev_result_valid <= dut_valid;
            prev_final_ready <= dut_ready;
        end
    end

endmodule
```

</div>

上の指示を与えて生成されたコードは無修正で使用可能でした。テストベンチは期待通りの動作をさせるために約5時間かかりました。詳細な指示を与えないで、XXと同様にというあいまいな指示ではリクエストされた側もうまく生成はできないということです。

## 4. 実行用スクリプトの生成

シミュレータのコンパイル・実行スクリプトは以下のように指示して自動生成させます
```
modelsim用にコンパイルと実行を行うスクリプトを作成してください。スクリプト名はテストベンチ名に合わせます。
```

## ライセンス

このプロジェクトは [Apache License 2.0](LICENSE) の下で公開されています。 