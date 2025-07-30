# AXI パイプライン回路設計ガイド - API リファレンス

## 目次

- [AXI パイプライン回路設計ガイド - API リファレンス](#axi-パイプライン回路設計ガイド---api-リファレンス)
  - [目次](#目次)
  - [1. 概要](#1-概要)
  - [2. モジュール一覧](#2-モジュール一覧)
  - [3. pipeline_4stage モジュール](#3-pipeline_4stage-モジュール)
    - [3.1 モジュール概要](#31-モジュール概要)
    - [3.2 パラメータ](#32-パラメータ)
    - [3.3 ポート仕様](#33-ポート仕様)
    - [3.4 内部信号](#34-内部信号)
    - [3.5 動作仕様](#35-動作仕様)
  - [4. インターフェース仕様](#4-インターフェース仕様)
    - [4.1 Ready/Valid ハンドシェイク](#41-readyvalid-ハンドシェイク)
    - [4.2 タイミング仕様](#42-タイミング仕様)
  - [5. 使用例](#5-使用例)
    - [5.1 基本的な使用方法](#51-基本的な使用方法)
    - [5.2 複数モジュールの連結](#52-複数モジュールの連結)
    - [5.3 テストベンチ例](#53-テストベンチ例)
  - [6. 設計ガイドライン](#6-設計ガイドライン)
    - [6.1 パラメータ設定](#61-パラメータ設定)
    - [6.2 リセット仕様](#62-リセット仕様)
    - [6.3 クロック要件](#63-クロック要件)
  - [7. パフォーマンス特性](#7-パフォーマンス特性)
  - [8. 制限事項](#8-制限事項)
  - [ライセンス](#ライセンス)

---

## 1. 概要

このドキュメントは、AXI バスパイプライン回路設計ガイドプロジェクトで提供される全ての公開 API、関数、およびコンポーネントの包括的なリファレンスです。

**プロジェクト構成**:
- **pipeline_4stage.v**: 4段パイプラインモジュール（メインコンポーネント）
- **4-stage_pipeline.md**: パイプライン動作原理の詳細解説
- **sequence_chart_rules.md**: シーケンスチャート記述ルール
- **API_REFERENCE.md**: 本ドキュメント（API リファレンス）

## 2. モジュール一覧

| モジュール名 | ファイル | 説明 | 用途 |
|-------------|---------|------|------|
| `pipeline_4stage` | pipeline_4stage.v | 4段パイプライン処理モジュール | AXI バス互換パイプライン実装 |

## 3. pipeline_4stage モジュール

### 3.1 モジュール概要

**モジュール名**: `pipeline_4stage`  
**説明**: Ready/Valid ハンドシェイクを使用した4段パイプライン処理モジュール  
**用途**: AXI バス互換のデータパイプライン処理

**主な特徴**:
- 4段シフトレジスタ構造による効率的なパイプライン処理
- Ready/Valid ハンドシェイクによる流量制御
- パラメータ化可能なデータ幅
- ストール動作とバブル動作の完全サポート
- 非同期リセット対応

### 3.2 パラメータ

| パラメータ名 | タイプ | デフォルト値 | 範囲 | 説明 |
|-------------|--------|-------------|------|------|
| `DATA_WIDTH` | integer | 32 | 1 ≤ DATA_WIDTH ≤ 1024 | データバスのビット幅 |

**使用例**:
```verilog
// 32ビットデータ幅（デフォルト）
pipeline_4stage #() pipe_default (
    // ポート接続
);

// 64ビットデータ幅
pipeline_4stage #(
    .DATA_WIDTH(64)
) pipe_64bit (
    // ポート接続
);

// 8ビットデータ幅
pipeline_4stage #(
    .DATA_WIDTH(8)
) pipe_8bit (
    // ポート接続
);
```

### 3.3 ポート仕様

#### 3.3.1 クロック・リセット

| ポート名 | 方向 | ビット幅 | タイプ | 説明 |
|---------|------|---------|-------|------|
| `clk` | input | 1 | wire | システムクロック（正エッジトリガ） |
| `rst_n` | input | 1 | wire | 非同期リセット（負論理） |

#### 3.3.2 上流インターフェース（入力側）

| ポート名 | 方向 | ビット幅 | タイプ | 説明 |
|---------|------|---------|-------|------|
| `u_data` | input | `DATA_WIDTH` | wire | 上流からの入力データ |
| `u_valid` | input | 1 | wire | 入力データ有効信号 |
| `u_ready` | output | 1 | wire | 入力受付可能信号 |

#### 3.3.3 下流インターフェース（出力側）

| ポート名 | 方向 | ビット幅 | タイプ | 説明 |
|---------|------|---------|-------|------|
| `d_data` | output | `DATA_WIDTH` | wire | 下流への出力データ |
| `d_valid` | output | 1 | wire | 出力データ有効信号 |
| `d_ready` | input | 1 | wire | 下流受付可能信号 |

### 3.4 内部信号

| 信号名 | ビット幅 | 説明 |
|-------|---------|------|
| `t_data[3:0]` | `DATA_WIDTH` | 各段のデータレジスタ (T0, T1, T2, T3) |
| `t_valid[3:0]` | 1 | 各段の有効信号レジスタ (T0, T1, T2, T3) |
| `ready` | 1 | 共通Ready信号（d_readyと同値） |

**段階定義**:
- **T0**: 入力段階（1段目）
- **T1**: 第1中間段階（2段目）
- **T2**: 第2中間段階（3段目）
- **T3**: 出力段階（4段目）

### 3.5 動作仕様

#### 3.5.1 基本動作

1. **データ転送条件**: `u_valid = 1` かつ `d_ready = 1` の時のみデータが転送される
2. **パイプライン動作**: データは T0 → T1 → T2 → T3 の順で段階的に処理される
3. **レイテンシ**: 入力から出力まで4クロックサイクル
4. **スループット**: 1クロックサイクルあたり1つのデータ処理（理想状態）

#### 3.5.2 ストール動作

`d_ready = 0` の場合：
- パイプライン全体が停止
- 全ての段でデータが保持される
- `u_ready = 0` を出力して上流に停止を通知

#### 3.5.3 バブル動作

`u_valid = 0` の場合：
- 無効データ（バブル）がパイプラインを流れる
- データ値は更新されるが、`valid` 信号により無効として扱われる

## 4. インターフェース仕様

### 4.1 Ready/Valid ハンドシェイク

#### 4.1.1 プロトコル仕様

**基本ルール**:
- `valid` 信号は、対応する `ready` 信号に依存してはならない
- `ready` 信号は、対応する `valid` 信号に依存しても良い（組み合わせ回路）
- データ転送は `valid` かつ `ready` が共に `1` の時に発生

#### 4.1.2 信号関係

```
転送発生 = u_valid & u_ready (入力側)
転送発生 = d_valid & d_ready (出力側)
```

#### 4.1.3 タイミング要件

| 信号 | セットアップ時間 | ホールド時間 | 備考 |
|------|----------------|-------------|------|
| `u_data` | クロック前 | クロック後 | `u_valid = 1` の時のみ有効 |
| `u_valid` | クロック前 | クロック後 | - |
| `d_ready` | クロック前 | クロック後 | 組み合わせ回路で伝播 |

### 4.2 タイミング仕様

#### 4.2.1 クロック要件

- **最小クロック周期**: 実装に依存（通常 2-10ns）
- **デューティ比**: 40-60%（推奨 50%）
- **クロックスキュー**: 最大クロック周期の10%

#### 4.2.2 リセット要件

- **リセット幅**: 最小3クロックサイクル
- **リセット解放**: クロック立ち上がりエッジに同期して解放（推奨）

## 5. 使用例

### 5.1 基本的な使用方法

```verilog
module basic_usage_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] input_data,
    input  wire        input_valid,
    output wire        input_ready,
    output wire [31:0] output_data,
    output wire        output_valid,
    input  wire        output_ready
);

    // 4段パイプラインの実装
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (input_data),
        .u_valid (input_valid),
        .u_ready (input_ready),
        .d_data  (output_data),
        .d_valid (output_valid),
        .d_ready (output_ready)
    );

endmodule
```

### 5.2 複数モジュールの連結

```verilog
module cascade_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] input_data,
    input  wire        input_valid,
    output wire        input_ready,
    output wire [31:0] output_data,
    output wire        output_valid,
    input  wire        output_ready
);

    // 中間信号
    wire [31:0] mid_data;
    wire        mid_valid;
    wire        mid_ready;

    // 第1段パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline1 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (input_data),
        .u_valid (input_valid),
        .u_ready (input_ready),
        .d_data  (mid_data),
        .d_valid (mid_valid),
        .d_ready (mid_ready)
    );

    // 第2段パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline2 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (mid_data),
        .u_valid (mid_valid),
        .u_ready (mid_ready),
        .d_data  (output_data),
        .d_valid (output_valid),
        .d_ready (output_ready)
    );

endmodule
```

### 5.3 テストベンチ例

```verilog
module pipeline_4stage_tb;

    // テストベンチ信号
    reg         clk;
    reg         rst_n;
    reg  [31:0] u_data;
    reg         u_valid;
    wire        u_ready;
    wire [31:0] d_data;
    wire        d_valid;
    reg         d_ready;

    // DUT（被試験デバイス）
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (u_data),
        .u_valid (u_valid),
        .u_ready (u_ready),
        .d_data  (d_data),
        .d_valid (d_valid),
        .d_ready (d_ready)
    );

    // クロック生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns周期
    end

    // テスト実行
    initial begin
        // 初期化
        rst_n = 0;
        u_data = 0;
        u_valid = 0;
        d_ready = 1;

        // リセット解放
        repeat(3) @(posedge clk);
        rst_n = 1;

        // データ送信テスト
        repeat(2) @(posedge clk);
        for (int i = 0; i < 10; i++) begin
            u_data = i;
            u_valid = 1;
            @(posedge clk);
        end
        u_valid = 0;

        // テスト終了
        repeat(10) @(posedge clk);
        $finish;
    end

    // モニタリング
    always @(posedge clk) begin
        if (d_valid && d_ready) begin
            $display("Time=%0t: Output data = %0d", $time, d_data);
        end
    end

endmodule
```

## 6. 設計ガイドライン

### 6.1 パラメータ設定

#### 6.1.1 DATA_WIDTH の選択

| 用途 | 推奨値 | 理由 |
|------|-------|------|
| 8ビットデータ処理 | 8 | バイト単位処理 |
| AXI4-Lite | 32 | 標準データ幅 |
| AXI4 | 32, 64, 128, 256, 512 | 標準データ幅 |
| カスタム用途 | 2^n | 効率的な実装 |

#### 6.1.2 実装時の注意点

```verilog
// 推奨: パラメータ化された実装
parameter DATA_WIDTH = 32;
wire [DATA_WIDTH-1:0] data_bus;

// 非推奨: ハードコードされた値
wire [31:0] data_bus; // DATA_WIDTHが変更された時に不整合
```

### 6.2 リセット仕様

#### 6.2.1 リセット戦略

- **非同期アサート、同期デアサート**を推奨
- 全ての内部状態を既知の値にリセット
- パワーオンリセット時は最低10クロック以上の幅を確保

#### 6.2.2 リセット実装例

```verilog
// 推奨リセット実装
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 非同期リセット
        for (integer i = 0; i < 4; i = i + 1) begin
            t_data[i]  <= {DATA_WIDTH{1'b0}};
            t_valid[i] <= 1'b0;
        end
    end else begin
        // 通常動作
        if (ready) begin
            // データ更新処理
        end
    end
end
```

### 6.3 クロック要件

#### 6.3.1 クロック品質

- **ジッタ**: 最大周期の5%以下
- **スキュー**: チップ内で最大周期の10%以下
- **デューティ比**: 45-55%（厳しい場合）、40-60%（一般的）

#### 6.3.2 クロックドメイン

- 全てのコンポーネントは同一クロックドメインで動作
- 異なるクロックドメイン間ではCDC（Clock Domain Crossing）回路が必要

## 7. パフォーマンス特性

### 7.1 レイテンシ

| 動作状態 | レイテンシ（クロック数） | 備考 |
|---------|----------------------|------|
| 通常動作 | 4 | T0→T1→T2→T3 |
| ストール発生時 | 4 + ストール期間 | Ready=0の期間 |
| バブル挿入時 | 4 | レイテンシは変わらず |

### 7.2 スループット

| 動作状態 | スループット | 効率 |
|---------|-------------|------|
| 連続データ | 1データ/クロック | 100% |
| 間欠データ | Valid依存 | Valid率に比例 |
| ストール有り | Ready依存 | Ready率に比例 |

### 7.3 リソース使用量

| リソース | 使用量 | 計算式 |
|---------|-------|-------|
| フリップフロップ | `4 × (DATA_WIDTH + 1)` | データ4段 + Valid4段 |
| 組み合わせロジック | 最小限 | Ready信号の接続のみ |
| メモリ | 0 | 使用しない |

## 8. 制限事項

### 8.1 設計上の制限

1. **パイプライン段数**: 4段固定（変更不可）
2. **データ幅**: パラメータで設定可能だが、合成ツールの制限による上限あり
3. **Ready信号**: 組み合わせ回路で伝播するため、長い組み合わせパスになる可能性

### 8.2 タイミング制約

1. **セットアップ・ホールド**: Ready信号の組み合わせ遅延を考慮した制約が必要
2. **ファンアウト**: Ready信号が全段に接続されるため、ファンアウト制約が必要
3. **クロックスキュー**: 全段で同期動作するため、スキュー制約が重要

### 8.3 使用上の注意

1. **Ready信号の遅延**: 下流の遅延が上流に直接影響するため、長い組み合わせパスは避ける
2. **バックプレッシャー**: 複数段を連結する場合、Ready信号の伝播遅延に注意
3. **シミュレーション**: タイミング検証には静的タイミング解析（STA）が必須

---

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details.

このドキュメントは、AIがハードウェア設計を学習するための教師データとしても活用できるよう設計されています。