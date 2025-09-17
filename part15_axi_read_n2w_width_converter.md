# AXIバス設計ガイド 第15回 AXI読み出し幅変換器

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
      - [リード側パイプライン構成](#リード側パイプライン構成)
      - [パイプライン制御の特徴](#パイプライン制御の特徴)
  - [ライセンス](#ライセンス)

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

第15回では狭いデータバス幅から広いデータバス幅に変換する読み出し専用コンポーネントの実装について説明します。


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
| バースト長 | 4 | 2 | 1/2に圧縮 |
| アドレス | 0x00 | 0x00 | そのまま |
| データ1 | 0x12 | 0x1212 | 2回分を結合 |
| データ2 | 0x34 | 0x3434 | 2回分を結合 |

**変換ルール**:
- 2つの8bitデータを1つの16bitデータに結合
- バースト長は1/2に圧縮

#### 2.2.2 size=2(4バイト)、4ビートのバースト転送

**32bit→64bit変換の場合**:

| 項目 | 上流（32bit） | 下流（64bit） | 説明 |
|------|---------------|---------------|------|
| データ幅 | 32bit | 64bit | 2倍に拡張 |
| バースト長 | 4 | 2 | 1/2に圧縮 |
| アドレス | 0x00 | 0x00 | そのまま |
| データ1 | 0x12345678 | 0x1234567812345678 | 2回分を結合 |
| データ2 | 0x9ABCDEF0 | 0x9ABCDEF09ABCDEF0 | 2回分を結合 |

**変換ルール**:
- 2つの32bitデータを1つの64bitデータに結合
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

#### 2.3.2 具体例による計算過程（汎用バス幅変換）

**32bit→128bit変換（RATIO=4）の場合**:

| 上流側 | 下流側 | 計算過程 |
|--------|--------|----------|
| データ幅 | 32bit → 128bit | 32 × 4 = 128 |
| バースト長 | 8 → 2 | 8 ÷ 4 = 2 |
| アドレス | 0x00 → 0x00 | そのまま |
| データ1 | 0x12345678 → 0x12345678123456781234567812345678 | 4回複製 |
| データ2 | 0x9ABCDEF0 → 0x9ABCDEF09ABCDEF09ABCDEF09ABCDEF0 | 4回複製 |

## 3. 仕様

### 3.1 パイプライン構成

#### リード側パイプライン構成

リード側は2段構成のパイプラインで、2つのペイロードが並列に動作します：

```
m_r_Payload_D=> [T0D] ===> [T1D] => s_r_Payload_D
                 ^         ^^ ^ 
                 |         || | 
m_r_Ready_D   <-[AND]---+--||-+- <- s_r_Ready_D
                 ^      |  || 
                 |      |  || 
       [T0D_Ready]      |  ||
                  ++====|=>[T1A2]
                  ||    |
                  ||    |   
s_r_Payload_A=> [T0A] ===> [T1A] => m_r_Payload_A
                 ^      |    ^      
                 |      |    |      
s_r_Ready_A   <-[AND]<--+----+-- <- m_r_Ready_A
                 ^ ^                     
                 | |        
       [T0A_Ready] |        
              [T0A_M_Ready]
```

**リード側パイプラインの詳細**:

| 段階 | 機能 | 説明 | ペイロード増幅 | レイテンシ |
|------|------|------|------------|------------|
| T0A | アドレス処理 | アドレスとデータの同時並列処理 | **アドレスは1→N個に増加** | 1クロック |
| T1A | 待ち合わせ制御 | データを変換 | **増幅なし**（N個維持） | 1クロック |

| 段階 | 機能 | 説明 | ペイロード増幅 | レイテンシ |
|------|------|------|------------|------------|
| T0D | データ処理 | アドレスとデータの同時並列処理 | **アドレスは1→N個に増加** | 1クロック |
| T1D | バス幅変換回路 | データを変換 | **増幅なし**（N個維持） | 1クロック |

**リード側の特徴**:
- **T0A/T0Dステージ**: アドレス・データ並列処理
- **T1ステージ**: 変換回路（レイテンシ1）
- **総レイテンシ**: 2クロック（T0: 1 + T1: 1）

#### パイプライン制御の特徴

**独立動作**:
- リードのパイプラインが独立して動作
- パイプラインが独自のReady制御で動作

**Ready制御**:
- 上流へのReady信号は非同期ANDで生成

**メモリレイテンシ**:
- **リード側**: メモリレイテンシ2を採用（FPGAのBRAMの構造による要件）
- 論理合成ツールでの最適化が容易

### 3.2 ポート定義

#### 3.2.1 モジュール宣言

```systemverilog
module axi_read_width_converter #(
    parameter int unsigned SOURCE_WIDTH = 64,        // 上流側バス幅（ビット）
    parameter int unsigned TARGET_WIDTH = 128,       // 下流側バス幅（ビット）
    parameter int unsigned ADDR_WIDTH = 32,          // アドレスバス幅（ビット）
    
    // 派生パラメータ（自動計算）
    parameter int unsigned SOURCE_BYTES = SOURCE_WIDTH / 8,        // 上流側バイト数
    parameter int unsigned TARGET_BYTES = TARGET_WIDTH / 8,        // 下流側バイト数
    parameter int unsigned SOURCE_ADDR_BITS = $clog2(SOURCE_BYTES), // 上流側アドレスビット数
    parameter int unsigned TARGET_ADDR_BITS = $clog2(TARGET_BYTES)  // 下流側アドレスビット数
)(
    // クロック・リセット
    input  logic aclk,
    input  logic aresetn,
    
    // スレーブ側AXI4インターフェース（狭いバス幅）
    // リードアドレスチャネル
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]              s_axi_arsize,
    input  logic [7:0]              s_axi_arlen,
    input  logic [1:0]              s_axi_arburst,
    input  logic [7:0]              s_axi_arid,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    
    // リードデータチャネル
    output logic [SOURCE_WIDTH-1:0] s_axi_rdata,
    output logic [7:0]              s_axi_rid,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,
    output logic                    s_axi_rlast,
    
    // マスター側AXI4インターフェース（広いバス幅）
    // リードアドレスチャネル
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [2:0]              m_axi_arsize,
    output logic [7:0]              m_axi_arlen,
    output logic [1:0]              m_axi_arburst,
    output logic [7:0]              m_axi_arid,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    
    // リードデータチャネル
    input  logic [TARGET_WIDTH-1:0] m_axi_rdata,
    input  logic [7:0]              m_axi_rid,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic                    m_axi_rlast
);
```

#### 3.2.2 パラメータ説明

| パラメータ | 説明 | デフォルト値 | 制約 |
|------------|------|--------------|------|
| `SOURCE_WIDTH` | 上流側（狭い）バス幅 | 64 | 8, 16, 32, 64, 128, 256, 512 |
| `TARGET_WIDTH` | 下流側（広い）バス幅 | 128 | 16, 32, 64, 128, 256, 512, 1024 |
| `ADDR_WIDTH` | アドレスバス幅 | 32 | メモリサイズ（2のN乗）から自動計算 |

**派生パラメータ（自動計算）**:
| パラメータ | 説明 | 計算式 |
|------------|------|--------|
| `SOURCE_BYTES` | 上流側バイト数 | `SOURCE_WIDTH / 8` |
| `TARGET_BYTES` | 下流側バイト数 | `TARGET_WIDTH / 8` |
| `SOURCE_ADDR_BITS` | 上流側アドレスビット数 | `$clog2(SOURCE_BYTES)` |
| `TARGET_ADDR_BITS` | 下流側アドレスビット数 | `$clog2(TARGET_BYTES)` |

**制約条件**:
- `TARGET_WIDTH > SOURCE_WIDTH`（バス幅増加のみ対応）
- `TARGET_WIDTH % SOURCE_WIDTH == 0`（整数倍のみ対応）
- `SOURCE_WIDTH >= 8`（最小8ビット）
- `TARGET_WIDTH >= 16`（最小16ビット）
- `TARGET_WIDTH <= 1024`（最大1024ビット）
- メモリサイズは2のN乗のみ（例：1KB, 2KB, 4KB, 8KB, 16KB, 32KB, 64KB, 128KB, 256KB, 512KB, 1MB, 2MB, 4MB, 8MB, 16MB, 32MB, 64MB, 128MB, 256MB, 512MB, 1GB等）
- IDバス幅は固定8ビット

#### 3.2.3 信号説明

**スレーブ側インターフェース（s_axi_*）**:
- 狭いバス幅のAXI4マスターから接続
- データ幅: `SOURCE_WIDTH`ビット
- ID幅: 8ビット（固定）

**マスター側インターフェース（m_axi_*）**:
- 広いバス幅のAXI4スレーブに接続
- データ幅: `TARGET_WIDTH`ビット
- ID幅: 8ビット（固定）

**共通信号**:
- `aclk`: AXI4システムクロック
- `aresetn`: AXI4アクティブローリセット
- アドレス、ID、バースト情報は変換されずにそのまま転送（データの増幅用にラッチされた後に出力）
- データのみが変換対象


## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
