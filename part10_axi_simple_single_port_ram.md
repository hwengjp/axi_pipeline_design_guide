# AXIバスのパイプライン回路設計ガイド ～ 第10回 AXI4仕様のシンプルシングルポートRAM

## 目次

- [1. はじめに](#1-はじめに)
- [2. 仕様](#2-仕様)
  - [2.1 パイプライン構成](#21-パイプライン構成)
  - [2.2 ポート定義](#22-ポート定義)
  - [2.3 バースト制御](#23-バースト制御)
  - [2.4 ID](#24-id)
  - [2.5 シングルポートRAM](#25-シングルポートram)
- [3. サンプルコード](#3-サンプルコード)
  - [3.1 DUTのサンプルコード](#31-dutのサンプルコード)
  - [3.2 テストベンチのサンプルコード](#32-テストベンチのサンプルコード)
- [4. 何度やってもバグが取れない場合の「御破算やりなおし法」](#4-何度やってもバグが取れない場合の御破算やりなおし法)
- [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、AXI4仕様に準拠したシンプルシングルポートRAMの実装について説明します。第6回で学んだリードライトの優先制御の基本概念を応用し、AXI4仕様の「シンプルシングルポートRAM」の実装を扱います。

シンプルシングルポートRAMは、1つのクロックポートと1つのアクセスポートを持つメモリデバイスです。リードとライトは時分割で実行され、同一アドレスへの同時アクセスは制御が必要です。

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

シンプルシングルポートRAMのパイプライン構成は、リード側とライト側が競合制御によって制御されます。

#### リード側パイプライン構成

リード側は2段構成のパイプラインで、データ増幅を行う構成です：

```
u_r_Payload -> [T0] -> [T1] -> d_r_Payload
                ^       ^
                |       |
u_r_Ready   <-[AND]<---+-- <- d_r_Ready
                ^
                |
            [T0_State_Ready]
```

#### ライト側パイプライン構成

ライト側は4段構成のパイプラインで、2つのペイロードが合流する構成です。

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

## 3. サンプルコード

### 3.1 DUTのサンプルコード

シンプルシングルポートRAMのDUTのサンプルコードを示します。

### 3.2 テストベンチのサンプルコード

シンプルシングルポートRAMのテストベンチのサンプルコードを示します。

## 4. 何度やってもバグが取れない場合の「御破算やりなおし法」

シンプルシングルポートRAMの実装では、競合制御の複雑さから以下の点に注意が必要です：

- **競合検出の動作確認**: リード・ライトの競合時の動作
- **優先度制御の検証**: 優先度決定ロジックの動作
- **タイミング制御の確認**: 各ステージのタイミング制御


burst_rw_pipeline.vのT1ステージを、axi_simple_dual_port_ram.vに組み込みます。
組み込み前に、burst_rw_pipeline.vのもとになったコード、burst_read_pipeline.vとburst_write_pipeline.vとパイプライン構成の比較を行って、T1ステージをどのように挿入すればいいかを計画してください。


## ライセンス

このドキュメントは[Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)の下で公開されています。
