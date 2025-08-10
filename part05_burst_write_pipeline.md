# AXIバスのパイプライン回路設計ガイド ～ 第５回 Payloadが合流するパイプラインAXIライトデータチャネルの模擬

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第５回 Payloadが合流するパイプラインAXIライトデータチャネルの模擬](#axiバスのパイプライン回路設計ガイド--第５回-payloadが合流するパイプラインaxiライトデータチャネルの模擬)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 データ増幅シナリオ](#21-データ増幅シナリオ)
    - [2.2 複数のReadyを制御するシナリオ](#22-複数のreadyを制御するシナリオ)
  - [3. ２つのペイロードが合流するパイプライン](#3-２つのペイロードが合流するパイプライン)
  - [4. シーケンス　バースト長４、データは連続して来る、d_readyはアサートのままのシーケンス](#4-シーケンスバースト長４データは連続して来るd_readyはアサートのままのシーケンス)
  - [5. サンプルコード](#5-サンプルコード)
    - [5.1 バーストライトパイプラインモジュール](#51-バーストライトパイプラインモジュール)
    - [5.2 バーストライトパイプラインテストベンチ](#52-バーストライトパイプラインテストベンチ)
  - [6. 本質要素抽象化とは](#6-本質要素抽象化とは)
    - [6.1 抽象化の重要性](#61-抽象化の重要性)
    - [6.2 3つの基本要素](#62-3つの基本要素)
    - [6.3 ValidとPayloadの関係](#63-validとpayloadの関係)
    - [6.4 Readyによる制御の統一性](#64-readyによる制御の統一性)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、パイプライン処理においてペイロードが合流する場合のAXIライトデータチャネルの動作を模擬します。前回までに学んだパイプライン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「バーストライト」シナリオを扱います。

バーストライトは、アドレスリクエストとライトデータが合流するシナリオです。パイプラインの途中で1つのPayload（アドレス）がバースト回数分に膨らみます。この膨らんだアドレスは書き込みデータに合流します。Payload-1(アドレス)の個数が増えるパイプラインステージより上流のパイプラインを停止して待機させる必要があります。また、Payload-1(アドレス)はPayload-2(データ)と合流しさらにPayload-3(レスポン)に受け渡されます。Readyの発生源はPayload-1(アドレス)のバースト、Payload-2(データ)の書き込み可能かどうか、Payload-3(レスポン)の下流側から入力されるReadyの３箇所あります。この３つのパイプラインにできるだけ無駄なサイクルが発生しない実装を考えます。

AXIライトチャネルの特徴を整理します：

- **アドレスチャネル**: 書き込みアドレスとバースト情報を伝達
- **データチャネル**: 実際のデータとストローブ信号を伝達
- **レスポンスチャネル**: 書き込み完了の応答を伝達

このようにあらゆる設計を本質要素抽象化により検討内容をシンプルにして進めます。

ライトパイプランの実装は管理するチャネルが３つになり、またReadyの条件が複雑化するため難易度が一気に上がります。しかしながら、ここまで進めてきた単純化・ルール化によって先の見通しはかなりいいはずです。

## 2. 動作原理

### 2.1 データ増幅シナリオ

データ増幅は第４回で解説した通り、パイプライン処理において1つの入力データが複数の出力データに変換される現象です。特に**バーストアクセス**では、1つのリクエストに対して複数のデータ応答が返されます。これはリードと同様にライトでも発生します。データ増幅の実装方法はすでに学んだ方法を使用します。

## 3. ２つのペイロードが合流するパイプライン

T0Aはアドレスをカウントする回路。T0Dはデータパイプラインをアドレスパイプラインと同じ位置に合わせる。
T1はT0AとT0Dの制御をすると同時に、アドレス、データ、WEを生成する。
T2はライトの結果としてレスポンスを生成する。AXIではLASTサイクルにレスポンスを返すルールになっているが、この回路では、書き込みが正常である証にアドレスとデータが同じでWEがアサートされているかどうかをチェックする。正常の場合はT1のアドレスを出力、異常の場合はペイロードに不定を出力する。

### 2.2 複数のReadyを制御するシナリオ

Ready信号は、アドレスチャネルのデータ増幅によるReady、データチャネルの書き込み待ちによるReady、レスポンスチャネルの最下流からのReadyの3つあります。データチャネルのReadyを除くと第4回の構造がそのまま使えます。
第4回と同様に複数のReadyのマージは非同期の論理ANDです。

Readyの制御について説明します。
このパイプライン全体のイネーブルを制御するd_Readyはレスポンスチャネルから入力されます。このd_ReadyがネゲートされるとT0,T1,T2のパイプラインを停止します。d_Readyは途中のパイプラインで生成されるReadyと非同期ANDされて上流に渡されます。
T1はデータとアドレスを待ち合わせるためのT0A_M_ReadyとT0D_M_Readyを生成します。T0A_M_Readyがアサートされる条件はT0DがValid && T0Aがnot Valid またはT0DとT0Aの両方がnot Valid　またはT0DとT0Aの両方がValidです。T0D_M_Readyがアサートされる条件は、T0Dがnot Valid && T0AがValid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValidです。T0A_M_ReadyとT0D_M_Readyはd_Readyと非同期ANDされて上流に渡されます。
T0Dはデータパイプラインです。T0D_Ready=Hの場合にペイロードをラッチします。
T0Aはアドレスパイプラインです。第４回の2.3章で説明したアドレスの回路と同じ動作をします。バーストの管理のためにT0A_Readyが生成されます。このT0A_ReadyはT0A_M_Readyと非同期ANDされて上流に渡されます。

```
u_Payload_D=> [T0D]=======++
               ^          ||
               |          ||
u_Ready_D   <-[AND]---+   ||
               ^      |   ||
               |      |   ||
     [T0D_Ready]      |   ||
                      |   ||
u_Payload_A=> [T0A] ===> [T1] => [T2] => d_Payload
               ^      |   ^       ^   
               |      |   |       |   
u_Ready_A   <-[AND]<--+---+-------+--- <- d_Ready
               ^ ^                     
               | |        
     [T0A_Ready] |        
            [T0A_M_Ready]
```

### 4. シーケンス　バースト長４、データは連続して来る、d_readyはアサートのままのシーケンス
```
Clock        : 123456789012345678901
Address      : xxxxxx044448888xxxxxx
Data         : xxxxxx0123456789ABxxx
Length       : xxxxxx333333333xxxxxx
Valid        : ______HHHHHHHHHHHH___
Ready        : HHHHHHH___H___H___HHH

T0A_Count    : FFFFFFF321032103210FF
T0A_Valid    : _______HHHHHHHHHHHH__
T0A_Last     : __________H___H___H__
T0A_Ready    : HHHHHHH___H___H___HHH

T0D_Data     : xxxxxxx0123456789ABxxx
T0D_Valid    : _______HHHHHHHHHHHH__
T0D_Ready    : HHHHHHHHHHHHHHHHHHHHH

T1_Address   : xxxxxxx0123456789ABxx
T1_Data      : xxxxxxx0123456789ABxx
T1_WE        : _______HHHHHHHHHHHH__
T1_Valid     : _______HHHHHHHHHHHH__
T1_Last      : __________H___H___H__

d_Response   : xxxxxxxx0123456789ABx
d_Valid      : ________HHHHHHHHHHHH_
d_Ready      : HHHHHHHHHHHHHHHHHHHHH
```

**シーケンスの説明**:

- **Clock 1-6**: リセット解除後の初期化期間
- **Clock 7**: バースト開始、アドレス0x04、長さ3（4回のバースト）
- **Clock 8-11**: アドレスカウンタが3→2→1→0とカウントダウン
- **Clock 12**: アドレスカウンタが0xFF（アイドル状態）に戻る
- **Clock 13**: 次のバースト開始、アドレス0x08、長さ3
- **Clock 14-17**: アドレスカウンタが3→2→1→0とカウントダウン
- **Clock 18-19**: アドレスカウンタが0xFF（アイドル状態）に戻る

**T1 stageの動作**:
- T1_Valid: T0A_Valid && T0D_Valid の条件で生成
- T1_Last: T0A_Last を転送

**T2 stage（出力）の動作**:
- d_Valid: T1_Valid を転送（T1がvalidな間、出力もvalid）
- d_Response: T1_Valid && (T1_addr == T1_data) && T1_we の条件でT1_addrを出力、それ以外は不定値
- この例では、アドレスとデータが一致しているため、アドレス値がそのままレスポンスとして出力される

## 3. サンプルコード

### 3.1 バーストライトパイプラインモジュール

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module burst_write_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Address Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_addr,
    input  wire [7:0]              u_length,  // Burst length - 1
    input  wire                     u_addr_valid,
    output wire                     u_addr_ready,
    
    // Upstream Data Interface (Input)
    input  wire [DATA_WIDTH-1:0]   u_data,
    input  wire                     u_data_valid,
    output wire                     u_data_ready,
    
    // Downstream Response Interface (Output)
    output wire [ADDR_WIDTH-1:0]   d_response,
    output wire                     d_valid,
    input  wire                     d_ready
);

    // T0A stage internal signals (Address counter)
    reg [7:0]                      t0a_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           t0a_mem_addr;  // Current memory address
    reg                             t0a_valid;     // T0A stage valid signal
    wire                            t0a_last;      // Last burst cycle indicator
    wire                            t0a_state_ready;     // T0A stage ready signal
    
    // T0D stage internal signals (Data pipeline)
    reg [DATA_WIDTH-1:0]           t0d_data;      // T0D stage data output
    reg                             t0d_valid;     // T0D stage valid signal
    reg                             t0d_ready;     // T0D stage ready signal
    
    // T1 stage internal signals (Merge control)
    reg [ADDR_WIDTH-1:0]           t1_addr;       // T1 stage address output
    reg [DATA_WIDTH-1:0]           t1_data;       // T1 stage data output
    wire                            t1_we;         // T1 stage write enable
    reg                             t1_valid;      // T1 stage valid signal
    reg                             t1_last;       // T1 stage last signal
    reg                             t1_ready;      // T1 stage ready signal
    
    // T2 stage internal signals (Response generation)
    reg [ADDR_WIDTH-1:0]           t2_response;   // T2 stage response output
    reg                             t2_valid;      // T2 stage valid signal
    reg                             t2_ready;      // T2 stage ready signal
    
    // Merge control signals
    wire                            t0a_m_ready;   // T0A merge ready signal
    wire                            t0d_m_ready;   // T0D merge ready signal
    
    // Downstream interface assignments
    assign d_response = t2_response;
    assign d_valid = t2_valid;
    
    // T1 write enable assignment
    assign t1_we = t1_valid;
    
    // T0A stage control signals
    assign t0a_state_ready = (t0a_count == 8'hFF) || (t0a_count == 8'h00); // Ready when idle or last cycle
    assign t0a_last = (t0a_count == 8'h00); // Last cycle when counter reaches 0
    
    // Ready signal assignments
    assign u_addr_ready = t0a_state_ready && t0a_m_ready && d_ready; // Upstream address ready when all conditions met
    assign u_data_ready = t0d_ready && t0d_m_ready && d_ready;       // Upstream data ready when all conditions met
    
    // Merge ready generation
    // T0A_M_Ready: T0DがValid && T0Aがnot Valid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0a_m_ready = (t0d_valid && !t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    // T0D_M_Ready: T0Dがnot Valid && T0AがValid またはT0DとT0Aの両方がnot Valid またはT0DとT0Aの両方がValid
    assign t0d_m_ready = (!t0d_valid && t0a_valid) || (!t0d_valid && !t0a_valid) || (t0d_valid && t0a_valid);
    
    // T0A stage control logic (Address counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0a_count <= 8'hFF;                        // Initialize to idle state
            t0a_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            t0a_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_ready) begin
            if (t0a_m_ready) begin
                case (t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        t0a_count <= u_length;          // Load burst length
                        t0a_mem_addr <= u_addr;         // Load start address
                        t0a_valid <= u_addr_valid;      // Set valid based on upstream
                    end
                    1'b0: begin // Not ready state (Bursting)
                        t0a_count <= t0a_count - 8'h01; // Decrement burst counter
                        t0a_mem_addr <= t0a_mem_addr + 1; // Increment memory address
                        t0a_valid <= 1'b1;              // Keep valid during burst
                    end
                endcase
            end
        end
    end
    
    // T0D stage control logic (Data pipeline)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t0d_data <= {DATA_WIDTH{1'b0}};             // Initialize data to 0
            t0d_valid <= 1'b0;                          // Initialize valid to 0
            t0d_ready <= 1'b1;                          // Initialize ready to 1
        end else if (d_ready) begin
            if (t0d_m_ready) begin
                t0d_data <= u_data;                     // Update data from upstream
                t0d_valid <= u_data_valid;              // Set valid based on upstream
            end
        end
    end
    
    // T1 stage control logic (Merge control)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            t1_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            t1_valid <= 1'b0;                           // Initialize valid to 0
            t1_last <= 1'b0;                            // Initialize last to 0
        end else if (d_ready) begin
            t1_addr <= t0a_mem_addr;                    // Forward T0A address
            t1_data <= t0d_data;                        // Forward T0D data
            t1_valid <= (t0a_valid && t0d_valid);       // Valid when both T0A and T0D are valid
            t1_last <= t0a_last;                        // Forward T0A last signal
        end
    end
    
    // T2 stage control logic (Response generation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t2_response <= {ADDR_WIDTH{1'b0}};           // Initialize response to 0
            t2_valid <= 1'b0;                           // Initialize valid to 0
            t2_ready <= 1'b1;                           // Initialize ready to 1
        end else if (d_ready) begin
            t2_valid <= t1_valid;                       // Forward T1 valid signal
            t2_response <= ((t1_addr == t1_data) && t1_we) ? t1_addr : {ADDR_WIDTH{1'bx}}; // Generate response based on condition
        end
    end

endmodule
```

</div>

**コードの特徴**:
1. **3つのパイプライン**: T0A（アドレス）、T0D（データ）、T1（合流制御）、T2（レスポンス生成）の4段階構成
2. **Ready制御の統合**: パイプライン全体が`d_ready`信号で制御されており、各ステージの動作はReadyがHの時のみ実行されます
3. **Merge制御**: T0AとT0Dのデータを適切なタイミングで合流させる制御ロジック
4. **レスポンス生成**: アドレスとデータが一致し、書き込みが有効な場合のみアドレス値をレスポンスとして出力
5. **バースト制御**: T0Aステージでバースト長の管理とアドレスのカウントアップを実装
### 3.2 バーストライトパイプラインテストベンチ

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.
`timescale 1ns / 1ps

module burst_write_pipeline_tb #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4,   // Maximum burst length for testing
    parameter TEST_COUNT = 1000,      // Number of test
    parameter BUBBLE_N = 2,           // Base number of bubble cycles
    parameter STALL_N = 2             // Base number of stall cycles
)();

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;
    
    // Test pattern generator signals - Address interface
    reg  [ADDR_WIDTH-1:0]  test_addr;
    reg  [7:0]             test_length;
    reg                     test_addr_valid;
    wire                    test_addr_ready;
    
    // Test pattern generator signals - Data interface
    reg  [DATA_WIDTH-1:0]  test_data;
    reg                     test_data_valid;
    wire                    test_data_ready;
    
    // Test pattern arrays (queue arrays) - Address interface
    reg  [ADDR_WIDTH-1:0]  test_addr_array [$];
    reg  [7:0]             test_length_array [$];
    reg                     test_addr_valid_array [$];
    
    // Test pattern arrays (queue arrays) - Data interface
    reg  [DATA_WIDTH-1:0]  test_data_array [$];
    reg                     test_data_valid_array [$];
    
    // Expected response arrays
    reg  [ADDR_WIDTH-1:0]  expected_response_array [$];
    reg                     expected_valid_array [$];
    
    // Stall control arrays
    reg  [2:0]             stall_cycles_array [$];
    
    // Array control variables
    integer                 array_index;
    integer                 array_size;
    integer                 expected_response_index;
    integer                 stall_index;
    
    // DUT interface signals
    wire [ADDR_WIDTH-1:0]  dut_response;
    wire                    dut_valid;
    wire                    dut_ready;
    
    // Test control signals
    reg                     final_ready;
    integer                 test_count;
    integer                 burst_count;
    integer                 response_count;
    integer                 valid_address_count;
    integer                 valid_data_count;
    integer                 bubble_count;
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_burst_addr;
    reg [7:0]              current_burst_length;
    integer                 burst_response_count;
    
    // DUT instance
    burst_write_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .u_addr(test_addr),
        .u_length(test_length),
        .u_addr_valid(test_addr_valid),
        .u_addr_ready(test_addr_ready),
        .u_data(test_data),
        .u_data_valid(test_data_valid),
        .u_data_ready(test_data_ready),
        .d_response(dut_response),
        .d_valid(dut_valid),
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
        integer bubble_cycles;
        integer data_value;
        
        // Initialize test pattern arrays
        array_size = 0;
        expected_response_index = 0;
        stall_index = 0;
        valid_address_count = 0;
        valid_data_count = 0;
        bubble_count = 0;
        burst_response_count = 0;
        
        // Initialize test signals to avoid X values
        test_addr = 0;
        test_length = 0;
        test_addr_valid = 0;
        test_data = 0;
        test_data_valid = 0;
        
        // Generate test pattern arrays
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Generate random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Add valid burst request - Address interface
            test_addr_array.push_back(i * 16);  // Start address
            test_length_array.push_back(burst_length - 1);  // Length - 1
            test_addr_valid_array.push_back(1);
            valid_address_count = valid_address_count + 1;
            
            // Add valid data - Data interface
            for (j = 0; j < burst_length; j = j + 1) begin
                data_value = (i * 16) + j;  // Same as address for successful write
                test_data_array.push_back(data_value);
                test_data_valid_array.push_back(1);
                valid_data_count = valid_data_count + 1;
                
                // Expected response (address value for successful write)
                expected_response_array.push_back(data_value);
                expected_valid_array.push_back(1);
                expected_response_index = expected_response_index + 1;
            end
            
            // Generate bubble cycles for address interface
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Add bubbles for address
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_addr_array.push_back(0);
                test_length_array.push_back(0);
                test_addr_valid_array.push_back(0);
                bubble_count = bubble_count + 1;
            end
            
            // Generate bubble cycles for data interface
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Add bubbles for data
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_data_array.push_back(0);
                test_data_valid_array.push_back(0);
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
        $display("  Total data patterns: %0d", test_data_array.size());
        $display("  Valid address patterns: %0d", valid_address_count);
        $display("  Valid data patterns: %0d", valid_data_count);
        $display("  Bubble patterns: %0d", bubble_count);
        $display("  Expected responses: %0d", expected_response_index);
    end
    
    // Test pattern generator - Address interface
    reg [31:0] addr_array_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            test_addr <= 0;
            test_length <= 0;
            test_addr_valid <= 0;
            addr_array_index <= 0;
        end else begin
            if (addr_array_index < test_addr_array.size()) begin
                if (test_addr_ready) begin
                    test_addr <= test_addr_array[addr_array_index];
                    test_length <= test_length_array[addr_array_index];
                    test_addr_valid <= test_addr_valid_array[addr_array_index];
                    addr_array_index <= addr_array_index + 1;
                end
            end else begin
                test_addr_valid <= 0;
            end
        end
    end
    
    // Test pattern generator - Data interface
    reg [31:0] data_array_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            test_data <= 0;
            test_data_valid <= 0;
            data_array_index <= 0;
        end else begin
            if (data_array_index < test_data_array.size()) begin
                if (test_data_ready) begin
                    test_data <= test_data_array[data_array_index];
                    test_data_valid <= test_data_valid_array[data_array_index];
                    data_array_index <= data_array_index + 1;
                end
            end else begin
                test_data_valid <= 0;
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
    
    // Test result checker circuit
    always @(posedge clk) begin
        if (!rst_n) begin
            test_count <= 0;
            burst_count <= 0;
            response_count <= 0;
            burst_response_count <= 0;
        end else begin
            // Check if test count reached maximum
            if (response_count >= expected_response_index) begin
                $display("Test completed:");
                $display("  Total address patterns: %0d", test_addr_array.size());
                $display("  Total data patterns: %0d", test_data_array.size());
                $display("  Valid address patterns: %0d", valid_address_count);
                $display("  Valid data patterns: %0d", valid_data_count);
                $display("  Bubble patterns: %0d", bubble_count);
                $display("  Total responses: %0d", test_count);
                $display("  Max burst length: %0d", MAX_BURST_LENGTH);
                $display("  Bubble cycles (BUBBLE_N): %0d", BUBBLE_N);
                $display("  Stall cycles (STALL_N): %0d", STALL_N);
                $display("  Total stall cycles generated: %0d", stall_cycles_array.size());
                $display("PASS: All tests passed");
                repeat (1) @(posedge clk);
                $finish;
            end
            
            // Check final output response
            if (dut_valid && dut_ready) begin
                test_count <= test_count + 1;
                burst_response_count <= burst_response_count + 1;
                
                // Check if response matches expected value from array
                if (dut_response !== expected_response_array[response_count]) begin
                    $display("ERROR: Response mismatch at test %0d", test_count);
                    $display("  Time: %0t", $time);
                    $display("  Signal: dut_response");
                    $display("  Expected: 0x%0h, Got: 0x%0h", expected_response_array[response_count], dut_response);
                    $display("  Debug - T1_addr: 0x%0h, T1_data: 0x%0h, T1_we: %0d, T1_valid: %0d", 
                             dut.t1_addr, dut.t1_data, dut.t1_we, dut.t1_valid);
                    $display("  Test count: %0d, Response count: %0d", test_count, response_count);
                    repeat (1) @(posedge clk);
                    $finish;
                end else begin
                    // Success message with test count
                    $display("Time %0t: Test %0d passed - Response: 0x%0h, Test count: %0d, Response count: %0d", 
                             $time, test_count, dut_response, test_count, response_count);
                end
                
                response_count <= response_count + 1;
                
                // Report burst information
                if (dut.t1_last) begin
                    burst_count <= burst_count + 1;
                    $display("Time %0t: Burst %0d completed - Response count: %0d, Test count: %0d", 
                             $time, burst_count, burst_response_count + 1, test_count);
                    burst_response_count <= 0;
                end
            end
        end
    end
    
    // Debug signal monitoring
    always @(posedge clk) begin
        if (dut.t1_valid && dut_ready) begin
            $display("Time %0t: T1 Debug - addr: %0d, data: %0d, we: %0d, valid: %0d, last: %0d", 
                     $time, dut.t1_addr, dut.t1_data, dut.t1_we, dut.t1_valid, dut.t1_last);
        end
    end

endmodule
```

</div>

**コードの特徴**:
1. **2つのインターフェース**: アドレスインターフェースとデータインターフェースを独立して制御
2. **キュー配列によるテストデータ管理**: アドレス、データ、期待値、ストール制御をキュー配列で管理
3. **バースト制御のテスト**: バースト長のランダム生成とバースト完了の検証
4. **デバッグ信号監視**: T1ステージの内部信号を監視してデバッグ情報を出力
5. **包括的なテスト**: バブルサイクル、ストールサイクル、データ整合性の検証

#### テストベンチの構造

テストベンチは以下の主要セクションで構成されています：

- **Clock and Reset**: クロック生成とリセット制御
- **Test pattern generator signals**: アドレスとデータのテスト信号生成
- **Test pattern arrays**: テストデータを格納するキュー配列
- **Expected response arrays**: 期待されるレスポンスデータ
- **Stall control arrays**: ストール制御用の配列
- **Array control variables**: 配列制御用の変数
- **DUT interface signals**: DUTとのインターフェース信号
- **Test control signals**: テスト制御用の信号
- **Burst tracking for reporting**: バースト追跡用の信号
- **DUT instance**: デバイスアンダーテストのインスタンス
- **Clock generation**: クロック生成回路
- **Reset generation**: リセット生成回路
- **Test data initialization**: テストデータの初期化
- **Test pattern generator**: アドレスとデータのテストパターン生成
- **Downstream Ready control circuit**: 下流Ready制御回路
- **Test result checker circuit**: テスト結果チェック回路
- **Debug signal monitoring**: デバッグ信号監視

#### テスト信号の参照方法

T1 stageのデバッグ信号は以下のように階層名で参照します：

```systemverilog
// デバッグ信号の監視
always @(posedge clk) begin
    if (dut.t1_valid && dut_ready) begin
        $display("Time %0t: T1 Debug - addr: %0d, data: %0d, we: %0d, valid: %0d, last: %0d",
                 $time, dut.t1_addr, dut.t1_data, dut.t1_we, dut.t1_valid, dut.t1_last);
    end
end
```



## 5. 本質要素抽象化とは

本質要素抽象化とは、複雑な設計課題を基本的な要素に分解し、それぞれの要素を独立して検討することで、全体の設計をシンプルにする手法です。複雑なシステムを設計する際、すべての要素を同時に考慮すると設計が困難になります。本質要素抽象化では、システムを制御要素、データ要素に分解します。

また、名称は具体名ではなく本質的にその機能を指し示す抽象的な名称にして、同じグループであるかそれとも別のグループであるかを明確にします。ここまで使用された抽象的な名称はReady、Valid、Payloadです。パイプラインは本質的にこの3種類の信号で説明が可能です。

### 抽象化の重要性

抽象化により、具体的な実装詳細に囚われることなく、システムの本質的な動作を理解できます。例えば、AXIプロトコルの詳細な信号名（AWVALID、WREADY、BRESPなど）ではなく、Ready、Valid、Payloadという抽象的な概念で考えることで、パイプラインの基本動作を理解しやすくなります。

### 3つの基本要素

**Ready**: データを受け取れる状態を示す制御信号
**Valid**: データが有効であることを示す制御信号  
**Payload**: 転送されるデータそのもの

### ValidとPayloadの関係

重要な洞察として、**Validは本質的にはPayloadである**ということができます。Valid信号は、その時点で有効なデータ（Payload）が存在するかどうかを示す制御情報ですが、これは実際には「データの有効性」という情報自体がPayloadとして機能していることを意味します。

つまり、Valid信号は：
- データチャネルでは「データが有効である」という情報を伝達
- 制御チャネルでは「制御情報が有効である」という情報を伝達
- アドレスチャネルでは「アドレスが有効である」という情報を伝達

このように、Validは各チャネルにおいて「何が有効であるか」という具体的なPayload情報を伝達する役割を果たしています。したがって、ValidとPayloadは密接に関連しており、ValidはPayloadの有効性を示すメタデータとして機能していると言えます。

### Readyによる制御の統一性

さらに重要な点として、**ValidとPayloadはいずれもReadyで制御されている**という統一性があります。これは、パイプライン設計における制御の本質を表しています：

- **Ready信号の役割**: Ready信号は、下流のステージがデータを受け取れる状態であることを示し、上流のステージに対してデータ転送の許可を与えます。

- **ValidとPayloadの制御**: Valid信号（データの有効性）とPayload（実際のデータ）の両方が、下流からのReady信号によって制御されます。Readyがアサートされていない場合、ValidとPayloadは下流に伝播されません。

- **制御の階層構造**: この制御構造により、パイプライン全体の流れが統一され、データの整合性が保たれます。Ready信号は、パイプラインの各段階における「流れの制御」を司る中心的役割を果たしています。

この統一性により、複雑なパイプラインシステムでも、Ready、Valid、Payloadの3つの基本要素だけで制御構造を理解し、設計することが可能になります。

この3つの要素により、あらゆるパイプラインの動作を統一的に記述できます。具体的なプロトコルや信号名に関係なく、パイプラインの本質的な動作を理解するための強力なツールとなります。

---

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details.
