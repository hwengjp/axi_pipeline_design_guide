# AXIバス設計ガイド 第14回 AXI書き込み幅変換器

## 目次

  - [1. はじめに](#1-はじめに)
  - [2. バス幅変換の分析](#2-バス幅変換の分析)
    - [2.1 バス幅変換組み合わせ表](#21-バス幅変換組み合わせ表)
    - [2.2 バス幅変換の具体例](#22-バス幅変換の具体例)
      - [2.2.1 size=0(1バイト)、4ビートのバースト転送](#221-size01バイト4ビートのバースト転送)
      - [2.2.2 size=2(4バイト)、4ビートのバースト転送](#222-size24バイト4ビートのバースト転送)
    - [2.3 バス幅変換の計算方法](#23-バス幅変換の計算方法)
      - [2.3.1 基本計算式（汎用バス幅変換）](#231-基本計算式汎用バス幅変換)
      - [2.3.2 具体例による計算過程（汎用バス幅変換）](#232-具体例による計算過程汎用バス幅変換)
  - [3. 仕様](#3-仕様)
    - [3.1 パイプライン構成](#31-パイプライン構成)
      - [ライト側パイプライン構成](#ライト側パイプライン構成)
      - [パイプライン制御の特徴](#パイプライン制御の特徴)
  - [ライセンス](#ライセンス)

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

第14回では狭いデータバス幅から広いデータバス幅に変換する書き込み専用コンポーネントの実装について説明します。


## 2. バス幅変換の分析

### 2.1 バス幅変換組み合わせ表

変換の組み合わせは以下の通りです。

| 変換元\変換先 | 8bit | 16bit | 32bit | 64bit | 128bit | 256bit | 512bit | 1024bit |
|---------------|------|-------|-------|-------|--------|--------|--------|---------|
| **8bit**      | -    | ✅    | ✅    | ✅    | ✅     | ✅     | ✅     | ✅      |
| **16bit**     | -    | -     | ✅    | ✅    | ✅     | ✅     | ✅     | ✅      |
| **32bit**     | -    | -     | -     | ✅    | ✅     | ✅     | ✅     | ✅      |
| **64bit**     | -    | -     | -     | -     | ✅     | ✅     | ✅     | ✅      |
| **128bit**    | -    | -     | -     | -     | -      | ✅     | ✅     | ✅      |
| **256bit**    | -    | -     | -     | -     | -      | -      | ✅     | ✅      |
| **512bit**    | -    | -     | -     | -     | -      | -      | -      | ✅      |
| **1024bit**   | -    | -     | -     | -     | -      | -      | -      | -       |

**凡例**:
- ✅: バス幅増加（変換可能）
- -: 同一バス幅またはバス幅減少（変換対象外）

### 2.2 バス幅変換の具体例

#### 2.2.1 size=0(1バイト)、4ビートのバースト転送

**8bit→16bit変換の場合**:

| 項目 | 上流（8bit） | 下流（16bit） | 説明 |
|------|-------------|---------------|------|
| データ幅 | 8bit | 16bit | 2倍に拡張 |
| ストローブ | 1bit | 2bit | 2倍に拡張 |
| バースト長 | 4 | 2 | 1/2に圧縮 |
| アドレス | 0x00 | 0x00 | そのまま |
| データ1 | 0x12 | 0x1212 | 2回分を結合 |
| データ2 | 0x34 | 0x3434 | 2回分を結合 |
| ストローブ1 | 1 | 11 | 2bitに拡張 |
| ストローブ2 | 1 | 11 | 2bitに拡張 |

**変換ルール**:
- 2つの8bitデータを1つの16bitデータに結合
- ストローブも2bitに拡張
- バースト長は1/2に圧縮

#### 2.2.2 size=2(4バイト)、4ビートのバースト転送

**32bit→64bit変換の場合**:

| 項目 | 上流（32bit） | 下流（64bit） | 説明 |
|------|---------------|---------------|------|
| データ幅 | 32bit | 64bit | 2倍に拡張 |
| ストローブ | 4bit | 8bit | 2倍に拡張 |
| バースト長 | 4 | 2 | 1/2に圧縮 |
| アドレス | 0x00 | 0x00 | そのまま |
| データ1 | 0x12345678 | 0x1234567812345678 | 2回分を結合 |
| データ2 | 0x9ABCDEF0 | 0x9ABCDEF09ABCDEF0 | 2回分を結合 |
| ストローブ1 | 1111 | 11111111 | 8bitに拡張 |
| ストローブ2 | 1111 | 11111111 | 8bitに拡張 |

**変換ルール**:
- 2つの32bitデータを1つの64bitデータに結合
- ストローブも8bitに拡張
- バースト長は1/2に圧縮

### 2.3 バス幅変換の計算方法

#### 2.3.1 基本計算式（汎用バス幅変換）

**基本パラメータ**:
- `SOURCE_WIDTH`: 上流側バス幅（ビット）
- `TARGET_WIDTH`: 下流側バス幅（ビット）
- `SOURCE_BYTES = SOURCE_WIDTH / 8`: 上流側バイト数
- `TARGET_BYTES = TARGET_WIDTH / 8`: 下流側バイト数

**変換比率**:
- `RATIO = TARGET_WIDTH / SOURCE_WIDTH`: バス幅拡張比率
- `BURST_RATIO = SOURCE_WIDTH / TARGET_WIDTH`: バースト長圧縮比率

**下流側バースト長**:
- `TARGET_LEN = SOURCE_LEN / RATIO`: 下流側バースト長

**下流側ストローブ**:
- 各バイト位置で上流側ストローブを複製
- `TARGET_STRB[i*RATIO +: RATIO] = SOURCE_STRB[i]`

#### 2.3.2 具体例による計算過程（汎用バス幅変換）

**32bit→128bit変換（RATIO=4）の場合**:

| 上流側 | 下流側 | 計算過程 |
|--------|--------|----------|
| データ幅 | 32bit → 128bit | 32 × 4 = 128 |
| ストローブ | 4bit → 16bit | 4 × 4 = 16 |
| バースト長 | 8 → 2 | 8 ÷ 4 = 2 |
| アドレス | 0x00 → 0x00 | そのまま |
| データ1 | 0x12345678 → 0x12345678123456781234567812345678 | 4回複製 |
| データ2 | 0x9ABCDEF0 → 0x9ABCDEF09ABCDEF09ABCDEF09ABCDEF0 | 4回複製 |
| ストローブ1 | 1111 → 1111111111111111 | 4回複製 |
| ストローブ2 | 1111 → 1111111111111111 | 4回複製 |

## 3. 仕様

### 3.1 パイプライン構成

#### ライト側パイプライン構成

ライト側は3段構成のパイプラインで、2つのペイロードが合流する構成です。T0DとT0Aは同時並列に動作します：

```
s_w_Payload_D=> [T0D]====> [T1D] => 
                 ^          ^      
                 |          |       
s_w_Ready_D   <-[AND]---+---+--- <- m_w_Ready_D
                 ^ ^        
                 | |        
       [T0D_Ready] +----+   
                        |   
s_w_Payload_A=> [T0A] ===> [T1A] => m_w_Payload_A
                 ^      |   ^      
                 |      |   |       
s_w_Ready_A   <-[AND]<------+--- <- m_w_Ready_A
                 ^ ^    |                 
                 | |    |    
       [T0A_Ready] |    |    
              [T0_M_Ready]
```

#### ライトシーケンス
偶数アドレススタートの場合(8bit->16bitのケース)
```
Clock        : 123456789012345678901
Address      : xxxxxx044448888xxxxxx
Data         : xxxxxx0123456789ABxxx
Length       : xxxxxx333333333xxxxxx
Valid        : ______HHHHHHHHHHHH___
Ready        : HHHHHHH___H___H___HHH

T0A_Adr      : xxxxxxx04448888xxxxxx
T0A_Count    : FFFFFFF321032103210FF
T0A_Valid    : _______HHHHHHHHHHHH__
T0A_Last     : __________H___H___H__
T0A_Ready    : HHHHHHH___H___H___HHH

アドレス側はアドレスのReadyで止める制御をする

T0D_Data     : xxxxxxx0123456789ABxxx
T0D_Valid    : _______HHHHHHHHHHHH__
T0D_Ready    : HHHHHHHHHHHHHHHHHHHHH

データ側はデータののReadyで止める制御をする

両方の待ち合わせ回路は？

-----------------------------

**ライト側パイプラインの詳細**:

| 段階 | 機能 | 説明 | ペイロード増幅 | レイテンシ |
|------|------|------|------------|------------|
| T0A/T0D | アドレス・データ並列処理 | アドレスとデータの同時並列処理 | **1→N個に増加** | 1クロック |
| T1 | アドレス・データ合流 | アドレスとデータの合流制御 | **増幅なし**（N個維持） | 1クロック |
| T2 | 変換回路 | データとストローブの変換 | **増幅なし**（N個維持） | 1クロック |

**ライト側の特徴**:
- **T0A/T0Dステージ**: アドレスとデータの同時並列処理
- **T1ステージ**: アドレス・データの合流制御
- **T2ステージ**: 変換回路（レイテンシ1）
- **総レイテンシ**: 3クロック（T0A/T0D: 1 + T1: 1 + T2: 1）

#### パイプライン制御の特徴

**独立動作**:
- ライトのパイプラインが独立して動作
- パイプラインが独自のReady制御で動作

**Ready制御**:
- 上流へのReady信号は非同期ANDで生成

**メモリレイテンシ**:
- **ライト側**: メモリレイテンシ1を採用（書き込みは即座に実行）
- 論理合成ツールでの最適化が容易

### 3.2 ポート定義

#### 3.2.1 モジュール宣言

```systemverilog
module axi_write_n2w_width_converter #(
    // ライト側パラメータ
    parameter int unsigned WRITE_SOURCE_WIDTH = 64,        // ライト上流側バス幅（ビット）
    parameter int unsigned WRITE_TARGET_WIDTH = 128,       // ライト下流側バス幅（ビット）
    
    // リード側パラメータ（変換なし、同じ幅）
    parameter int unsigned READ_SOURCE_WIDTH = 64,         // リード上流側バス幅（ビット）
    parameter int unsigned READ_TARGET_WIDTH = 64,         // リード下流側バス幅（ビット）
    
    parameter int unsigned ADDR_WIDTH = 32,                // アドレスバス幅（ビット）
    
    // 派生パラメータ（自動計算）
    parameter int unsigned WRITE_SOURCE_BYTES = WRITE_SOURCE_WIDTH / 8,        // ライト上流側バイト数
    parameter int unsigned WRITE_TARGET_BYTES = WRITE_TARGET_WIDTH / 8,        // ライト下流側バイト数
    parameter int unsigned READ_SOURCE_BYTES = READ_SOURCE_WIDTH / 8,          // リード上流側バイト数
    parameter int unsigned READ_TARGET_BYTES = READ_TARGET_WIDTH / 8,          // リード下流側バイト数
    parameter int unsigned WRITE_SOURCE_ADDR_BITS = $clog2(WRITE_SOURCE_BYTES), // ライト上流側アドレスビット数
    parameter int unsigned WRITE_TARGET_ADDR_BITS = $clog2(WRITE_TARGET_BYTES), // ライト下流側アドレスビット数
    parameter int unsigned READ_SOURCE_ADDR_BITS = $clog2(READ_SOURCE_BYTES),   // リード上流側アドレスビット数
    parameter int unsigned READ_TARGET_ADDR_BITS = $clog2(READ_TARGET_BYTES)    // リード下流側アドレスビット数
)(
    // クロック・リセット
    input  logic aclk,
    input  logic aresetn,
    
    // スレーブ側AXI4インターフェース
    // ライトアドレスチャネル
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]              s_axi_awsize,
    input  logic [7:0]              s_axi_awlen,
    input  logic [1:0]              s_axi_awburst,
    input  logic [7:0]              s_axi_awid,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    
    // ライトデータチャネル
    input  logic [WRITE_SOURCE_WIDTH-1:0] s_axi_wdata,
    input  logic [WRITE_SOURCE_BYTES-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    input  logic                    s_axi_wlast,
    
    // ライト応答チャネル
    output logic [7:0]              s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    
    // リードアドレスチャネル
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]              s_axi_arsize,
    input  logic [7:0]              s_axi_arlen,
    input  logic [1:0]              s_axi_arburst,
    input  logic [7:0]              s_axi_arid,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    
    // リードデータチャネル
    output logic [READ_SOURCE_WIDTH-1:0] s_axi_rdata,
    output logic [7:0]              s_axi_rid,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic                    s_axi_rlast,
    
    // マスター側AXI4インターフェース
    // ライトアドレスチャネル
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [2:0]              m_axi_awsize,
    output logic [7:0]              m_axi_awlen,
    output logic [1:0]              m_axi_awburst,
    output logic [7:0]              m_axi_awid,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    
    // ライトデータチャネル
    output logic [WRITE_TARGET_WIDTH-1:0] m_axi_wdata,
    output logic [WRITE_TARGET_BYTES-1:0] m_axi_wstrb,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic                    m_axi_wlast,
    
    // ライト応答チャネル
    input  logic [7:0]              m_axi_bid,
    input  logic [1:0]              m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    
    // リードアドレスチャネル
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [2:0]              m_axi_arsize,
    output logic [7:0]              m_axi_arlen,
    output logic [1:0]              m_axi_arburst,
    output logic [7:0]              m_axi_arid,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    
    // リードデータチャネル
    input  logic [READ_TARGET_WIDTH-1:0] m_axi_rdata,
    input  logic [7:0]              m_axi_rid,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic                    m_axi_rlast
);
```

#### 3.2.2 パラメータ説明

**ライト側パラメータ**:
| パラメータ | 説明 | デフォルト値 | 制約 |
|------------|------|--------------|------|
| `WRITE_SOURCE_WIDTH` | ライト上流側（狭い）バス幅 | 64 | 8, 16, 32, 64, 128, 256, 512 |
| `WRITE_TARGET_WIDTH` | ライト下流側（広い）バス幅 | 128 | 16, 32, 64, 128, 256, 512, 1024 |

**リード側パラメータ**:
| パラメータ | 説明 | デフォルト値 | 制約 |
|------------|------|--------------|------|
| `READ_SOURCE_WIDTH` | リード上流側バス幅 | 64 | 8, 16, 32, 64, 128, 256, 512 |
| `READ_TARGET_WIDTH` | リード下流側バス幅 | 64 | 8, 16, 32, 64, 128, 256, 512 |

**共通パラメータ**:
| パラメータ | 説明 | デフォルト値 | 制約 |
|------------|------|--------------|------|
| `ADDR_WIDTH` | アドレスバス幅 | 32 | メモリサイズ（2のN乗）から自動計算 |

**派生パラメータ（自動計算）**:
| パラメータ | 説明 | 計算式 |
|------------|------|--------|
| `WRITE_SOURCE_BYTES` | ライト上流側バイト数 | `WRITE_SOURCE_WIDTH / 8` |
| `WRITE_TARGET_BYTES` | ライト下流側バイト数 | `WRITE_TARGET_WIDTH / 8` |
| `READ_SOURCE_BYTES` | リード上流側バイト数 | `READ_SOURCE_WIDTH / 8` |
| `READ_TARGET_BYTES` | リード下流側バイト数 | `READ_TARGET_WIDTH / 8` |
| `WRITE_SOURCE_ADDR_BITS` | ライト上流側アドレスビット数 | `$clog2(WRITE_SOURCE_BYTES)` |
| `WRITE_TARGET_ADDR_BITS` | ライト下流側アドレスビット数 | `$clog2(WRITE_TARGET_BYTES)` |
| `READ_SOURCE_ADDR_BITS` | リード上流側アドレスビット数 | `$clog2(READ_SOURCE_BYTES)` |
| `READ_TARGET_ADDR_BITS` | リード下流側アドレスビット数 | `$clog2(READ_TARGET_BYTES)` |

**制約条件**:
- `WRITE_TARGET_WIDTH > WRITE_SOURCE_WIDTH`（ライト側バス幅増加のみ対応）
- `WRITE_TARGET_WIDTH % WRITE_SOURCE_WIDTH == 0`（ライト側整数倍のみ対応）
- `READ_SOURCE_WIDTH == READ_TARGET_WIDTH`（リード側は同じ幅）
- `WRITE_SOURCE_WIDTH >= 8`（最小8ビット）
- `WRITE_TARGET_WIDTH >= 16`（最小16ビット）
- `WRITE_TARGET_WIDTH <= 1024`（最大1024ビット）
- メモリサイズは2のN乗のみ（例：1KB, 2KB, 4KB, 8KB, 16KB, 32KB, 64KB, 128KB, 256KB, 512KB, 1MB, 2MB, 4MB, 8MB, 16MB, 32MB, 64MB, 128MB, 256MB, 512MB, 1GB等）
- IDバス幅は固定8ビット

#### 3.2.3 信号説明

**スレーブ側インターフェース（s_axi_*）**:
- AXI4マスターから接続
- ライトデータ幅: `WRITE_SOURCE_WIDTH`ビット
- ライトストローブ幅: `WRITE_SOURCE_BYTES`ビット
- リードデータ幅: `READ_SOURCE_WIDTH`ビット
- ID幅: 8ビット（固定）

**マスター側インターフェース（m_axi_*）**:
- AXI4スレーブに接続
- ライトデータ幅: `WRITE_TARGET_WIDTH`ビット
- ライトストローブ幅: `WRITE_TARGET_BYTES`ビット
- リードデータ幅: `READ_TARGET_WIDTH`ビット
- ID幅: 8ビット（固定）

**共通信号**:
- `aclk`: AXI4システムクロック
- `aresetn`: AXI4アクティブローリセット
- アドレス、ID、バースト情報は変換されずにそのまま転送（データの増幅用にラッチされた後に出力）
- ライト応答チャネル（Bチャネル）は下流の末端から帰ってくるため、変換無しでそのまま転送
- **ライト側**: データとストローブのみが変換対象
- **リード側**: 変換なし（直結）

## 4. コード

### 4.1 DUTのコード

バス幅変換のWriteチャネルの実装を示します。

以下はAIに対する実装の指示です。

```
コードの作成をお願いします。ファイル名はaxi_write_n2w_width_converter.svです。

ライトだけ実装します。リードとレスポンスチャネルは入力と出力を直結にしてください。
ライトのT0AとT0Dはpart07_axi_simple_dual_port_ramのaxi_simple_dual_port_ram.svを参考にしてください。
T1ステージはT1DとT1Aに分けます。T1Dの実装法はpart14_axi_write_n2w_width_converter.mdを参照し、T1AはT0Aをそのままパイプラインで接続してください。

axi_breadyはこのパイプラインには使用せずに代わりに、アドレス側はm_axi_awreadyをデータ側はm_axi_wreadyに置き換えてください。

次にこのモジュールに接続するAXIのメモリを作成します。
part07_axi_simple_dual_port_ramのaxi_simple_dual_port_ram.svをローカルにコピーしてaxi_dual_width_dual_port_ram.svにリネームしてのREADとWRITEのデータバスを個別に指定できるようにしてください。このコードの中のメモリはdual_width_dual_port_ram.vでインスタンスを作成して使用します。

次に、axi_write_n2w_width_converterとdual_width_dual_port_ramを接続するモジュールdutを作成してください。このモジュールをpart13で作成したテストベンチでテストしてください。
axi_common_defs.svhはローカルのファイルを使用し、その他のファイルは相対パスでpart13のファイルをコンパイルしてください。

```

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
