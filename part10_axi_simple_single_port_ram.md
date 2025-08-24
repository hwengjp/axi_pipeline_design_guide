# AXIバス設計ガイド 第10回 AXI4仕様のシンプルシングルポートRAM

## 目次

- [1. はじめに](#1-はじめに)
- [2. 仕様](#2-仕様)
  - [2.1 パイプライン構成](#21-パイプライン構成)
  - [2.2 ポート定義](#22-ポート定義)
  - [2.3 バースト制御](#23-バースト制御)
  - [2.4 ID](#24-id)
  - [2.5 シングルポートRAM](#25-シングルポートram)
- [3. コード](#3-コード)
  - [3.1 DUTのコード](#31-dutのコード)
  - [3.2 テストベンチのコード](#32-テストベンチのコード)
- [4. まとめ](#4-まとめ)
- [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、AXI4仕様に準拠したシンプルシングルポートRAMの実装について説明します。第6回で学んだリードライトの優先制御の基本概念を応用し、AXI4仕様の「シンプルシングルポートRAM」の実装を扱います。

シンプルシングルポートRAMは、1つのクロックポートと1つのアクセスポートを持つメモリデバイスです。リードとライトは時分割で実行され、同時アクセスは制御が必要です。

**シンプルシングルポートRAMの特徴**:
- **単一アクセスポート**: リードポートとライトポートが共有
- **時分割アクセス**: リード・ライトが順次実行される
- **アドレス競合制御**: 同一アドレスへの同時アクセス制御が必要
- **AXI4準拠**: AXI4プロトコルの要件を満たすインターフェース
- **パイプライン対応**: バースト転送とパイプライン処理に対応
- **統合ステート管理**: 第6回の5状態FSMによる優先度制御と調停

AXI4インターフェースの特徴を整理します：

- **リードチャネル**: 読み出しアドレスとバースト情報を伝達
- **ライトチャネル**: 書き込みアドレス、データ、バースト情報を伝達
- **レスポンスチャネル**: 書き込み完了の応答を伝達
- **バースト転送**: 連続したアドレスへの効率的なアクセス
- **パイプライン処理**: 複数のトランザクションの並列処理

シンプルシングルポートRAMでは、リード・ライトの同時実行ができないため、第6回で実装した統合ステート管理による優先度制御と調停が必要になります。これにより、リードとライトの処理順序が制御され、データの整合性が保たれます。

**シンプルシングルポートRAMの利点**:
- **効率的なリソース利用**: 単一のメモリでリード・ライト両方を処理
- **統合制御**: 第6回の5状態FSMによる明確な優先度制御
- **AXI4準拠**: 標準プロトコルによる互換性の確保
- **パイプライン対応**: バースト転送とパイプライン処理の最適化
- **競合制御**: 同一アドレスアクセス時の適切な制御
- **拡張性**: 様々なメモリサイズとデータ幅への対応

## 2. 仕様

### 2.1 パイプライン構成

シンプルシングルポートRAMのパイプライン構成は、第6回の統合ステート管理によるリードライトパイプラインと全く同じです。ReadとWriteのパイプラインがT1ステージで合流し、統合されたステート管理により優先度制御と調停を行います。

#### リード側パイプライン構成

リード側は3段構成のパイプラインで、ペイロード増幅を行う構成です：

```
axi_ar_Payload -> [T0] -> [T1] -> [T2] -> axi_r_Payload
                   ^       ^       ^
                   |       |       |
axi_ar_Ready   <-[AND]<----+-------+-- <- axi_r_Ready
                   ^
                   |
               [T0_State_Ready]
```

**リード側パイプラインの詳細**:

| 段階 | 機能 | 説明 | ペイロード増幅 | レイテンシ |
|------|------|------|------------|------------|
| T0 | アドレスカウンタとバースト制御 | バースト転送の制御とアドレス生成 | **1→N個に増加** | 1クロック |
| T1 | ステートマシン制御 | ReadとWriteの優先度制御 | **増幅なし**（N個維持） | 1クロック |
| T2 | メモリアクセス | メモリからのデータ読み出し | **増幅なし**（N個維持） | 1クロック |

**リード側の特徴**:
- **T0ステージ**: バースト制御とアドレス生成、上流に対するReady制御
- **T1ステージ**: ステートマシン制御（Read/Write優先度制御）
- **T2ステージ**: メモリアクセス（レイテンシ1）
- **総レイテンシ**: 3クロック（T0: 1 + T1: 1 + T2: 1）

#### ライト側パイプライン構成

ライト側は5段構成のパイプラインで、2つのペイロードが合流する構成です。T0DとT0Aは同時並列に動作します：

```
axi_w_Payload_D=> [T0D]=======++
                 ^          ||
                 |          ||
axi_w_Ready   <-[AND]---+   ||
                 ^      |   ||
                 |      |   ||
       [T0D_Ready]      |   ||
                        |   ||
axi_aw_Payload_A=> [T0A] ===> [T1] => [T2] => [T3] => axi_b_Payload
                 ^      |   ^       ^       ^   
                 |      |   |       |       |   
axi_aw_Ready   <-[AND]<--+---+-------+-------+--- <- axi_b_Ready
                 ^ ^                     
                 | |        
       [T0A_Ready] |        
              [T0A_M_Ready]
```

**ライト側パイプラインの詳細**:

| 段階 | 機能 | 説明 | ペイロード増幅 | レイテンシ |
|------|------|------|------------|------------|
| T0A/T0D | アドレス・データ並列処理 | アドレスとデータの同時並列処理 | **1→N個に増加** | 1クロック |
| T1 | ステートマシン制御 | ReadとWriteの優先度制御 | **増幅なし**（N個維持） | 1クロック |
| T2 | メモリアクセス | メモリへの書き込み | **増幅なし**（N個維持） | 1クロック |
| T3 | レスポンス生成 | 書き込み完了の応答生成 | **増幅なし**（N個維持） | 1クロック |

**ライト側の特徴**:
- **T0A/T0Dステージ**: アドレスとデータの同時並列処理
- **T1ステージ**: ステートマシン制御（Read/Write優先度制御）
- **T2ステージ**: メモリアクセス（レイテンシ1）
- **T3ステージ**: レスポンス生成（追加レイテンシ1）
- **総レイテンシ**: 5クロック（T0A/T0D: 1 + T1: 1 + T2: 1 + T3: 1）

#### 統合制御の特徴

**T1ステージ統合**:
- Read・Write両方のパイプラインがT1ステージで合流
- 5つのステート（`STATE_IDLE`, `STATE_R_NLAST`, `STATE_R_LAST`, `STATE_W_NLAST`, `STATE_W_LAST`）による統合制御
- 書き込み優先の優先度制御（アイドル・リード状態では書き込み優先、ライト状態ではリード優先）

**Ready制御**:
- 各ステージの動作は`axi_r_ready`/`axi_b_ready`がHの時のみ実行
- パイプライン全体がReady信号で統一的に制御
- 上流へのReady信号は非同期ANDで生成

**メモリアクセス制御**:
- シングルポートRAMの制約により、Read・Writeは排他的に実行
- T1ステートに基づくメモリアクセスのイネーブル制御
- メモリアクセス競合検出機能（シミュレーション専用）

### 2.2 ポート定義

シンプルシングルポートRAMのポート定義は以下の通りです：

```systemverilog
module axi_simple_single_port_ram #(
    parameter MEMORY_SIZE_BYTES = 33554432,  // 32MB
    parameter AXI_DATA_WIDTH = 32,           // 32bit
    parameter AXI_ID_WIDTH = 8,              // 8bit ID
    parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES)
) (
    input  logic                        aclk,           // Clock
    input  logic                        aresetn,        // Reset (active low)
    
    // Read Address Channel
    input  logic [AXI_ID_WIDTH-1:0]    s_axi_arid,     // Read address ID
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,   // Read address
    input  logic [7:0]                 s_axi_arlen,    // Burst length
    input  logic [2:0]                 s_axi_arsize,   // Burst size
    input  logic [1:0]                 s_axi_arburst,  // Burst type
    input  logic                       s_axi_arvalid,  // Read address valid
    output logic                       s_axi_arready,  // Read address ready
    
    // Read Data Channel
    output logic [AXI_ID_WIDTH-1:0]    s_axi_rid,      // Read ID
    output logic [AXI_DATA_WIDTH-1:0]  s_axi_rdata,    // Read data
    output logic [1:0]                 s_axi_rresp,    // Read response
    output logic                       s_axi_rlast,    // Read last
    output logic                       s_axi_rvalid,   // Read valid
    input  logic                       s_axi_rready,   // Read ready
    
    // Write Address Channel
    input  logic [AXI_ID_WIDTH-1:0]    s_axi_awid,     // Write address ID
    input  logic [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,   // Write address
    input  logic [7:0]                 s_axi_awlen,    // Burst length
    input  logic [2:0]                 s_axi_awsize,   // Burst size
    input  logic [1:0]                 s_axi_awburst,  // Burst type
    input  logic                       s_axi_awvalid,  // Write address valid
    output logic                       s_axi_awready,   // Write address ready
    
    // Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0]  s_axi_wdata,    // Write data
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,   // Write strobe
    input  logic                       s_axi_wlast,    // Write last
    input  logic                       s_axi_wvalid,   // Write valid
    output logic                       s_axi_wready,   // Write ready
    
    // Write Response Channel
    output logic [AXI_ID_WIDTH-1:0]    s_axi_bid,      // Write response ID
    output logic [1:0]                 s_axi_bresp,    // Write response
    output logic                       s_axi_bvalid,   // Write response valid
    input  logic                       s_axi_bready    // Write response ready
);
```

### 2.3 バースト制御

AXI4仕様で定義された3種類のバーストタイプをサポートします：

- **FIXED (2'b00)**: 固定アドレスバースト。同一アドレスへの連続アクセスで、データの更新やFIFO操作に使用
  - **アドレス固定**: バースト中は開始アドレスが固定され、アドレスは変化しない
  - **最大バースト長**: 256ビート（`axi_ar_len`/`axi_aw_len` = 8'hFF）
  - **用途**: 同一レジスタへの連続書き込み、FIFOの読み出し、カウンタの更新
- **INCR (2'b01)**: インクリメントバースト。アドレスが連続的に増加する最も一般的なバースト転送
  - **最大バースト長**: 256ビート（`axi_ar_len`/`axi_aw_len` = 8'hFF）
  - **アドレス増分**: データサイズ（`axi_aw_size`/`axi_ar_size`）に基づいて自動計算
- **WRAP (2'b10)**: ラップバースト。指定された境界でアドレスがラップする循環的なバースト転送
  - **ラップ境界**: バースト長 × データサイズで計算される境界
  - **境界計算**: `boundary = start_addr + (burst_length + 1) × data_size`
  - **ラップ動作**: 境界に達すると、アドレスが開始アドレス付近に戻る

**バースト制御の実装**:
- **T0ステージ**: `r_t0_count`/`w_t0a_count`によるバーストカウンタ制御
- **アイドルフラグ**: `r_t0_idle`/`w_t0a_idle`によるバースト状態管理
- **アドレス更新**: バーストタイプに応じたアドレス計算（`r_t0_addr`/`w_t0a_addr`）

### 2.4 ID

AXI4のID信号は、複数のトランザクションを識別するために使用されます。IDはペイロードと一緒にパイプラインを流れ、各チャネル間でトランザクションの対応関係を維持します：

**リードチャネル**:
- **`axi_ar_id`**: リードアドレスチャネルのトランザクションID
- **`r_t0_id`**: T0ステージでのID保持
- **`r_t1_id`**: T1ステージでのID転送
- **`r_t2_id`**: T2ステージでのID出力（`axi_r_id`）

**ライトチャネル**:
- **`axi_aw_id`**: ライトアドレスチャネルのトランザクションID
- **`w_t0a_id`**: T0AステージでのID保持
- **`w_t1_id`**: T1ステージでのID転送
- **`w_t2_id`**: T2ステージでのID保持
- **`w_t3_id`**: T3ステージでのID転送（`axi_b_id`）

**ID転送の制御**:
- **T1ステージ**: ステートマシンの状態に基づくID転送制御
- **T2/T3ステージ**: メモリアクセス完了後のID出力制御

### 2.5 シングルポートRAM

FPGAの論理合成ツールで推定可能なシンプルシングルポートRAMのサンプル記述を示します。この記述により、論理合成ツールが適切なメモリブロック（ブロックRAM、エンベデッドRAM等）を自動的に推定・配置します。

**メモリアクセス制御**:
- **read_enable (re)**: リード有効信号。レディネゲート時に現在の状態をホールドするための信号として使用される
- **write_enable (we)**: ライト有効信号。レディネゲート時に現在の状態をホールドするための信号として使用される
- **排他アクセス**: reとweは同時にアサートされず、シングルポートRAMの制約により排他的に制御される

**レイテンシ**:
- **レイテンシ = 1**: メモリアクセス後1クロックでデータ出力（メモリのみ、追加レジスタなし）

**Verilog記述例**:

**シングルポートRAMのコード**: [single_port_ram.v](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/single_port_ram.v)

## 3. コード

### 3.1 DUTのコード

シンプルシングルポートRAMのDUTのコードを示します。

以下はAIに対する実装の指示です。

```
以下の方針で実装してください。
burst_rw_pipeline.vをAXI4対応にする。ステートの制御は変更なくそのまま流用する。
T2ステージでシングルポートメモリをアクセスするように修正する。
T0ステージのバースト制御は、axi_simple_dual_port_ram.vのT1ステージを流用する。
```
**DUTのコード**: [axi_simple_single_port_ram.v](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_simple_single_port_ram.v)

### 3.2 テストベンチのコード

テストベンチは第９回で実装したコードを流用します。

- **テストベンチのコード**: [axi_simple_single_port_ram_tb.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_simple_single_port_ram_tb.sv)

## 4. まとめ

本記事では、AXI4仕様に準拠したシンプルシングルポートRAMの実装について説明しました。

**主要な特徴**:
- **統合パイプライン**: 第6回の5状態FSMによる優先度制御と調停
- **シングルポート制約**: Read・Writeの排他制御によるメモリアクセス管理
- **AXI4準拠**: 標準プロトコルの要件を満たすインターフェース
- **パイプライン最適化**: 3段Read、5段Writeの効率的な構成

**実装のポイント**:
- **ステート管理**: T1ステージでの統合されたステート制御
- **競合制御**: メモリアクセスの排他制御と競合検出
- **バースト対応**: 3種類のバーストタイプ（FIXED、INCR、WRAP）のサポート
- **ID管理**: トランザクション識別のためのID転送制御

シンプルシングルポートRAMは、リソース効率性とAXI4準拠性を両立させた実用的なメモリデバイスとして、様々なシステムに適用できます。

## ライセンス

このドキュメントは[Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)の下で公開されています。
