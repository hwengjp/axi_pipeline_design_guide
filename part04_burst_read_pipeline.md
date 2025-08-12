# AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプラインAXIリードアドレスチャネルの模擬

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプラインAXIリードアドレスチャネルの模擬](#axiバスのパイプライン回路設計ガイド--第４回-データがn倍に増えるパイプラインaxiリードアドレスチャネルの模擬)
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

本記事では、パイプライン処理においてペイロードがN倍に増える場合のAXIリードアドレスチャネルの動作を模擬します。前回までに学んだパイプライン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「バーストアクセス」シナリオを扱います。

バーストアクセスは、1つのアドレスリクエストに対して複数のデータ応答が返されるシナリオです。パイプラインの途中で1つのPayload（アドレス）がバースト回数分に膨らみます。このような状況では、Payloadの個数が増えるパイプラインステージより上流のパイプラインを停止して待機させる必要があります。できるだけ無駄なサイクルが発生しない実装を考えます。

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

T0はアドレスをカウントする回路。ここで上流に対するReadyの制御を行います。T1は下流のd_readyで制御されると同時に、上流に対するu_Readyを生成します。u_Readyは今までのルールであるd_ReadyがU_Readyに非同期でつながる回路に、T0でバースト中に待たせるためのT0_State_Readyを非同期で論理ANDした信号です。T0_State_ReadyはT0ステージで同期回路で生成します。
T1はメモリです。Read Enableとアドレスをラッチして次のクロックでデータを出力します。T1は下流のd_Readyで制御されます。

**重要な設計ポイント**: この回路では、パイプライン全体がReady信号で制御されており、各ステージの動作は`d_ready`がHの時のみ実行されます。また、T0ステージから派生する制御信号（`t0_mem_read_en`、`t0_last`、`t0_state_ready`）は、`t0_count`の値をデコードして生成されるため、always文内での複雑な制御ロジックが不要になり、コードがすっきりしています。

**Ready制御の特徴**: 各ステージのalways文は`d_ready`がHの時のみ実行され、パイプライン全体がReady信号で統一的に制御されています。また、T0ステージの制御は`t0_state_ready`信号に基づいて行われ、より直感的な制御フローを実現しています。

```
u_Payload -> [T0] -> [T1] -> d_Payload
              ^       ^
              |       |
u_Ready   <-[AND]<----+-- <- d_Ready
              ^
              |
          [T0_State_Ready]
```
| 段階 | 機能 | 説明 | データ増幅 |
|------|------|------|------------|
| T0 | アドレスカウンタとRE | バースト転送の制御とアドレス生成 | **1→４個に増加** |
| T1 | メモリアクセス| メモリからのデータ読み出し | **増幅なし**（4個維持） |

#### バースト長４、d_readyがH のシーケンス

アドレスは0から+4インクリメントで送られて、T0でAddress~Address+3の4つのアクセスを生成します。
Lengthはバースト長-1の値です。下流からのd_readyはHの場合です。

T0_State_Readyは2つの状態で管理されます。

| 状態 | 状態名 | 条件 | 動作 |
|------|--------|------|------|
| 1 | リクエスト受付可能 | T0_Count=0xFFまたはT0_Count=0x00 | アイドルまたはバーストの最後のサイクル |
| 0 | バースト中 | T0_Countが0xFFでも0x00でもない | バースト転送を実行中 |

**初期値**: 状態=1（リクエスト受付可能）、T0_Count=0xFF、T0_Mem_Adr=0、T0_Mem_RE=L、T0_LAST=L、T0_State_Ready=H

**状態1（リクエスト受付可能）**: T0_u_Ready && T0_u_ValidでAddressとLengthから以下を生成
- T0_Count ← Lengthの値
- T0_Mem_Adr ← Addressの値

**状態0（バースト中）**: T0_Countをデクリメントし、アドレスをインクリメント
- T0_Count ← T0_Count - 1
- T0_Mem_Adr ← T0_Mem_Adr + 1

**制御信号の生成**: 以下の信号は`t0_count`の値をデコードして生成されます：
- `t0_state_ready`: `(t0_count == 8'hFF) || (t0_count == 8'h00)` - アイドルまたは最終サイクルの時のみH
- `t0_last`: `(t0_count == 8'h00)` - カウンタが0の時のみH
- `t0_mem_read_en`: `(t0_count != 8'hFF)` - アイドル状態以外でメモリ読み取り有効

```
Clock         : 123456789012345678901
Address       : xxxxxx044448888xxxxxx
Length        : xxxxxx333333333xxxxxx
Valid         : ______HHHHHHHHHHHH___
Ready         : HHHHHHH___H___H___HHH

T0_Count      : FFFFFFF321032103210FF
T0_Mem_Adr    : xxxxxxx0123456789ABxx
T0_Mem_RE     : _______HHHHHHHHHHHH__
T0_Valid      : _______HHHHHHHHHHHH__
T0_Last       : __________H___H___H__
T0_State_Ready: HHHHHHH___H___H___HHH
u_Ready       : HHHHHHH___H___H___HHH

d_Data        : _______0123456789AB__
d_Valid       : _______HHHHHHHHHHHH__
d_Last        : __________H___H___H__
d_Ready       : HHHHHHHHHHHHHHHHHHHHH
```

#### バースト長４、d_readyがトグルするシーケンス

T0とT1はどちらもd_readyで論理全体のイネーブル制御を行います。T0_State_Readyもこのd_readyでイネーブル制御されます。

**Ready制御の特徴**: 各ステージのalways文は`d_ready`がHの時のみ実行され、パイプライン全体がReady信号で統一的に制御されています。また、T0ステージの制御は`t0_state_ready`信号に基づいて行われ、より直感的な制御フローを実現しています。

```
Clock         : 123456789012345678901234567890123456
Address       : xxxxxx044444444888888888xxxxxxxxxxxx
Length        : xxxxxx333333333333333333xxxxxxxxxxxx
Valid         : ______HHHHHHHHHHHHHHHHHH____________
Ready         : HHHHHHH_______H________H_______HHHHH

T0_Count      : FFFFFFF3322110033322110033221100FFFF
T0_Mem_Adr    : xxxxxxx001122334445566778899AABBxxxx
T0_Mem_RE     : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Valid      : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Last       : _____________HH_______HH______HH____
T0_State_Ready: HHHHHHH______HH_______HH______HHHHHH
u_Ready       : HHHHHHH_______H________H_______HHHHH

d_Data        : xxxxxxxxx001122333445566778899AABB__
d_Valid       : _________HHHHHHHHHHHHHH_____________
d_Last        : _______________HHH______HH______HH__
d_Ready       : HHHHHHH_H_H_H_H__H_H_H_H_H_H_H_H_HHH
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
ここまでの説明を読み込ませてAIに自動生成させたコードです。たった２段のパイプラインですので非常にシンプルです。
このコードはアドレスチャネルと、データチャネルが合体しています。分離する方法として例えば、pipeline_insertモジュールをアドレスチャネルとする方法もあるでしょうし、アドレスチャネルとしてFIFOを使う方法もあるでしょう。

**コードの特徴**:
1. **Ready制御**: パイプライン全体が`d_ready`信号で制御されており、各ステージの動作はReadyがHの時のみ実行されます
2. **デコードベース制御**: T0ステージから派生する制御信号（`t0_mem_read_en`、`t0_last`、`t0_state_ready`）は、`t0_count`の値をデコードして生成されます
3. **シンプルなalways文**: 複雑な制御ロジックがalways文内に含まれておらず、コードがすっきりしています
4. **統一的制御**: パイプライン全体が一つのReady信号で統一的に制御されています

### 3.1 バーストリードパイプラインモジュール

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
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
    reg [7:0]                      t0_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           t0_mem_addr;  // Current memory address
    wire                            t0_mem_read_en; // Memory read enable signal
    reg                             t0_valid;     // T0 stage valid signal
    wire                            t0_last;      // Last burst cycle indicator
    wire                            t0_state_ready;     // T0 stage ready signal

    // T1 stage internal signals (Memory access)
    reg [DATA_WIDTH-1:0]           t1_data;      // T1 stage data output
    reg                             t1_valid;     // T1 stage valid signal
    reg                             t1_last;      // T1 stage last signal

    // Internal memory interface (not exposed externally)
    wire [DATA_WIDTH-1:0]          mem_data;     // Memory data input (unused in this implementation)
    wire                            mem_valid;    // Memory valid signal (unused in this implementation)

    // Downstream interface assignments
    assign d_data  = t1_data;
    assign d_valid = t1_valid;
    assign d_last  = t1_last;

    // T0 stage control signals
    assign u_ready      = t0_state_ready && d_ready;           // Upstream ready when both T0 and downstream are ready
    assign t0_state_ready     = (t0_count == 8'hFF) || (t0_count == 8'h00); // Ready when idle or last cycle
    assign t0_last      = (t0_count == 8'h00);           // Last cycle when counter reaches 0
    assign t0_mem_read_en = (t0_count != 8'hFF);        // Enable memory read when not idle

    // T0 stage control logic (Address counter and Read Enable)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0_count    <= 8'hFF;                        // Initialize to idle state
            t0_mem_addr <= {ADDR_WIDTH{1'b0}};           // Initialize address to 0
            t0_valid    <= 1'b0;                         // Initialize valid to 0
        end else if (d_ready) begin
            case (t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    t0_count    <= u_valid ? u_length : 8'hFF;  // Load burst length or stay idle
                    t0_mem_addr <= u_addr;                       // Load start address
                    t0_valid    <= u_valid;                      // Set valid based on upstream
                end
                1'b0: begin // Not ready state (Bursting)
                    t0_count    <= t0_count - 8'h01;            // Decrement burst counter
                    t0_mem_addr <= t0_mem_addr + 1;             // Increment memory address
                    t0_valid    <= 1'b1;                        // Keep valid during burst
                end
            endcase
        end
    end

    // T1 stage control logic (Memory access)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_data  <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            t1_valid <= 1'b0;                             // Initialize valid to 0
            t1_last  <= 1'b0;                             // Initialize last to 0
        end else if (d_ready) begin
            // Memory latency 1: use address as data (simplified for demonstration)
            t1_data  <= (t0_mem_read_en) ? t0_mem_addr : t1_data; // Update data or hold at disable
            t1_valid <= t0_valid;                                // Forward T0 valid signal
            t1_last  <= t0_last;                                 // Forward T0 last signal
        end
    end

endmodule
```

</div>

**コードの特徴**:
1. **Ready制御**: パイプライン全体が`d_ready`信号で制御されており、各ステージの動作はReadyがHの時のみ実行されます
2. **デコードベース制御**: T0ステージから派生する制御信号（`t0_mem_read_en`、`t0_last`、`t0_state_ready`）は、`t0_count`の値をデコードして生成されます
3. **シンプルなalways文**: 複雑な制御ロジックがalways文内に含まれておらず、コードがすっきりしています
4. **統一的制御**: パイプライン全体が一つのReady信号で統一的に制御されています

### 3.2 バーストリードパイプラインテストベンチ

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
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
    
    // DUT signals
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
    integer                 valid_address_count;
    integer                 bubble_count;
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_burst_addr;
    reg [7:0]              current_burst_length;
    integer                 burst_data_count;
    
    // Burst queue for verification
    reg [ADDR_WIDTH-1:0]   burst_addr_queue [$];
    reg [7:0]              burst_length_queue [$];
    integer                 burst_queue_index;
    
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
        integer i, j;
        integer burst_length;
        integer stall_cycles;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_data_index = 0;
        stall_index = 0;
        valid_address_count = 0;
        bubble_count = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request
            test_addr_array.push_back(i * 16);
            test_length_array.push_back(burst_length - 1);
            test_valid_array.push_back(1);
            valid_address_count = valid_address_count + 1;
            
            // Add expected data for this burst
            for (j = 0; j < burst_length; j = j + 1) begin
                expected_data_array.push_back((i * 16) + j);
                expected_data_index = expected_data_index + 1;
            end
            
            // Generate bubble cycles
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Add bubbles
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array.push_back({ADDR_WIDTH{1'bx}});
                test_length_array.push_back(8'hxx);
                test_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate stall cycles for each burst request (including bubbles)
            stall_cycles = $urandom_range(0, STALL_N);
            stall_cycles_array.push_back(stall_cycles);
            
            // Add stall cycles for bubble cycles as well
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                stall_cycles = $urandom_range(0, STALL_N);
                stall_cycles_array.push_back(stall_cycles);
            end
        end
        
        array_size = test_addr_array.size();
        
        $display("Test initialization completed:");
        $display("  Total address patterns: %0d", test_addr_array.size());
        $display("  Valid address patterns: %0d", valid_address_count);
        $display("  Bubble patterns: %0d", bubble_count);
        $display("  Expected data: %0d", expected_data_index);
    end
    
    // Test pattern generator
    always @(posedge clk) begin
        if (!rst_n) begin
            test_addr <= {ADDR_WIDTH{1'bx}};
            test_length <= 8'hxx;
            test_valid <= 0;
            array_index <= 0;
        end else begin
            if (array_index < test_addr_array.size()) begin
                if (test_ready) begin
                    test_addr <= test_addr_array[array_index];
                    test_length <= test_length_array[array_index];
                    test_valid <= test_valid_array[array_index];
                    array_index <= array_index + 1;
                end
            end else begin
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
            final_ready <= 0;
            stall_counter <= 0;
            stall_active <= 0;
            current_stall_cycles <= 0;
            stall_index <= 0;
        end else begin
            // Default to ready unless stall is active
            final_ready <= 1;
            
            if (stall_counter == 0 && !stall_active) begin
                if (stall_index < stall_cycles_array.size()) begin
                    current_stall_cycles <= stall_cycles_array[stall_index];
                    stall_index <= stall_index + 1;
                end else begin
                    // Reset stall_index when reaching the end to cycle through the array
                    current_stall_cycles <= stall_cycles_array[0];
                    stall_index <= 1;
                end
                
                if (current_stall_cycles > 0) begin
                    final_ready <= 0;
                    stall_counter <= current_stall_cycles;
                    stall_active <= 1;
                end
            end else if (stall_active) begin
                if (stall_counter > 1) begin
                    stall_counter <= stall_counter - 1;
                    final_ready <= 0;
                end else begin
                    final_ready <= 1;
                    stall_counter <= 0;
                    stall_active <= 0;
                end
            end
        end
    end
    
    // Connect final ready to dut ready
    assign dut_ready = final_ready;
    
    // Burst queue tracking circuit
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
                $display("Time %0t: Burst queued - addr: 0x%0h, length: %0d, queue_size: %0d, Test count: %0d", 
                         $time, test_addr_array[array_index - 1], test_length_array[array_index - 1], burst_addr_queue.size(), test_count);
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
                    $display("  Expected: 0x%0h, Got: 0x%0h", expected_data_array[data_count], dut_data);
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
                        $display("Time %0t: Burst %0d completed - Start addr: 0x%0h, Length: %0d, Data count: %0d, Test count: %0d", 
                                 $time, burst_count, burst_addr_queue[burst_queue_index], burst_length_queue[burst_queue_index], burst_data_count + 1, test_count);
                        
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

### 3.3 実行用スクリプト

以下の指示でスクリプトを自動生成させます：
```
modelsim用にコンパイルと実行を行うスクリプトを作成してください。スクリプト名はテストベンチ名に合わせます。
```

## ライセンス

このプロジェクトは [Apache License 2.0](LICENSE) の下で公開されています。