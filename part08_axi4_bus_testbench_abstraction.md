# AXIバスのパイプライン回路設計ガイド ～ 第8回 AXI4バス・テストベンチの本質要素抽象化設計

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第8回 AXI4バス・テストベンチの本質要素抽象化設計](#axiバスのパイプライン回路設計ガイド--第8回-axi4バス・テストベンチの本質要素抽象化設計)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 本質要素抽象化の設計方針](#2-本質要素抽象化の設計方針)
    - [2.1 パラメータ設定系](#21-パラメータ設定系)
    - [2.2 ハードウェア制御系](#22-ハードウェア制御系)
    - [2.3 テストデータ生成・制御系](#23-テストデータ生成・制御系)
    - [2.4 データ検証系](#24-データ検証系)
    - [2.5 プロトコル検証系](#25-プロトコル検証系)
    - [2.6 監視・ログ系](#26-監視・ログ系)
    - [2.7 重み付き乱数発生系](#27-重み付き乱数発生系)
  - [3. 抽象化されたAXI4バスコンポーネントの実装](#3-抽象化されたaxi4バスコンポーネントの実装)
  - [4. 抽象化されたテストベンチフレームワークの実装](#4-抽象化されたテストベンチフレームワークの実装)
  - [5. 本質要素抽象化の効果と検証](#5-本質要素抽象化の効果と検証]
    - [5.1 設計効率の向上](#51-設計効率の向上)
    - [5.2 再利用性の検証](#52-再利用性の検証)
    - [5.3 保守性の向上](#53-保守性の向上)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

第7回でテストベンチの自動生成を試みましたが、期待した結果が得られませんでした。このドキュメントとコードはCursorのProモードを使用して作成しています。

Proモードの特徴として、月初めにはコード全体を読み込んで包括的な回答を提供します。しかし、この状態であいまいな指示でAIにデバッグを依頼すると、トークンの消費が激しく、短期間で使い切ってしまいます。トークンを使い切った後は、コードの一部しか参照できない制限されたモードに移行します。

第7回と第8回では、この制限された状態でCursorに適切な指示を出し、効果的な設計を実現する試みを行っています。本質要素抽象化の設計手法により、限られた情報でも質の高いコード生成が可能になることを目指しています。

## 2. 本質要素抽象化の設計方針

まず、テストベンチの基本要素を考えてみましょう。

テストベンチの設計において、本質的な要素を抽象化することで、再利用性と保守性を大幅に向上させることができます。以下に、6つの基本要素を定義します：

#### テストベンチの基本要素

**1. パラメータ設定系（最優先）**
- **テスト動作パラメータ**: テストベンチの動作を定義する設定値
- **モジュールTOP指示パラメータ**: テスト対象モジュールへの指示パラメータ
- **テスト条件パラメータ**: テストの実行条件や制約を定義するパラメータ

**2. ハードウェア制御系**
- **クロック制御**: システムクロックの生成と制御
- **リセット制御**: リセット信号の生成と制御

**3. テストデータ生成・制御系**
- **スティミュラス生成**: テストパターンやテストベクタの生成

**4. データ検証系**
- **期待値比較**: 出力データと期待値の照合
- **タイミング検証**: 信号のタイミング要件の確認

**5. プロトコル検証系**
- **AXI4仕様準拠性チェック**: プロトコル要件の検証
- **ハンドシェイク検証**: Ready/Valid信号の動作確認
- **バースト転送検証**: バーストモードの動作確認

**6. 監視・ログ系**
- **テストシーケンス制御**: テストデータ制御とデータ検証のスタートストップ制御・監視
- **信号監視**: 重要な信号の状態監視
- **エラー検出**: 異常動作の検出と報告
- **タイムアウト監視**: テストの実行時間制限とタイムアウト検出
- **ログ出力**: テスト実行結果の記録

**7. 重み付き乱数発生系**
- **重み付き乱数生成**: 特定の値の出現頻度を制御する乱数生成

これらの要素を独立したモジュールとして実装し、パラメータによる設定変更が可能にすることで、様々なテストシナリオに対応できる柔軟なテストベンチフレームワークを構築できます。

### 2.1 パラメータ設定系

テストベンチの動作を定義するパラメータを体系的に設定することで、様々なテストシナリオに対応できる柔軟なシステムを構築します。

#### 基本パラメータ設定

```systemverilog
// テストベンチの基本パラメータ設定
module axi4_testbench_params;
    // メモリサイズとデータ幅の設定
    parameter MEMORY_SIZE_BYTES = 16384;        // 16KB
    parameter AXI_DATA_WIDTH = 32;              // 32bit
    parameter AXI_ID_WIDTH = 8;                 // 8bit ID
    
    // テスト実行回数の設定
    parameter TOTAL_TEST_COUNT = 1000;          // 総テスト回数
    parameter PHASE_TEST_COUNT = 2;             // 1Phase当たりのテスト回数
    
    // 自動計算されるパラメータ
    parameter AXI_ADDR_WIDTH = $clog2(MEMORY_SIZE_BYTES);           // アドレス幅（自動計算）
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;                  // ストローブ幅（自動計算）
    
    // バブル発生確率の設定（重み付き乱数パラメータ）
    typedef struct {
        int cyc_cnt_start;  // 開始サイクル数
        int cyc_cnt_end;    // 終了サイクル数
        int weight;         // 重み（出現確率）
    } bubble_param_t;
    
    // Writeアドレスバブルの確率設定
    bubble_param_t write_addr_bubble_weights[int];
    
    // Readアドレスバブルの確率設定
    bubble_param_t read_addr_bubble_weights[int];
    
    // Writeデータバブルの確率設定
    bubble_param_t write_data_bubble_weights[int];
    
    // b_Readyネゲートの確率設定
    bubble_param_t b_ready_negate_weights[int];
    
    // ReadデータReadyネゲートの確率設定
    bubble_param_t r_ready_negate_weights[int];
    
    // バースト設定を統合した構造体（範囲ベース）
    typedef struct {
        int length_min;       // バースト長の最小値
        int length_max;       // バースト長の最大値
        string burst_type;    // バーストタイプ（"FIXED", "INCR", "WRAP"）
        int weight;           // 重み（出現確率）
    } burst_config_t;
    
    // 統合されたバースト設定配列
    burst_config_t burst_config_weights[int];
    
    // パラメータの初期化
    initial begin
        // Writeアドレスバブルの確率設定
        write_addr_bubble_weights = '{
            0: '{cyc_cnt_start: 0, cyc_cnt_end: 0, weight: 60},    // バブルなし（60%）
            1: '{cyc_cnt_start: 1, cyc_cnt_end: 1, weight: 25},    // 1サイクルバブル（25%）
            2: '{cyc_cnt_start: 2, cyc_cnt_end: 2, weight: 10},    // 2サイクルバブル（10%）
            3: '{cyc_cnt_start: 3, cyc_cnt_end: 3, weight: 5}      // 3サイクルバブル（5%）
        };
        
        // Readアドレスバブルの確率設定
        read_addr_bubble_weights = '{
            0: '{cyc_cnt_start: 0, cyc_cnt_end: 0, weight: 70},    // バブルなし（70%）
            1: '{cyc_cnt_start: 1, cyc_cnt_end: 1, weight: 20},    // 1サイクルバブル（20%）
            2: '{cyc_cnt_start: 2, cyc_cnt_end: 2, weight: 8},     // 2サイクルバブル（8%）
            3: '{cyc_cnt_start: 3, cyc_cnt_end: 3, weight: 2}      // 3サイクルバブル（2%）
        };
        
        // Writeデータバブルの確率設定
        write_data_bubble_weights = '{
            0: '{cyc_cnt_start: 0, cyc_cnt_end: 0, weight: 65},    // バブルなし（65%）
            1: '{cyc_cnt_start: 1, cyc_cnt_end: 1, weight: 22},    // 1サイクルバブル（22%）
            2: '{cyc_cnt_start: 2, cyc_cnt_end: 2, weight: 10},    // 2サイクルバブル（10%）
            3: '{cyc_cnt_start: 3, cyc_cnt_end: 3, weight: 3}      // 3サイクルバブル（3%）
        };
        
        // b_Readyネゲートの確率設定
        b_ready_negate_weights = '{
            0: '{cyc_cnt_start: 0, cyc_cnt_end: 0, weight: 50},    // ネゲートなし（50%）
            1: '{cyc_cnt_start: 1, cyc_cnt_end: 1, weight: 30},    // 1サイクルネゲート（30%）
            2: '{cyc_cnt_start: 2, cyc_cnt_end: 2, weight: 15},    // 2サイクルネゲート（15%）
            3: '{cyc_cnt_start: 3, cyc_cnt_end: 3, weight: 4},     // 3サイクルネゲート（4%）
            4: '{cyc_cnt_start: 4, cyc_cnt_end: 8, weight: 1}      // 4-8サイクルネゲート（1%）
        };
        
        // ReadデータReadyネゲートの確率設定
        r_ready_negate_weights = '{
            0: '{cyc_cnt_start: 0, cyc_cnt_end: 0, weight: 55},    // ネゲートなし（55%）
            1: '{cyc_cnt_start: 1, cyc_cnt_end: 1, weight: 28},    // 1サイクルネゲート（28%）
            2: '{cyc_cnt_start: 2, cyc_cnt_end: 2, weight: 12},    // 2サイクルネゲート（12%）
            3: '{cyc_cnt_start: 3, cyc_cnt_end: 3, weight: 4},     // 3サイクルネゲート（4%）
            4: '{cyc_cnt_start: 4, cyc_cnt_end: 8, weight: 1}      // 4-8サイクルネゲート（1%）
        };
        
        // 統合されたバースト設定の初期化
        burst_config_weights = '{
            0: '{length_min: 1, length_max: 1, burst_type: "INCR", weight: 28},     // INCR, LENGTH=1（28%）
            1: '{length_min: 1, length_max: 1, burst_type: "WRAP", weight: 8},      // WRAP, LENGTH=1（8%）
            2: '{length_min: 1, length_max: 1, burst_type: "FIXED", weight: 4},     // FIXED, LENGTH=1（4%）
            3: '{length_min: 2, length_max: 4, burst_type: "INCR", weight: 15},     // INCR, LENGTH=2-4（15%）
            4: '{length_min: 2, length_max: 4, burst_type: "WRAP", weight: 4},      // WRAP, LENGTH=2-4（4%）
            5: '{length_min: 2, length_max: 4, burst_type: "FIXED", weight: 2},     // FIXED, LENGTH=2-4（2%）
            6: '{length_min: 5, length_max: 8, burst_type: "INCR", weight: 10},     // INCR, LENGTH=5-8（10%）
            7: '{length_min: 5, length_max: 8, burst_type: "WRAP", weight: 3},      // WRAP, LENGTH=5-8（3%）
            8: '{length_min: 5, length_max: 8, burst_type: "FIXED", weight: 1},     // FIXED, LENGTH=5-8（1%）
            9: '{length_min: 9, length_max: 16, burst_type: "INCR", weight: 8},     // INCR, LENGTH=9-16（8%）
            10: '{length_min: 9, length_max: 16, burst_type: "WRAP", weight: 2},    // WRAP, LENGTH=9-16（2%）
            11: '{length_min: 9, length_max: 16, burst_type: "FIXED", weight: 1},   // FIXED, LENGTH=9-16（1%）
            12: '{length_min: 17, length_max: 32, burst_type: "INCR", weight: 6},   // INCR, LENGTH=17-32（6%）
            13: '{length_min: 33, length_max: 64, burst_type: "INCR", weight: 4},   // INCR, LENGTH=63（4%）
            14: '{length_min: 65, length_max: 128, burst_type: "INCR", weight: 2}   // INCR, LENGTH=65-128（2%）
        };
    end
    
    // WRAP転送時のアドレス生成関数
    function automatic logic [AXI_ADDR_WIDTH-1:0][] generate_wrap_addresses(
        input logic [AXI_ADDR_WIDTH-1:0] start_address,
        input int length
    );
        logic [AXI_ADDR_WIDTH-1:0] addresses[];
        int burst_length = length + 1;
        int wrap_boundary;
        int boundary_mask;
        
        // AXI4規格チェック: LENGTHの制約
        if (length < 1 || length > 255) begin
            $error("AXI4 WRAP: Invalid LENGTH value %0d. LENGTH must be 1-255", length);
            $finish;
        end
        
        // AXI4規格チェック: バースト長は2のN乗である必要がある
        if ((burst_length & (burst_length - 1)) != 0) begin
            $error("AXI4 WRAP: Invalid burst length %0d. Burst length must be power of 2", burst_length);
            $finish;
        end
        
        // AXI4規格チェック: アドレスは境界の倍数である必要がある
        wrap_boundary = burst_length;
        if ((start_address % wrap_boundary) != 0) begin
            $error("AXI4 WRAP: Address 0x%h is not aligned to %0d-byte boundary", start_address, wrap_boundary);
            $finish;
        end
        
        // 配列サイズを設定
        addresses = new[burst_length];
        
        // 境界マスクを計算（境界サイズ-1）
        boundary_mask = wrap_boundary - 1;
        
        // 各転送のアドレスを生成
        for (int i = 0; i < burst_length; i++) begin
            // 基本アドレス（境界内のオフセット）
            addresses[i] = start_address + i;
            
            // 境界を超えた場合のラップアラウンド処理
            if ((addresses[i] & boundary_mask) >= wrap_boundary) begin
                addresses[i] = (start_address & ~boundary_mask) | (i & boundary_mask);
            end
        end
        
        return addresses;
    endfunction
    
    // シングルアクセス時のストローブ組み合わせ生成関数（2のN乗制限版）
    typedef struct {
        logic [AXI_STRB_WIDTH-1:0] strobe;  // ストローブパターン
        int byte_count;                      // バイト数
    } strobe_combination_t;
    
    function automatic strobe_combination_t[] generate_strobe_combinations(int strb_width);
        strobe_combination_t combinations[];
        int combination_count = 0;
        
        // 2のN乗のバイト数とオフセットのみを生成
        for (int byte_count = 1; byte_count <= strb_width; byte_count = byte_count << 1) begin
            if (byte_count > strb_width) break;
            
            for (int byte_offset = 0; byte_offset < strb_width; byte_offset = byte_offset + byte_count) begin
                if (byte_offset + byte_count <= strb_width) begin
                    combination_count++;
                end
            end
        end
        
        // 配列サイズを設定
        combinations = new[combination_count];
        
        // 各組み合わせを生成
        int idx = 0;
        for (int byte_count = 1; byte_count <= strb_width; byte_count = byte_count << 1) begin
            if (byte_count > strb_width) break;
            
            for (int byte_offset = 0; byte_offset < strb_width; byte_offset = byte_offset + byte_count) begin
                if (byte_offset + byte_count <= strb_width) begin
                    logic [strb_width-1:0] strobe = 0;
                    
                    // ストローブパターンを生成
                    for (int i = 0; i < strb_width; i++) begin
                        if (i >= byte_offset && i < byte_offset + byte_count) begin
                            strobe[i] = 1'b1;
                        end
                    end
                    
                    // 配列に格納
                    combinations[idx].strobe = strobe;
                    combinations[idx].byte_count = byte_count;
                    idx++;
                end
            end
        end
        
        return combinations;
    endfunction
    
    // パラメータ表示関数
    function automatic void display_parameters();
        $display("=== AXI4 Testbench Parameters ===");
        $display("Memory Size: %0d bytes", MEMORY_SIZE_BYTES);
        $display("Data Width: %0d bits", AXI_DATA_WIDTH);
        $display("ID Width: %0d bits", AXI_ID_WIDTH);
        $display("Address Width: %0d bits (auto-calculated)", AXI_ADDR_WIDTH);
        $display("Strobe Width: %0d bits (auto-calculated)", AXI_STRB_WIDTH);
        $display("Total Test Count: %0d", TOTAL_TEST_COUNT);
        $display("Phase Test Count: %0d", PHASE_TEST_COUNT);
        $display("================================");
    endfunction
    
endmodule
```

#### パラメータ設定の特徴

1. **自動計算パラメータ**: アドレス幅とストローブ幅は基本パラメータから自動計算
2. **重み付き確率設定**: 各バブル・ネゲート・バースト長の発生確率を重みで制御
3. **シングルアクセス対応**: バースト確率でシングルアクセス時のストローブ組み合わせを生成
4. **設定の柔軟性**: パラメータファイルで簡単に調整可能
5. **デバッグ支援**: パラメータ表示機能で設定内容を確認可能

このパラメータ設定により、テストベンチの動作を詳細に制御し、様々なテストシナリオに対応できます。

### 2.2 ハードウェア制御系

ハードウェア制御系では、クロックとリセットの生成・制御を行います。

#### 2.2 ハードウェア制御系 - Sample Code

```systemverilog
// クロック・リセット制御パラメータ
localparam CLK_PERIOD = 10;        // クロック周期 [ns]
localparam RESET_CYCLES = 5;       // リセット期間 [クロック数]
localparam CLK_HALF_PERIOD = CLK_PERIOD / 2;

// クロック・リセット信号
reg clk;
reg rst_n;

// クロック生成
initial begin
    clk = 0;
    forever #CLK_HALF_PERIOD clk = ~clk;
end

// リセット生成
initial begin
    rst_n = 0;
    repeat(RESET_CYCLES) @(posedge clk);
    rst_n = 1;
end

// クロック・リセット設定の表示
function void display_clock_reset_status;
    $display("Clock period: %0d ns", CLK_PERIOD);
    $display("Reset cycles: %0d", RESET_CYCLES);
endfunction
```

#### ハードウェア制御系の特徴

1. **クロック生成**: 指定された周期で安定したクロック信号を生成
2. **リセット制御**: 指定されたサイクル数のリセット期間を提供

### 2.3 テストデータ生成・制御系

### 2.4 データ検証系

### 2.5 プロトコル検証系

### 2.6 監視・ログ系

### 2.7 重み付き乱数発生系

テストベンチにおいて、特定の値の出現頻度を制御したい場合があります。例えば、READY信号をネゲートする頻度を制御して、ストールの発生パターンの調整です。

#### 重み付き乱数の基本概念

重み付き乱数は、各値に重み（出現確率）を設定し、その重みに基づいて乱数を発生させる手法です。これにより、テストシナリオに適した確率分布を持つ乱数を生成できます。

#### 統一された重み付き乱数システム

基本パラメータ設定で定義された統一された関数を使用して、全ての配列で一貫した重み付き乱数生成が可能です。

#### 統一された重み付き乱数生成関数の定義

```systemverilog
// 統一された重み付き乱数生成関数
function automatic int generate_weighted_random_index(
    input int weights[],
    input int total_weight
);
    int random_val;
    int cumulative_weight = 0;
    
    // 0から総重み-1の範囲で乱数生成
    random_val = $urandom_range(0, total_weight - 1);
    
    // 重みに基づくインデックスの選択
    for (int i = 0; i < weights.size(); i++) begin
        cumulative_weight += weights[i];
        if (random_val < cumulative_weight) begin
            return i;
        end
    end
    
    // デフォルト値
    return 0;
endfunction

// 統一された重み配列抽出関数
function automatic int[] extract_weights_generic(
    input int weight_field[],
    input int array_size
);
    int weights[];
    weights = new[array_size];
    
    for (int i = 0; i < array_size; i++) begin
        weights[i] = weight_field[i];
    end
    
    return weights;
endfunction

// 統一された総重み計算関数
function automatic int calculate_total_weight_generic(
    input int weights[]
);
    int total = 0;
    foreach (weights[i]) begin
        total += weights[i];
    end
    return total;
endfunction
```

#### 共通関数の使用方法

```systemverilog
// 1. 重み配列の抽出
int[] weights = extract_weights_generic(target_array, target_array.size());

// 2. 総重みの計算
int total_weight = calculate_total_weight_generic(weights);

// 3. 重み付き乱数でインデックスを選択
int selected_index = generate_weighted_random_index(weights, total_weight);

// 4. 選択されたインデックスから値を取得
// （配列の型に応じて適切なフィールドにアクセス）
```

#### 具体例1: r_ready_negate_weightsでの使用

```systemverilog
// r_ready_negate_weightsでの重み付き乱数生成
int[] r_ready_weights = extract_weights_generic(r_ready_negate_weights, r_ready_negate_weights.size());
int r_ready_total = calculate_total_weight_generic(r_ready_weights);
int r_ready_index = generate_weighted_random_index(r_ready_weights, r_ready_total);

// 選択された設定から値を取得
int r_ready_cycles = $urandom_range(
    r_ready_negate_weights[r_ready_index].cyc_cnt_start,
    r_ready_negate_weights[r_ready_index].cyc_cnt_end
);

$display("r_ready_negate: Index=%0d, Cycles=%0d", r_ready_index, r_ready_cycles);
```

#### 具体例2: burst_config_weightsでの使用

```systemverilog
// burst_config_weightsでの重み付き乱数生成
int[] burst_weights = extract_weights_generic(burst_config_weights, burst_config_weights.size());
int burst_total = calculate_total_weight_generic(burst_weights);
int burst_index = generate_weighted_random_index(burst_weights, burst_total);

// 選択された設定から値を取得
burst_config_t selected_burst = burst_config_weights[burst_index];
int selected_length = $urandom_range(selected_burst.length_min, selected_burst.length_max);
string selected_type = selected_burst.burst_type;

$display("Burst Config: Index=%0d, LENGTH=%0d-%0d, TYPE=%s, Generated LENGTH=%0d", 
         burst_index, selected_burst.length_min, selected_burst.length_max, 
         selected_type, selected_length);
```

#### 具体例3: 統合使用例

```systemverilog
// テストシーケンスでの統合使用
task generate_test_sequence;
    // 1. バースト設定の生成
    int[] burst_weights = extract_weights_generic(burst_config_weights, burst_config_weights.size());
    int burst_total = calculate_total_weight_generic(burst_weights);
    int burst_index = generate_weighted_random_index(burst_weights, burst_total);
    burst_config_t selected_burst = burst_config_weights[burst_index];
    
    // 2. r_readyネゲート設定の生成
    int[] r_ready_weights = extract_weights_generic(r_ready_negate_weights, r_ready_negate_weights.size());
    int r_ready_total = calculate_total_weight_generic(r_ready_weights);
    int r_ready_index = generate_weighted_random_index(r_ready_weights, r_ready_total);
    int r_ready_cycles = $urandom_range(
        r_ready_negate_weights[r_ready_index].cyc_cnt_start,
        r_ready_negate_weights[r_ready_index].cyc_cnt_end
    );
    
    // 3. 結果の表示
    $display("=== Test Sequence Generated ===");
    $display("Burst: LENGTH=%0d-%0d, TYPE=%s", 
             selected_burst.length_min, selected_burst.length_max, selected_burst.burst_type);
    $display("r_ready negate: %0d cycles", r_ready_cycles);
    
    // 4. 実際のテスト実行
    execute_test_sequence(selected_burst, r_ready_cycles);
endtask
```

#### 重み付き乱数の利点

1. **テストカバレッジの向上**: 特定のシナリオの発生確率を制御
2. **デバッグ効率の向上**: 問題が発生しやすい条件を重点的にテスト
3. **設定の柔軟性**: パラメータファイルで簡単に調整可能
4. **再利用性**: 共通関数により様々な配列で使用可能
5. **一貫性**: 全ての配列で同じパターンで乱数生成

この統一された重み付き乱数システムにより、テストベンチの動作を詳細に制御し、効率的なテストシナリオの実行が可能になります。

## 3. 抽象化されたAXI4バスコンポーネントの実装

## 4. 抽象化されたテストベンチフレームワークの実装

## 5. 本質要素抽象化の効果と検証

### 5.1 設計効率の向上

### 5.2 再利用性の検証

### 5.3 保守性の向上

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
