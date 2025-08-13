# AXIバスのパイプライン回路設計ガイド ～ 第６回 統合ステート管理によるリードライトパイプラインの実装

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第６回 統合ステート管理によるリードライトパイプラインの実装](#axiバスのパイプライン回路設計ガイド--第６回-統合ステート管理によるリードライトパイプラインの実装)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 リードライトの合流シナリオ](#21-リードライトの合流シナリオ)
    - [2.2 優先順位の調停シナリオ](#22-優先順位の調停シナリオ)
  - [3. リードライトが合流するパイプライン](#3-リードライトが合流するパイプライン)
    - [3.1 Readパイプライン（第４回のサンプルコードより）](#31-readパイプライン第４回のサンプルコードより)
    - [3.2 Writeパイプライン（第５回のサンプルコードより）](#32-writeパイプライン第５回のサンプルコードより)
  - [4. シーケンス　リードとライトが混在するバーストアクセスのシーケンス](#4-シーケンスリードとライトが混在するバーストアクセスのシーケンス)
  - [5. サンプルコード](#5-サンプルコード)
    - [5.1 リードライトパイプラインモジュール](#51-リードライトパイプラインモジュール)
    - [5.2 リードライトパイプラインテストベンチ](#52-リードライトパイプラインテストベンチ)
  - [6. 条件網羅法と条件刈込法](#6-条件網羅法と条件刈込法)
    - [6.1 条件網羅法とは](#61-条件網羅法とは)
    - [6.2 条件刈込法とは](#62-条件刈込法とは)
    - [6.3 実装例での適用](#63-実装例での適用)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、パイプライン処理においてリードとライトの統合制御を実現するAXIリードライトパイプラインの実装について説明します。前回までに学んだパイプライン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「リードライト統合制御」シナリオを扱います。

リードライト統合制御は、リードリクエストとライトリクエストを単一のパイプラインで効率的に処理する仕組みです。T1ステージでの統合されたステート管理により、明確な優先度制御とパイプライン制御を実現します。この統合制御により、リードとライトの処理順序が制御され、データの整合性が保たれます。

**統合パイプラインの特徴**:
- **Readパイプライン**: 3段構成でデータ増幅、ステート制御、メモリアクセスを実現
- **Writeパイプライン**: 5段構成でアドレス・データ合流、ステート制御、メモリアクセス、レスポンス生成を実現
- **T1ステージ統合**: 両パイプラインの優先度制御とステート管理を**共通ステートマシン**で統合
- **制御信号の統合**: `t1_r_ready`、`t1_w_ready`によるパイプライン制御の統合

AXIリードライトチャネルの特徴を整理します：

- **リードチャネル**: 読み出しアドレスとバースト情報を伝達
- **ライトチャネル**: 書き込みアドレス、データ、バースト情報を伝達
- **レスポンスチャネル**: 書き込み完了の応答を伝達

リード・ライト独立動作の場合は、第4回と第5回の両方を実装するだけですが、シングルポートのRAMにアクセスする場合は、同一時間でのリード・ライト両方はできないため、順番を決めてRAMにアクセスします。統合ステート管理は第5回のライトのアドレス・データの合流と類似のロジックが使えます。違いは、リードとライトのどちらを優先して、どのような順番で実行するかという点です。

**統合パイプラインの利点**:
- **効率的なリソース利用**: 単一のパイプラインでリード・ライト両方を処理
- **明確な優先度制御**: T1ステージでの統合されたステート管理
- **共通ステートマシン**: Read・Write両方のパイプラインを同一のステートマシンで制御
- **分離された機能**: T1ステージ（ステート制御）とT2ステージ（メモリアクセス）の役割分離
- **統一されたメモリアクセス**: Read・Write両方のT2ステージでメモリアクセスを実現
- **拡張性**: 3段・5段構成による柔軟なパイプライン設計
- **制御の統一**: `t1_r_ready`、`t1_w_ready`による統合制御

## 2. 動作原理

### 2.1 リードライトの合流シナリオ

リードライトの合流は、パイプライン処理においてリードリクエストとライトリクエストが同じパイプラインを通過する現象です。リードライトの合流の実装方法はすでに学んだ第５回のライトのアドレス、データの合流と同様の方法を使用します。

### 2.2 優先順位の調停シナリオ

優先順位の調停は、リードとライトのリクエストが同時に存在する場合に、どちらを優先して処理するかを決定する仕組みです。この調停により、リードとライトの処理順序が制御され、データの整合性が保たれます。

優先順位の調停方式には以下の3種類があります：

- **リード優先方式**: リードリクエストが常にライトリクエストより優先される
- **ライト優先方式**: ライトリクエストが常にリードリクエストより優先される  
- **ラウンドロビン方式（今回採用）**: リードとライトのリクエストを交互に処理する

ラウンドロビン方式では、リードとライトのリクエストを交互に処理します。この方式の特徴は以下の通りです：

- **メリット**: リードとライトの公平性が保たれる、スタベーションが発生しにくい
- **デメリット**: 最適なレイテンシが得られない場合がある
- **適用場面**: バランスの取れた性能が要求されるシステム、リードとライトの処理量が同程度の場合

**今回の実装方針**:
T1ステージで5つのステートを使用して状態管理を行います：

- `STATE_IDLE`: アイドル状態（0: 3'b000）
- `STATE_R_NLAST`: リード実行中（1: 3'b001）
- `STATE_R_LAST`: リード完了（2: 3'b010）
- `STATE_W_NLAST`: ライト実行中（3: 3'b011）
- `STATE_W_LAST`: ライト完了（4: 3'b100）

**パイプライン構成**:
- **Readパイプライン**: 3段構成（T0 → T1 → T2）
  - T0: データ増幅とアドレス生成
  - T1: ステートマシン制御（Read/Write優先度制御）
  - T2: メモリアクセスとデータ出力
- **Writeパイプライン**: 5段構成（T0A → T0D → T1 → T2 → T3）
  - T0A: アドレス生成とバースト制御
  - T0D: データパイプライン処理
  - T1: ステートマシン制御（Read/Write優先度制御）**共通ステートマシン**
  - T2: メモリアクセス（メモリへの書き込み）
  - T3: レスポンス生成
- **統合制御**: T1ステージでの優先度制御とステート管理

**ステートの動作**:

- `STATE_IDLE`: リード・ライトの要求待ち状態
- `STATE_R_NLAST/STATE_R_LAST`: リード実行中・完了状態
- `STATE_W_NLAST/STATE_W_LAST`: ライト実行中・完了状態

**初期値**: 

- `t1_current_state = STATE_IDLE`（アイドル状態として開始）

**優先度制御**:

1. **アイドル状態**: 書き込み要求を優先（`d_w_ready && (w_t0a_valid && w_t0d_valid)`）
2. **リード状態**: 書き込み要求を優先（`d_w_ready && (w_t0a_valid && w_t0d_valid)`）
3. **ライト状態**: リード要求を優先（`d_r_ready && r_t0_valid`）
4. **パイプライン制御**: `d_r_ready`、`d_w_ready`、`t1_r_ready`、`t1_w_ready`が各状態の遷移を制御

この方式により、書き込み優先の制御が実現され、データの整合性が保たれます。

## 3. リードライトが合流するパイプライン

本章では、リードライトが合流するパイプラインの構造について説明します。まず、ReadとWriteの各パイプラインの基本構造を説明し、その後で結合部分の動作について詳しく説明します。

### 3.1 Readパイプライン（第４回のサンプルコードより）

Readパイプラインは3段構成で、データ増幅を行うパイプラインです。

#### T0ステージ（アドレスカウンタとRE制御）
- バースト転送の制御とアドレス生成
- 1つのPayload（アドレス）がバースト回数分に増幅（1→4個に増加）
- 上流に対するReady制御

#### T1ステージ（ステートマシン制御）
- ReadとWriteの優先度制御
- ステート遷移の管理
- 下流のd_Readyで制御される

#### T2ステージ（メモリアクセス）
- メモリからのデータ読み出し
- ステートに応じたデータの有効化
- アドレス値をデータとして出力

**パイプライン構成**:

```
u_r_Payload -> [T0] -> [T1] -> [T2] -> d_r_Payload
                ^       ^       ^
                |       |       |
u_r_Ready   <-[AND]<----+-------+-- <- d_r_Ready
                ^
                |
            [T0_State_Ready]
```

**T1ステージの役割**: ReadとWriteのステートマシン制御
**T2ステージの役割**: メモリアクセスとデータ出力

### 3.2 Writeパイプライン（第５回のサンプルコードより）

Writeパイプラインは5段構成で、2つのペイロードが合流するパイプラインです。

#### T0Aステージ（アドレスカウンタ）
- バースト転送の制御とアドレス生成
- 1つのPayload（アドレス）がバースト回数分に増幅（1→4個に増加）

#### T0Dステージ（データパイプライン）
- データのパイプライン処理
- データ増幅なし（4個維持）

#### T1ステージ（ステートマシン制御）
- ReadとWriteの優先度制御
- ステート遷移の管理

#### T2ステージ（メモリアクセス）
- アドレスとデータの保持
- メモリへの書き込みアクセス

#### T3ステージ（レスポンス生成）
- 書き込み完了の応答生成
- アドレスとデータが一致し、書き込みが有効な場合のみアドレス値をレスポンスとして出力

**パイプライン構成**:

```
u_w_Payload_D=> [T0D]=======++
                 ^          ||
                 |          ||
u_w_Ready_D   <-[AND]---+   ||
                 ^      |   ||
                 |      |   ||
       [T0D_Ready]      |   ||
                        |   ||
u_w_Payload_A=> [T0A] ===> [T1] => [T2] => [T3] => d_w_Payload
                 ^      |   ^       ^       ^   
                 |      |   |       |       |   
u_w_Ready_A   <-[AND]<--+---+-------+-------+--- <- d_w_Ready
                 ^ ^                     
                 | |        
       [T0A_Ready] |        
              [T0A_M_Ready]
```

### 3.3 結合部分の説明

リードライトパイプラインでは、ReadとWriteのパイプラインが合流し、優先順位の調停を行います。

**合流のポイント**:

- Readパイプライン: T0 → T1 → T2 → 出力
- Writeパイプライン: T0A + T0D → T1 → T2 → T3 → 出力（T0AとT0DがT1で合流）
- 両パイプラインがT1ステージで合流

**T1ステージでの結合**:

- T1ステージでリード・ライトの優先度制御を実行（**共通ステートマシン**）
- RE（Read Enable）とWE（Write Enable）は排他的にアサート可能
- 6つの制御信号（`d_r_ready`, `r_t0_valid`, `d_w_ready`, `w_t0a_valid && w_t0d_valid`, `t1_r_ready`, `t1_w_ready`）で状態遷移を制御
- Read・Write両方のパイプラインが同一のT1ステージで統合制御

**優先度制御**:

- T1ステージで5つのステート（`STATE_IDLE`, `STATE_R_NLAST`, `STATE_R_LAST`, `STATE_W_NLAST`, `STATE_W_LAST`）による状態管理
- アイドル状態とリード状態では書き込み要求を優先
- ライト状態ではリード要求を優先
- 各状態で`d_r_ready`と`d_w_ready`によるパイプライン制御

**制御の統合**:

- リードパイプラインは`d_r_ready`と`t1_r_ready`信号で制御
- ライトパイプラインは`d_w_ready`と`t1_w_ready`信号で制御
- T1ステージでステート遷移ロジックを統合管理
- 各ステージの動作はReadyがHの時のみ実行
- if文ベースの優先度制御による明確な制御構造
- 優先度制御信号（`t1_r_ready`, `t1_w_ready`）によるパイプライン制御の統合

## 4. シーケンス - リードとライトが混在するバーストアクセスのシーケンス
```
[Write]-------------------------------------
Clock           : 12345678901234567890123456
w_T0A_Count     : FFFFFFF321033333210FFFFFFF
w_T0A_Valid     : _______HHHHHHHHHHHH_______
w_T0A_Last      : __________H_______H_______
w_T0A_Ready     : HHHHHHH___H_______HHHHHHHH

w_T1_Address    : xxxxxxxx012333334567777xxx
w_T1_Valid      : ________HHHHHHHHHHHH______
w_T1_Last       : ___________H_______H______

[State]-------------------------------------
t1_next_state   : IIIIIIIWWWwRRRrWWWwRRRrIII
t1_current_state: IIIIIIIIWWWwRRRrWWWwRRRrII
t1_w_ready      : HHHHHHHHHHH____HHHH____HHH
t1_r_ready      : HHHHHHH____HHHH____HHHHHHH

[Read]--------------------------------------
r_T0_Count      : FFFFFFF3333321033333210FFF
r_T0_Valid      : _______HHHHHHHHHHHHHHHH___
r_T0_Last       : ______________H_______H___

r_T1_Address    : xxxxxxxx0000012344444567xx
r_T1_Valid      : ________HHHHHHHHHHHHHHHH__
r_T1_Last       : _______________H_______H__
```

## 5. サンプルコード

AIに以下のように指示してコードを作成してください：

```
ここまでのドキュメントの記述を読んで、コードを実装してください。モジュール名はburst_rw_pipeline、ファイル名はburst_rw_pipeline.vとします。2つのソースコードburst_write_pipeline.v、burst_read_pipeline.vを改良して新しいファイルの中に記述して、そこに追加の機能を実装してください。参照する2つのファイルには同じ信号名が出てきますので仕様書を注意深く読んで信号のリネームを行ってください。リードとライトの両方にT1ステージを挿入して、このT1ステージを優先順位の調停に使用します。

テストベンチはburst_read_pipeline_tb.svとburst_write_pipeline_tb.svの構造とテスト内容をそのまま継承してください。
```
### 5.1 リードライトパイプラインモジュール

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.

module burst_rw_pipeline #(
    parameter DATA_WIDTH = 32,        // Data width in bits
    parameter ADDR_WIDTH = 32,        // Address width in bits
    parameter MAX_BURST_LENGTH = 4    // Maximum burst length
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Read Upstream Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_r_addr,
    input  wire [7:0]              u_r_length,  // Burst length - 1
    input  wire                     u_r_valid,
    output wire                     u_r_ready,
    
    // Write Upstream Address Interface (Input)
    input  wire [ADDR_WIDTH-1:0]   u_w_addr,
    input  wire [7:0]              u_w_length,  // Burst length - 1
    input  wire                     u_w_addr_valid,
    output wire                     u_w_addr_ready,
    
    // Write Upstream Data Interface (Input)
    input  wire [DATA_WIDTH-1:0]   u_w_data,
    input  wire                     u_w_data_valid,
    output wire                     u_w_data_ready,
    
    // Read Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]   d_r_data,
    output wire                     d_r_valid,
    output wire                     d_r_last,
    input  wire                     d_r_ready,
    
    // Write Downstream Response Interface (Output)
    output wire [ADDR_WIDTH-1:0]   d_w_response,
    output wire                     d_w_valid,
    input  wire                     d_w_ready
);

    // State definitions
    localparam STATE_IDLE           = 3'b000;
    localparam STATE_R_NLAST        = 3'b001;
    localparam STATE_R_LAST         = 3'b010;
    localparam STATE_W_NLAST        = 3'b011;
    localparam STATE_W_LAST         = 3'b100;

    // State management (T1 stage control)
    reg [2:0]                      t1_current_state;  // Current state
    reg [2:0]                      t1_next_state;     // Next state for combinational logic
    
    // Read T0 stage internal signals
    reg [7:0]                      r_t0_count;        // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           r_t0_mem_addr;    // Current memory address
    wire                            r_t0_mem_read_en; // Memory read enable signal
    reg                             r_t0_valid;       // T0 stage valid signal
    wire                            r_t0_last;        // Last burst cycle indicator
    wire                            r_t0_state_ready; // T0 stage ready signal
    
    // Read T1 stage internal signals
    reg [ADDR_WIDTH-1:0]           r_t1_addr;        // T1 stage address output
    reg                             r_t1_valid;       // T1 stage valid signal
    reg                             r_t1_last;        // T1 stage last signal
    
    // Read T2 stage internal signals
    reg [DATA_WIDTH-1:0]           r_t2_data;        // T2 stage data output
    reg                             r_t2_valid;       // T2 stage valid signal
    reg                             r_t2_last;        // T2 stage last signal
    
    // Write T0A stage internal signals
    reg [7:0]                      w_t0a_count;      // Burst counter (0xFF = idle, 0x00 = last)
    reg [ADDR_WIDTH-1:0]           w_t0a_mem_addr;  // Current memory address
    reg                             w_t0a_valid;     // T0A stage valid signal
    wire                            w_t0a_last;      // Last burst cycle indicator
    wire                            w_t0a_state_ready; // T0A stage ready signal
    
    // Write T0D stage internal signals
    reg [DATA_WIDTH-1:0]           w_t0d_data;      // T0D stage data output
    reg                             w_t0d_valid;     // T0D stage data valid signal
    
    // Write T1 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t1_addr;       // T1 stage address output
    reg [DATA_WIDTH-1:0]           w_t1_data;       // T1 stage data output
    wire                            w_t1_we;         // T1 stage write enable
    reg                             w_t1_valid;      // T1 stage valid signal
    reg                             w_t1_last;       // T1 stage last signal
    
    // Write T2 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t2_addr;       // T2 stage address output
    reg [DATA_WIDTH-1:0]           w_t2_data;       // T2 stage data output
    wire                            w_t2_we;         // T2 stage write enable
    reg                             w_t2_valid;      // T2 stage valid signal
    reg                             w_t2_last;       // T2 stage last signal
    
    // Write T3 stage internal signals
    reg [ADDR_WIDTH-1:0]           w_t3_response;   // T3 stage response output
    reg                             w_t3_valid;      // T3 stage valid signal
    reg                             w_t3_last;       // T3 stage last signal
    
    // Merge control signals
    wire                            w_t0a_m_ready;   // T0A merge ready signal
    wire                            w_t0d_m_ready;   // T0D merge ready signal
    
    // Priority arbitration signals
    wire                            t1_r_ready;      // T1 Read ready signal
    wire                            t1_w_ready;      // T1 Write ready signal
    
    // Downstream interface assignments
    assign d_r_data  = r_t2_data;
    assign d_r_valid = r_t2_valid;
    assign d_r_last  = r_t2_last;
    
    assign d_w_response = w_t3_response;
    assign d_w_valid = w_t3_valid;
    
    // T1 and T2 write enable assignment
    assign w_t1_we = w_t1_valid;
    assign w_t2_we = w_t2_valid;
    
    // Read T0 stage control signals
    assign r_t0_state_ready = (r_t0_count == 8'hFF) || (r_t0_count == 8'h00); // Ready when idle or last cycle
    assign r_t0_last = (r_t0_count == 8'h00);        // Last cycle when counter reaches 0
    assign r_t0_mem_read_en = (r_t0_count != 8'hFF); // Enable memory read when not idle
    
    // Write T0A stage control signals
    assign w_t0a_state_ready = (w_t0a_count == 8'hFF) || (w_t0a_count == 8'h00); // Ready when idle or last cycle
    assign w_t0a_last = (w_t0a_count == 8'h00);      // Last cycle when counter reaches 0
    
    // Priority arbitration logic
    assign t1_r_ready =
    t1_next_state == STATE_IDLE ||
    t1_next_state == STATE_R_NLAST ||
    t1_next_state == STATE_R_LAST;

    assign t1_w_ready =
    t1_next_state == STATE_IDLE ||
    t1_next_state == STATE_W_NLAST ||
    t1_next_state == STATE_W_LAST;

    // Ready signal assignments
    assign u_r_ready = r_t0_state_ready && t1_r_ready && d_r_ready;           // Read upstream ready
    assign u_w_addr_ready = w_t0a_state_ready && w_t0a_m_ready && t1_w_ready && d_w_ready; // Write address upstream ready
    assign u_w_data_ready = w_t0d_m_ready && t1_w_ready && d_w_ready;         // Write data upstream ready
    
    // Merge ready generation for Write pipeline
    assign w_t0a_m_ready = (w_t0d_valid && !w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    assign w_t0d_m_ready = (!w_t0d_valid && w_t0a_valid) || (!w_t0d_valid && !w_t0a_valid) || (w_t0d_valid && w_t0a_valid);
    

    // State transition logic - split into logical groups
    always @(*) begin
        case (t1_current_state)
            STATE_IDLE: begin
                // IDLE state transitions with priority order
                if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                    // Write priority: d_w_ready && (w_t0a_valid && w_t0d_valid)
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else if (d_r_ready && r_t0_valid) begin
                    // Read execution: d_r_ready && r_t0_valid
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else begin
                    // No execution - stay in idle
                    t1_next_state = t1_current_state;
                end
            end

            STATE_R_NLAST, STATE_R_LAST: begin
                // READ states transitions - d_r_ready controls state changes
                if (d_r_ready) begin
                    // d_r_ready is HIGH - evaluate state transitions
                    if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                        // Write request - priority to write
                        t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                    end else if (r_t0_valid) begin
                        // Continue reading: r_t0_valid
                        t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                    end else begin
                        // No valid read request - return to idle
                        t1_next_state = STATE_IDLE;
                    end
                end else begin
                    // d_r_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            STATE_W_NLAST, STATE_W_LAST: begin
                // WRITE states transitions - d_w_ready controls state changes
                if (d_w_ready) begin
                    // d_w_ready is HIGH - evaluate state transitions
                    if (d_r_ready && r_t0_valid) begin
                        // Read request - priority to read
                        t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                    end else if ((w_t0a_valid && w_t0d_valid)) begin
                        // Continue writing: (w_t0a_valid && w_t0d_valid)
                        t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                    end else begin
                        // No valid write request - return to idle
                        t1_next_state = STATE_IDLE;
                    end
                end else begin
                    // d_w_ready is LOW - hold current state
                    t1_next_state = t1_current_state;
                end
            end

            default: t1_next_state = 3'bx;
        endcase
    end    

    // Current state management logic (T1 stage)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t1_current_state <= STATE_IDLE; // Initialize to Idle
        end else begin
            t1_current_state <= t1_next_state;
        end
    end
    
    // Read T0 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t0_count <= 8'hFF;                        // Initialize to idle state
            r_t0_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            r_t0_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_r_ready && t1_r_ready) begin
            case (r_t0_state_ready)
                1'b1: begin // Ready state (Idle or last cycle)
                    r_t0_count <= u_r_valid ? u_r_length : 8'hFF;  // Load burst length or stay idle
                    r_t0_mem_addr <= u_r_addr;                     // Load start address
                    r_t0_valid <= u_r_valid;                       // Set valid based on upstream
                end
                1'b0: begin // Not ready state (Bursting)
                    r_t0_count <= r_t0_count - 8'h01;             // Decrement burst counter
                    r_t0_mem_addr <= r_t0_mem_addr + 1;            // Increment memory address
                    r_t0_valid <= 1'b1;                            // Keep valid during burst
                end
            endcase
        end
    end
    
    // Read T1 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            r_t1_valid <= 1'b0;                            // Initialize valid to 0
            r_t1_last <= 1'b0;                             // Initialize last to 0
        end else if (d_r_ready && t1_r_ready) begin
            // Forward T0 signals to T1 stage
            r_t1_addr <= r_t0_mem_addr;                            // Forward T0 address
            r_t1_valid <= r_t0_valid;                              // Forward T0 valid signal
            r_t1_last <= r_t0_last;                                // Forward T0 last signal
        end
    end
    
    // Read T2 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_t2_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            r_t2_valid <= 1'b0;                            // Initialize valid to 0
            r_t2_last <= 1'b0;                             // Initialize last to 0
        end else if (d_r_ready) begin
            if (t1_current_state==STATE_R_NLAST || t1_current_state==STATE_R_LAST) begin
                // Memory access with enable control
                r_t2_data <= (r_t1_valid) ? r_t1_addr : r_t2_data;     // Update data when valid, hold when not
                r_t2_valid <= r_t1_valid;                              // Forward T1 valid signal
                r_t2_last <= r_t1_last;                                // Forward T1 last signal
            end else begin
                r_t2_data <= r_t2_data;
                r_t2_valid <= 1'b0;
                r_t2_last <= 1'b0;
            end
        end
    end
    
    // Write T0A stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t0a_count <= 8'hFF;                        // Initialize to idle state
            w_t0a_mem_addr <= {ADDR_WIDTH{1'b0}};        // Initialize address to 0
            w_t0a_valid <= 1'b0;                         // Initialize valid to 0
        end else if (d_w_ready && t1_w_ready) begin
            if (w_t0a_m_ready) begin
                case (w_t0a_state_ready)
                    1'b1: begin // Ready state (Idle or last cycle)
                        w_t0a_count <= u_w_length;          // Load burst length
                        w_t0a_mem_addr <= u_w_addr;         // Load start address
                        w_t0a_valid <= u_w_addr_valid;      // Set valid based on upstream
                    end
                    1'b0: begin // Not ready state (Bursting)
                        w_t0a_count <= w_t0a_count - 8'h01; // Decrement burst counter
                        w_t0a_mem_addr <= w_t0a_mem_addr + 1; // Increment memory address
                        w_t0a_valid <= 1'b1;              // Keep valid during burst
                    end
                endcase
            end
        end
    end
    
    // Write T0D stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t0d_data <= {DATA_WIDTH{1'b0}};             // Initialize data to 0
            w_t0d_valid <= 1'b0;                          // Initialize valid to 0
        end else if (d_w_ready && t1_w_ready) begin
            if (w_t0d_m_ready) begin
                w_t0d_data <= u_w_data;                     // Update data from upstream
                w_t0d_valid <= u_w_data_valid;              // Set valid based on upstream
            end
        end
    end
    
    // Write T1 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t1_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            w_t1_data <= {DATA_WIDTH{1'b0}};              // Initialize data to 0
            w_t1_valid <= 1'b0;                           // Initialize valid to 0
            w_t1_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready && t1_w_ready) begin
            w_t1_addr <= w_t0a_mem_addr;                    // Forward T0A address
            w_t1_data <= w_t0d_data;                        // Forward T0D data
            w_t1_valid <= (w_t0a_valid && w_t0d_valid);     // Valid when both T0A and T0D are valid
            w_t1_last <= w_t0a_last;                        // Forward T0A last signal
        end
    end
    
    // Write T2 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t2_addr <= {ADDR_WIDTH{1'b0}};              // Initialize address to 0
            w_t2_data <= {DATA_WIDTH{1'b0}};               // Initialize data to 0
            w_t2_valid <= 1'b0;                           // Initialize valid to 0
            w_t2_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready) begin
            if (t1_current_state==STATE_W_NLAST || t1_current_state==STATE_W_LAST) begin
                w_t2_addr <= w_t1_addr;                         // Forward T1 address
                w_t2_data <= w_t1_data;                         // Forward T1 data
                w_t2_valid <= w_t1_valid;                       // Forward T1 valid signal
                w_t2_last <= w_t1_last;                         // Forward T1 last signal
            end else begin
                w_t2_addr <= w_t2_addr;
                w_t2_data <= w_t2_data;
                w_t2_valid <= 1'b0;
                w_t2_last <= 1'b0;
            end
        end
    end
    
    // Write T3 stage control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_t3_response <= {ADDR_WIDTH{1'b0}};           // Initialize response to 0
            w_t3_valid <= 1'b0;                           // Initialize valid to 0
            w_t3_last <= 1'b0;                            // Initialize last to 0
        end else if (d_w_ready) begin
            w_t3_valid <= w_t2_valid;                       // Forward T2 valid signal
            w_t3_last <= w_t2_last;                         // Forward T2 last signal
            w_t3_response <= ((w_t2_addr == w_t2_data) && w_t2_we) ? w_t2_addr : {ADDR_WIDTH{1'bx}}; // Generate response based on condition
        end
    end

endmodule
```

</div>

### 5.2 リードライトパイプラインテストベンチ

<div style="max-height: 500px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; background-color: #f6f8fa;">

```verilog
// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
`timescale 1ns / 1ps

module burst_rw_pipeline_tb #(
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
    
    // Test pattern generator signals - Read interface
    reg  [ADDR_WIDTH-1:0]  test_r_addr;
    reg  [7:0]             test_r_length;
    reg                     test_r_valid;
    wire                    test_r_ready;
    
    // Test pattern generator signals - Write interface
    reg  [ADDR_WIDTH-1:0]  test_w_addr;
    reg  [7:0]             test_w_length;
    reg                     test_w_addr_valid;
    wire                    test_w_addr_ready;
    reg  [DATA_WIDTH-1:0]  test_w_data;
    reg                     test_w_data_valid;
    wire                    test_w_data_ready;
    
    // Test pattern arrays - Read interface
    reg  [ADDR_WIDTH-1:0]  test_r_addr_array [$];
    reg  [7:0]             test_r_length_array [$];
    reg                     test_r_valid_array [$];
    reg  [DATA_WIDTH-1:0]  expected_r_data_array [$];
    
    // Test pattern arrays - Write interface
    reg  [ADDR_WIDTH-1:0]  test_w_addr_array [$];
    reg  [7:0]             test_w_length_array [$];
    reg                     test_w_addr_valid_array [$];
    reg  [DATA_WIDTH-1:0]  test_w_data_array [$];
    reg                     test_w_data_valid_array [$];
    
    // Expected response arrays
    reg  [ADDR_WIDTH-1:0]  expected_w_response_array [$];
    reg                     expected_w_valid_array [$];
    
    // Stall control arrays
    reg  [2:0]             r_stall_cycles_array [$];
    reg  [2:0]             w_stall_cycles_array [$];
    
    // Array control variables
    integer                 r_array_index;
    integer                 w_addr_array_index;
    integer                 w_data_array_index;
    integer                 array_size;
    integer                 expected_r_data_index;
    integer                 expected_w_response_index;
    integer                 r_stall_index;
    integer                 w_stall_index;
    
    // DUT interface signals
    wire [DATA_WIDTH-1:0]  dut_r_data;
    wire                    dut_r_valid;
    wire                    dut_r_last;
    wire                    dut_r_ready;
    wire [ADDR_WIDTH-1:0]  dut_w_response;
    wire                    dut_w_valid;
    wire                    dut_w_ready;
    
    // Test control signals
    reg                     final_r_ready;
    reg                     final_w_ready;
    integer                 test_count;
    integer                 r_burst_count;
    integer                 w_burst_count;
    integer                 r_data_count;
    integer                 w_response_count;
    integer                 valid_r_address_count;
    integer                 valid_w_address_count;
    integer                 valid_w_data_count;
    integer                 bubble_count;
    
    // Burst tracking for reporting
    reg [ADDR_WIDTH-1:0]   current_r_burst_addr;
    reg [7:0]              current_r_burst_length;
    reg [ADDR_WIDTH-1:0]   current_w_burst_addr;
    reg [7:0]              current_w_burst_length;
    integer                 r_burst_data_count;
    integer                 w_burst_response_count;
    
    // Burst verification queues
    reg [ADDR_WIDTH-1:0]   r_burst_addr_queue [$];
    reg [7:0]              r_burst_length_queue [$];
    reg [ADDR_WIDTH-1:0]   w_burst_addr_queue [$];
    reg [7:0]              w_burst_length_queue [$];
    integer                 r_burst_queue_index;
    integer                 w_burst_queue_index;
    
    // DUT instance
    burst_rw_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MAX_BURST_LENGTH(MAX_BURST_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        // Read interface
        .u_r_addr(test_r_addr),
        .u_r_length(test_r_length),
        .u_r_valid(test_r_valid),
        .u_r_ready(test_r_ready),
        .d_r_data(dut_r_data),
        .d_r_valid(dut_r_valid),
        .d_r_last(dut_r_last),
        .d_r_ready(dut_r_ready),
        // Write interface
        .u_w_addr(test_w_addr),
        .u_w_length(test_w_length),
        .u_w_addr_valid(test_w_addr_valid),
        .u_w_addr_ready(test_w_addr_ready),
        .u_w_data(test_w_data),
        .u_w_data_valid(test_w_data_valid),
        .u_w_data_ready(test_w_data_ready),
        .d_w_response(dut_w_response),
        .d_w_valid(dut_w_valid),
        .d_w_ready(dut_w_ready)
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
        integer bubble_cycles;
        integer data_value;
        

        
        // Initialize test pattern arrays
        array_size = 0;
        expected_r_data_index = 0;
        expected_w_response_index = 0;
        valid_r_address_count = 0;
        valid_w_address_count = 0;
        valid_w_data_count = 0;
        bubble_count = 0;
        r_burst_data_count = 0;
        w_burst_response_count = 0;
        
        // Initialize test signals to avoid X values
        test_r_addr = 0;
        test_r_length = 0;
        test_r_valid = 0;
        test_w_addr = 0;
        test_w_length = 0;
        test_w_addr_valid = 0;
        test_w_data = 0;
        test_w_data_valid = 0;
        
        // Initialize array indices
        r_array_index = 0;
        w_addr_array_index = 0;
        w_data_array_index = 0;
        
        // Initialize other control signals
        final_r_ready = 0;
        final_w_ready = 0;
        test_count = 0;
        r_burst_count = 0;
        w_burst_count = 0;
        r_data_count = 0;
        w_response_count = 0;
        valid_r_address_count = 0;
        valid_w_address_count = 0;
        valid_w_data_count = 0;
        bubble_count = 0;
        current_r_burst_addr = 0;
        current_r_burst_length = 0;
        current_w_burst_addr = 0;
        current_w_burst_length = 0;
        r_burst_queue_index = 0;
        w_burst_queue_index = 0;
        
        // Generate test patterns
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Random burst length (1 to MAX_BURST_LENGTH)
            burst_length = $urandom_range(1, MAX_BURST_LENGTH);
            
            // Random bubble cycles
            bubble_cycles = $urandom_range(0, BUBBLE_N);
            
            // Random stall cycles
            r_stall_cycles_array.push_back($urandom_range(0, STALL_N));
            w_stall_cycles_array.push_back($urandom_range(0, STALL_N));
            
            // Read test pattern
            test_r_addr_array.push_back($urandom_range(0, 2**ADDR_WIDTH-1));
            test_r_length_array.push_back(burst_length - 1);
            test_r_valid_array.push_back(1);
            
            // Write test pattern
            test_w_addr_array.push_back($urandom_range(0, 2**ADDR_WIDTH-1));
            test_w_length_array.push_back(burst_length - 1);
            test_w_addr_valid_array.push_back(1);
            
            // Generate expected data and responses
            for (j = 0; j < burst_length; j = j + 1) begin
                data_value = $urandom_range(0, 2**DATA_WIDTH-1);
                test_w_data_array.push_back(data_value);
                test_w_data_valid_array.push_back(1);
                
                // Expected read data (address value)
                expected_r_data_array.push_back(test_r_addr_array[i] + j);
                
                // Expected write response (address when addr == data)
                if (test_w_addr_array[i] + j == data_value) begin
                    expected_w_response_array.push_back(test_w_addr_array[i] + j);
                    expected_w_valid_array.push_back(1);
                end else begin
                    expected_w_response_array.push_back(32'hx);
                    expected_w_valid_array.push_back(0);
                end
            end
            
            // Add bubble cycles
            for (j = 0; j < bubble_cycles; j = j + 1) begin
                test_r_valid_array.push_back(0);
                test_w_addr_valid_array.push_back(0);
                test_w_data_valid_array.push_back(0);
            end
            
            array_size = array_size + burst_length + bubble_cycles;
        end
        
        // Wait for reset to complete
        wait (rst_n);
        
        // Start test execution
        fork
            read_test_sequence();
            write_test_sequence();
            read_response_monitor();
            write_response_monitor();
        join
        
        // Test completion
        #1000;
        $display("Test completed. Total tests: %0d", TEST_COUNT);
        $display("Read bursts: %0d, Write bursts: %0d", r_burst_count, w_burst_count);
        $display("Read data: %0d, Write responses: %0d", r_data_count, w_response_count);
        $finish;
    end
    
    // Read test sequence
    task read_test_sequence();
        integer i;
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Wait for ready
            wait (test_r_ready);
            
            // Apply test pattern
            test_r_addr = test_r_addr_array[i];
            test_r_length = test_r_length_array[i];
            test_r_valid = test_r_valid_array[i];
            
            // Track burst
            current_r_burst_addr = test_r_addr;
            current_r_burst_length = test_r_length + 1;
            r_burst_queue.push_back(test_r_addr);
            r_burst_length_queue.push_back(test_r_length + 1);
            
            @(posedge clk);
            
            // Clear valid
            test_r_valid = 0;
            
            // Wait for burst completion
            repeat (current_r_burst_length) @(posedge clk);
            
            r_burst_count = r_burst_count + 1;
        end
    endtask
    
    // Write test sequence
    task write_test_sequence();
        integer i;
        for (i = 0; i < TEST_COUNT; i = i + 1) begin
            // Wait for ready
            wait (test_w_addr_ready && test_w_data_ready);
            
            // Apply test pattern
            test_w_addr = test_w_addr_array[i];
            test_w_length = test_w_length_array[i];
            test_w_addr_valid = test_w_addr_valid_array[i];
            test_w_data = test_w_data_array[i];
            test_w_data_valid = test_w_data_valid_array[i];
            
            // Track burst
            current_w_burst_addr = test_w_addr;
            current_w_burst_length = test_w_length + 1;
            w_burst_addr_queue.push_back(test_w_addr);
            w_burst_length_queue.push_back(test_w_length + 1);
            
            @(posedge clk);
            
            // Clear valid
            test_w_addr_valid = 0;
            test_w_data_valid = 0;
            
            // Wait for burst completion
            repeat (current_w_burst_length) @(posedge clk);
            
            w_burst_count = w_burst_count + 1;
        end
    endtask
    
    // Read response monitor
    task read_response_monitor();
        forever begin
            @(posedge clk);
            if (dut_r_valid && dut_r_ready) begin
                r_data_count = r_data_count + 1;
                
                // Verify data
                if (dut_r_data !== expected_r_data_array[expected_r_data_index]) begin
                    $display("ERROR: Read data mismatch at index %0d", expected_r_data_index);
                    $display("  Expected: %0h, Got: %0h", expected_r_data_array[expected_r_data_index], dut_r_data);
                end
                
                expected_r_data_index = expected_r_data_index + 1;
                
                if (dut_r_last) begin
                    $display("Read burst completed: addr=%0h, length=%0d, data_count=%0d", 
                             current_r_burst_addr, current_r_burst_length, r_burst_data_count);
                    r_burst_data_count = 0;
                end else begin
                    r_burst_data_count = r_burst_data_count + 1;
                end
            end
        end
    endtask
    
    // Write response monitor
    task write_response_monitor();
        forever begin
            @(posedge clk);
            if (dut_w_valid && dut_w_ready) begin
                w_response_count = w_response_count + 1;
                
                // Verify response
                if (dut_w_response !== expected_w_response_array[expected_w_response_index]) begin
                    $display("ERROR: Write response mismatch at index %0d", expected_w_response_index);
                    $display("  Expected: %0h, Got: %0h", expected_w_response_array[expected_w_response_index], dut_w_response);
                end
                
                expected_w_response_index = expected_w_response_index + 1;
                
                if (dut_w_last) begin
                    $display("Write burst completed: addr=%0h, length=%0d, response_count=%0d", 
                             current_w_burst_addr, current_w_burst_length, w_burst_response_count);
                    w_burst_response_count = 0;
                end else begin
                    w_burst_response_count = w_burst_response_count + 1;
                end
            end
        end
    endtask
    
    // Stall control for downstream
    assign dut_r_ready = final_r_ready;
    assign dut_w_ready = final_w_ready;
    
    // Stall generation
    always @(posedge clk) begin
        if (r_stall_index < r_stall_cycles_array.size()) begin
            if (r_stall_cycles_array[r_stall_index] > 0) begin
                final_r_ready = 0;
                r_stall_cycles_array[r_stall_index] = r_stall_cycles_array[r_stall_index] - 1;
            end else begin
                final_r_ready = 1;
                r_stall_index = r_stall_index + 1;
            end
        end else begin
            final_r_ready = 1;
        end
        
        if (w_stall_index < w_stall_cycles_array.size()) begin
            if (w_stall_cycles_array[w_stall_index] > 0) begin
                final_w_ready = 0;
                w_stall_cycles_array[w_stall_index] = w_stall_cycles_array[w_stall_index] - 1;
            end else begin
                final_w_ready = 1;
                w_stall_index = w_stall_index + 1;
            end
        end else begin
            final_w_ready = 1;
        end
    end

endmodule
```

</div>

## 6. 条件網羅法と条件刈込法

本章の設計において、3つの段階とテクニックが使用されています。

まず、**本質要素抽象化**により、設計箇所をReadとWriteの順番を制御するT1ステートだけに絞り込み、その他のコードはここまでの設計内容を変更せずにそのまま使用しています。

次に、**条件網羅法**でT1ステートで使用する全ての条件、つまりT1のステート、Ready、Validの全組み合わせ表を作成し、casez文で記述します。

最後に、**条件刈込法**で、作成したcasez文を共通項で論理圧縮します。また、最初に行った本質要素抽象化による記述箇所の絞り込みも、条件刈込法でT1ステージのみの設計として抽出しています。

### 6.1 条件網羅法とは

条件網羅法は、ハードウェア設計において、すべての可能な入力条件の組み合わせを網羅的に記述する手法です。この手法により、設計の完全性と動作の正確性を保証することができます。

以下に、最初に条件網羅法で記述したコードを示します。読解するには分かりにくいですが、条件漏れを調べるには、この表のように網羅された記述が有効です。

#### **条件網羅法の特徴**:
- **完全性**: すべての入力条件の組み合わせをテスト
- **網羅性**: 境界値やエッジケースも含む包括的なテスト
- **品質保証**: 設計のバグや不具合を早期発見

#### **適用場面**:
- ステートマシンの状態遷移テスト
- 組み合わせ回路の真理値表検証
- パイプライン制御の動作確認

```verilog
// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.

    always @(*) begin
        casez ({t1_current_state, d_r_ready, r_t0_valid, d_w_ready, (w_t0a_valid && w_t0d_valid)})
            // Idle state - no execution
            {STATE_IDLE, 1'b0, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state; 
            {STATE_IDLE, 1'b1, 1'b0, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_IDLE, 1'b0, 1'b?, 1'b1, 1'b0}: t1_next_state = t1_current_state;
            {STATE_IDLE, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = t1_current_state;

            // Read execution from idle (d_r_ready && r_t0_valid)
            {STATE_IDLE, 1'b1, 1'b1, 1'b0, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b0, 1'b1}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            //{STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b1}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                
            // Write execution from idle (d_w_ready && w_t0a_valid && w_t0d_valid)
            {STATE_IDLE, 1'b0, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b0, 1'b1, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b1, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            // State transitions during execution
            {STATE_R_NLAST, 1'b0, 1'b?, 1'b?, 1'b?}: t1_next_state = t1_current_state;
            {STATE_R_NLAST, 1'b1, 1'b?, 1'b?, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            
            {STATE_W_NLAST, 1'b?, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_W_NLAST, 1'b?, 1'b?, 1'b1, 1'b?}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            // Return to idle after completion
            {STATE_R_LAST, 1'b0, 1'b?, 1'b?, 1'b?}: t1_next_state = t1_current_state;
            {STATE_R_LAST, 1'b1, 1'b0, 1'b0, 1'b?}: t1_next_state = STATE_IDLE;
            {STATE_R_LAST, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_R_LAST, 1'b1, 1'b1, 1'b0, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_R_LAST, 1'b1, 1'b1, 1'b1, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_R_LAST, 1'b1, 1'b?, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            {STATE_W_LAST, 1'b?, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_W_LAST, 1'b0, 1'b?, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_W_LAST, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_W_LAST, 1'b0, 1'b?, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_W_LAST, 1'b1, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_W_LAST, 1'b1, 1'b1, 1'b1, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;

            default: t1_next_state = 3'bx;
        endcase
    end    

```
### 6.2 条件刈込法とは

条件刈込法は、条件網羅法からさらに分かりやすいコードにするために、共通条件を選び出し、論理圧縮を行います。また、実際の動作に影響しない条件を除外することで、さらにシンプルなコードになります。

この条件刈込法により、アイドル・リード・ライトの3状態があり、それぞれ異なるReady信号で制御されていることが明確に浮き上がってきます。

#### **条件刈込法の特徴**:
- **効率性**: 不要なテストケースを除外
- **実用性**: 実際の動作に影響する条件のみに焦点
- **保守性**: テストケースの管理が容易

#### **適用場面**:
- パイプラインの優先度制御テスト
- バースト転送の制御信号テスト
- リード・ライト統合制御の動作確認

```verilog
// Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.

// 全状態での全条件の組み合わせ
always @(*) begin
    case (t1_current_state)
        STATE_IDLE: begin
            // 4つの制御信号の全組み合わせ
            if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            end else if (d_r_ready && r_t0_valid) begin
                t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        STATE_R_NLAST, STATE_R_LAST: begin
            // リード状態での全条件
            if (d_r_ready) begin
                if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else if (r_t0_valid) begin
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else begin
                    t1_next_state = STATE_IDLE;
                end
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        STATE_W_NLAST, STATE_W_LAST: begin
            // ライト状態での全条件
            if (d_w_ready) begin
                if (d_r_ready && r_t0_valid) begin
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else if ((w_t0a_valid && w_t0d_valid)) begin
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else begin
                    t1_next_state = STATE_IDLE;
                end
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        default: t1_next_state = 3'bx;
    endcase
end
```

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
