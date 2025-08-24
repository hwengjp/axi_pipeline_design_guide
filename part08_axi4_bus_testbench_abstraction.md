# AXIバス設計ガイド ～ 第8回 AXI4バス・テストベンチの本質要素抽象化設計

## 目次

  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 本質要素抽象化の設計方針](#2-本質要素抽象化の設計方針)
    - [2.1 パラメータ設定系](#21-パラメータ設定系)
    - [2.2 ハードウェア制御系](#22-ハードウェア制御系)
      - [2.2.1 ハードウェア制御系 - Sample Code](#221-ハードウェア制御系---sample-code)
    - [2.3 テストデータ生成・期待値生成・制御系](#23-テストデータ生成・期待値生成・制御系)
      - [2.3.1 テストシナリオ制御](#231-テストシナリオ制御)
      - [2.3.2 時間0でのペイロードと期待値生成](#232-時間0でのペイロードと期待値生成)
      - [2.3.3 Writeアドレスチャネルのテストデータ生成](#233-writeアドレスチャネルのテストデータ生成)
      - [2.3.4 Readアドレスチャネルのテストデータ生成](#234-readアドレスチャネルのテストデータ生成)
      - [2.3.5 Writeデータチャネルのテストデータ生成](#235-writeデータチャネルのテストデータ生成)
      - [2.3.6 Writeアドレスチャネルの制御回路](#236-writeアドレスチャネルの制御回路)
      - [2.3.7 Readアドレスチャネルの制御回路](#237-readアドレスチャネルの制御回路)
      - [2.3.8 Writeデータチャネルの制御回路](#238-writeデータチャネルの制御回路)
      - [2.3.9 Readデータチャネルの期待値生成](#239-readデータチャネルの期待値生成)
      - [2.3.10 Writeレスポンスチャネルの期待値生成](#2310-writeレスポンスチャネルの期待値生成)
      - [2.3.11 Readデータチャネルの制御回路](#2311-readデータチャネルの制御回路)
    - [2.4 プロトコル検証系](#24-プロトコル検証系)
      - [2.4.1 Readyネゲート時のペイロードホールド確認](#241-readyネゲート時のペイロードホールド確認)
    - [2.5 監視・ログ系](#25-監視・ログ系)
      - [2.5.1 基本ログ機能](#251-基本ログ機能)
      - [2.5.2 ログ機能の特徴](#252-ログ機能の特徴)
    - [2.6 重み付き乱数発生系](#26-重み付き乱数発生系)
  - [3. コード](#3-コード)
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
    parameter MEMORY_SIZE_BYTES = 33554432;     // 32MB
    parameter AXI_DATA_WIDTH = 32;              // 32bit
    parameter AXI_ID_WIDTH = 8;                 // 8bit ID
    
    // テスト実行回数の設定
    parameter TOTAL_TEST_COUNT = 1000;          // 総テスト回数
    parameter PHASE_TEST_COUNT = 2;             // 1Phase当たりのテスト回数
    
    // 1テストカウント毎のアドレス領域サイズ設定
    parameter TEST_COUNT_ADDR_SIZE_BYTES = 4096;     // 1テストカウント毎のアドレス領域サイズ（4KB）
    
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
        $display("Test Count Address Size: %0d bytes", TEST_COUNT_ADDR_SIZE_BYTES);
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
    #1
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

### 2.3 テストデータ生成・期待値生成・制御系

テストデータ生成・制御系では、DUTに与えるスティミュラスの生成と制御を行います。

#### 2.3.1 テストシナリオ制御

テストシナリオの制御を行います。期待値生成の確認、リセット解除の確認、フェーズ制御を含みます。

```verilog
// テストデータ生成完了フラグ
logic generate_stimulus_expected_done = 1'b0;

// フェーズ制御用信号
logic [7:0] current_phase = 8'd0;

// フェーズ開始信号（各チャネル用）
logic write_addr_phase_start = 1'b0;
logic read_addr_phase_start = 1'b0;
logic write_data_phase_start = 1'b0;
logic read_data_phase_start = 1'b0;

// フェーズ完了信号（各チャネル用）
logic write_addr_phase_done = 1'b0;
logic read_addr_phase_done = 1'b0;
logic write_data_phase_done = 1'b0;
logic read_data_phase_done = 1'b0;

// フェーズ完了信号のラッチ（各チャネル用）
logic write_addr_phase_done_latched = 1'b0;
logic read_addr_phase_done_latched = 1'b0;
logic write_data_phase_done_latched = 1'b0;
logic read_data_phase_done_latched = 1'b0;

// フェーズ完了信号のラッチ回路
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は初期化
        write_addr_phase_done_latched <= 1'b0;
        read_addr_phase_done_latched <= 1'b0;
        write_data_phase_done_latched <= 1'b0;
        read_data_phase_done_latched <= 1'b0;
    end else begin
        // パルス信号をラッチ
        if (write_addr_phase_done) write_addr_phase_done_latched <= 1'b1;
        if (read_addr_phase_done) read_addr_phase_done_latched <= 1'b1;
        if (write_data_phase_done) write_data_phase_done_latched <= 1'b1;
        if (read_data_phase_done) read_data_phase_done_latched <= 1'b1;
    end
end

// テストシナリオ制御
initial begin
    // 初期化
    current_phase = 8'd0;
    write_addr_phase_start = 1'b0;
    read_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
    
    // 期待値生成完了の確認
    wait(generate_stimulus_expected_done);
    $display("Phase %0d: Stimulus and Expected Values Generation Confirmed", current_phase);
    
    // リセット解除の確認
    wait(rst_n);
    $display("Phase %0d: Reset Deassertion Confirmed", current_phase);

    // 2クロック待ってからフェーズ開始信号をアサート
    repeat(2) @(posedge clk);
    #1        
    // 各チャネルのフェーズ開始信号を1クロックアサート
    write_addr_phase_start = 1'b1;
    write_data_phase_start = 1'b1;
        
    // 次のクロックで開始信号をクリア
    @(posedge clk);
    #1        
    write_addr_phase_start = 1'b0;
    write_data_phase_start = 1'b0;

    // 全チャネルのフェーズ完了を待機（ラッチした信号を使用）
    wait(write_addr_phase_done_latched && write_data_phase_done_latched);

    $display("Phase %0d: All Channels Completed", current_phase);

    @(posedge clk);
    #1        
    // ラッチした信号をクリア
    write_addr_phase_done_latched = 1'b0;
    write_data_phase_done_latched = 1'b0;

    current_phase = current_phase + 8'd1;

    // フェーズ制御ループ
    for (int phase = 0; phase < (TOTAL_TEST_COUNT / PHASE_TEST_COUNT) - 1; phase++) begin
        @(posedge clk);
        #1        
        // 各チャネルのフェーズ開始信号を1クロックアサート
        write_addr_phase_start = 1'b1;
        read_addr_phase_start = 1'b1;
        write_data_phase_start = 1'b1;
        read_data_phase_start = 1'b1;
        
        // 次のクロックで開始信号をクリア
        @(posedge clk);
        #1
        write_addr_phase_start = 1'b0;
        read_addr_phase_start = 1'b0;
        write_data_phase_start = 1'b0;
        read_data_phase_start = 1'b0;
        
        // 全チャネルのフェーズ完了を待機（ラッチした信号を使用）
        wait(write_addr_phase_done_latched && read_addr_phase_done_latched && 
             write_data_phase_done_latched && read_data_phase_done_latched);
        
        $display("Phase %0d: All Channels Completed", current_phase);
        
        @(posedge clk);
        #1        
        // ラッチした信号をクリア
        write_addr_phase_done_latched = 1'b0;
        read_addr_phase_done_latched = 1'b0;
        write_data_phase_done_latched = 1'b0;
        read_data_phase_done_latched = 1'b0;
        
        // 次のフェーズに移行
        current_phase = current_phase + 8'd1;
    end
    @(posedge clk);
    #1        
    // 各チャネルのフェーズ開始信号を1クロックアサート
    read_addr_phase_start = 1'b1;
    read_data_phase_start = 1'b1;
        
    // 次のクロックで開始信号をクリア
    @(posedge clk);
    #1
    read_addr_phase_start = 1'b0;
    read_data_phase_start = 1'b0;
        
    // 全チャネルのフェーズ完了を待機（ラッチした信号を使用）
    wait(read_addr_phase_done_latched && write_data_phase_done_latched);
        
    $display("Phase %0d: All Channels Completed", current_phase);
        
    @(posedge clk);
    #1        
    // ラッチした信号をクリア
    read_addr_phase_done_latched = 1'b0;
    read_data_phase_done_latched = 1'b0;
    
    // 全フェーズ完了
    $display("All Phases Completed. Test Scenario Finished.");
    $finish;
end
```


#### 2.3.2 時間0でのペイロードと期待値生成

Writeアドレスチャネル、Writeデータチャネル、Readアドレスチャネルの全てのペイロードを時間0で生成します。

```verilog
// 時間0でのペイロード生成
initial begin
    // Writeアドレスチャネルのペイロードを先に生成
    generate_write_addr_payloads();
    generate_write_addr_payloads_with_stall();
    
    // Writeデータチャネルのペイロードを生成
    generate_write_data_payloads();
    generate_write_data_payloads_with_stall();
    
    // Readアドレスチャネルのペイロードを生成
    generate_read_addr_payloads();
    generate_read_addr_payloads_with_stall();
    
    // Readデータチャネルの期待値を生成
    generate_read_data_expected();
    
    // Writeレスポンスチャネルの期待値を生成
    generate_write_resp_expected();
    
    $display("Payloads and Expected Values Generated:");
    $display("  Write Address - Basic: %0d, Stall: %0d", 
             write_addr_payloads.size(), write_addr_payloads_with_stall.size());
    $display("  Write Data - Basic: %0d, Stall: %0d", 
             write_data_payloads.size(), write_data_payloads_with_stall.size());
    $display("  Read Address - Basic: %0d, Stall: %0d", 
             read_addr_payloads.size(), read_addr_payloads_with_stall.size());
    $display("  Read Data Expected - %0d", read_data_expected.size());
    $display("  Write Response Expected - %0d", write_resp_expected.size());
    
    // 1単位時間待ってから完了フラグを設定
    #1;
    generate_stimulus_expected_done = 1'b1;
end
```

#### 2.3.3 Writeアドレスチャネルのテストデータ生成

Writeアドレスチャネルのペイロードデータを時間0で生成し、associated arrayに格納します。

```verilog
// Writeアドレスチャネルのペイロード構造体
typedef struct {
    int                         test_count; // テストカウント（配列インデックスと一致）
    logic [AXI_ADDR_WIDTH-1:0] addr;      // アドレス
    logic [1:0]                 burst;     // バーストタイプ
    logic [2:0]                 size;      // バーストサイズ
    logic [AXI_ID_WIDTH-1:0]    id;        // トランザクションID
    logic [7:0]                 len;       // バースト長
    logic                       valid;     // 有効信号
    int                         phase;     // フェーズ番号
} write_addr_payload_t;

// Writeアドレスチャネルのペイロード配列（ストールなし）
write_addr_payload_t write_addr_payloads[int];

// Writeアドレスチャネルのペイロード配列（ストールあり）
write_addr_payload_t write_addr_payloads_with_stall[int];

// 基本ペイロード生成関数
function automatic void generate_write_addr_payloads();
    int test_count = 0;  // テストカウント（アドレス1回で1インクリメント）
    
    // 各バースト設定に対してペイロードを生成
    foreach (burst_config_weights[i]) begin
        burst_config_t config = burst_config_weights[i];
        
        // 設定された重み分のペイロードを生成
        for (int weight_count = 0; weight_count < config.weight; weight_count++) begin
            // バースト長をランダムに選択（burst_config_weightsの使用例に従う）
            int selected_length = $urandom_range(config.length_min, config.length_max);
            string selected_type = config.burst_type;
            
            // フェーズを計算（テストカウント/PHASE_TEST_COUNT）
            int phase = test_count / PHASE_TEST_COUNT;
            
            // 1. まず、TEST_COUNT_ADDR_SIZE_BYTES/4の範囲で乱数を発生
            logic [AXI_ADDR_WIDTH-1:0] random_offset = $urandom_range(0, TEST_COUNT_ADDR_SIZE_BYTES / 4 - 1);
            
            // 2. これをアドレス境界に合わせる
            int burst_size_bytes = (selected_length + 1) * (AXI_DATA_WIDTH / 8);
            logic [AXI_ADDR_WIDTH-1:0] aligned_offset = align_address_to_boundary(random_offset, burst_size_bytes, selected_type);
            
            // 3. 最後にTEST_COUNT_ADDR_SIZE_BYTES*phaseを足す
            logic [AXI_ADDR_WIDTH-1:0] base_addr = aligned_offset + (phase * TEST_COUNT_ADDR_SIZE_BYTES);
            
            // ペイロードを生成
            write_addr_payloads[test_count] = '{
                test_count: test_count,
                addr: base_addr,
                burst: get_burst_type_value(selected_type),
                size: $clog2(AXI_DATA_WIDTH / 8),
                id: $urandom_range(0, (1 << AXI_ID_WIDTH) - 1),
                len: selected_length,
                valid: 1'b1,
                phase: phase
            };
            
            test_count++;  // テストカウントをインクリメント
        end
    end
    
endfunction

// ストール込みペイロード生成関数
function automatic void generate_write_addr_payloads_with_stall();
    int stall_index = 0;
    
    // 基本ペイロードをコピーし、ストールを挿入
    foreach (write_addr_payloads[i]) begin
        // ストールなしのペイロードをコピー
        write_addr_payloads_with_stall[stall_index] = write_addr_payloads[i];
        stall_index++;
        
        // ストールを挿入（重み付き乱数で決定）
        int[] stall_weights = extract_weights_generic(write_addr_bubble_weights, write_addr_bubble_weights.size());
        int stall_total = calculate_total_weight_generic(stall_weights);
        int stall_index_selected = generate_weighted_random_index(stall_weights, stall_total);
        
        int stall_cycles = $urandom_range(
            write_addr_bubble_weights[stall_index_selected].cyc_cnt_start,
            write_addr_bubble_weights[stall_index_selected].cyc_cnt_end
        );
        
        // ストールサイクル分のペイロードを挿入
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_addr_payloads_with_stall[stall_index] = '{
                test_count: -1,  // ストール時は無効なテストカウント
                addr: 0,
                burst: 2'b00,
                size: 0,
                id: 0,
                len: 0,
                valid: 1'b0,
                phase: -1  // ストール時は無効なフェーズ番号
            };
            stall_index++;
        end
    end
endfunction

#### 2.3.4 Readアドレスチャネルのテストデータ生成

Readアドレスチャネルのペイロードデータを時間0で生成し、associated arrayに格納します。Write用の配列から必要な信号の値をコピーして作成します。

```verilog
// Readアドレスチャネルのペイロード構造体
typedef struct {
    int                         test_count; // テストカウント（配列インデックスと一致）
    logic [AXI_ADDR_WIDTH-1:0] addr;      // アドレス
    logic [1:0]                 burst;     // バーストタイプ
    logic [2:0]                 size;      // バーストサイズ
    logic [AXI_ID_WIDTH-1:0]    id;        // トランザクションID
    logic [7:0]                 len;       // バースト長
    logic                       valid;     // 有効信号
    int                         phase;     // フェーズ番号
} read_addr_payload_t;

// Readアドレスチャネルのペイロード配列（ストールなし）
read_addr_payload_t read_addr_payloads[int];

// Readアドレスチャネルのペイロード配列（ストールあり）
read_addr_payload_t read_addr_payloads_with_stall[int];

// Readアドレスチャネルのペイロード生成関数
function automatic void generate_read_addr_payloads();
    int test_count = 0;  // テストカウント（アドレス1回で1インクリメント）
    
    // Writeアドレスチャネルの配列から必要な信号の値をコピー
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t write_payload = write_addr_payloads[i];
        
        // ペイロードを生成（Write用からコピー）
        read_addr_payloads[test_count] = '{
            test_count: write_payload.test_count,
            addr: write_payload.addr,
            burst: write_payload.burst,
            size: write_payload.size,
            id: write_payload.id,
            len: write_payload.len,
            valid: write_payload.valid,
            phase: write_payload.phase
        };
        
        test_count++;
    end
endfunction

// Readアドレスチャネルのストール込みペイロード生成関数
function automatic void generate_read_addr_payloads_with_stall();
    int stall_index = 0;
    
    // 基本ペイロードをコピーし、ストールを挿入
    foreach (read_addr_payloads[i]) begin
        // ストールなしのペイロードをコピー
        read_addr_payloads_with_stall[stall_index] = read_addr_payloads[i];
        stall_index++;
        
        // ストールを挿入（重み付き乱数で決定）
        int[] stall_weights = extract_weights_generic(read_addr_bubble_weights, read_addr_bubble_weights.size());
        int stall_total = calculate_total_weight_generic(stall_weights);
        int stall_index_selected = generate_weighted_random_index(stall_weights, stall_total);
        
        int stall_cycles = $urandom_range(
            read_addr_bubble_weights[stall_index_selected].cyc_cnt_start,
            read_addr_bubble_weights[stall_index_selected].cyc_cnt_end
        );
        
        // ストールサイクル分のペイロードを挿入
        for (int stall = 0; stall < stall_cycles; stall++) begin
            read_addr_payloads_with_stall[stall_index] = '{
                test_count: -1,  // ストール時は無効なテストカウント
                addr: 0,
                burst: 2'b00,
                size: 0,
                id: 0,
                len: 0,
                valid: 1'b0,
                phase: -1  // ストール時は無効なフェーズ番号
            };
            stall_index++;
        end
    end
endfunction

// バーストタイプの値を取得する関数
function automatic logic [1:0] get_burst_type_value(string burst_type);
    case (burst_type)
        "FIXED": return 2'b00;
        "INCR":  return 2'b01;
        "WRAP":  return 2'b10;
        default: return 2'b01; // デフォルトはINCR
    endcase
endfunction

// アドレスを境界に合わせる関数
function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_to_boundary(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input int burst_size_bytes,
    input string burst_type
);
    logic [AXI_ADDR_WIDTH-1:0] aligned_addr = address;
    
    case (burst_type)
        "WRAP": begin
            // WRAP転送の場合：バーストサイズの倍数に調整
            int wrap_boundary = burst_size_bytes;
            aligned_addr = (address / wrap_boundary) * wrap_boundary;
        end
        "INCR", "FIXED": begin
            // INCR/FIXED転送の場合：バス幅のサイズで最下位を0固定
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            aligned_addr = (address / bus_width_bytes) * bus_width_bytes;
        end
        default: begin
            // デフォルト：バス幅のサイズで最下位を0固定
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            aligned_addr = (address / bus_width_bytes) * bus_width_bytes;
        end
    endcase
    
    return aligned_addr;
endfunction

// FIXED転送用のSTROBEパターン生成関数
function automatic logic [AXI_STRB_WIDTH-1:0] generate_fixed_strobe_pattern(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int data_width
);
    logic [AXI_STRB_WIDTH-1:0] strobe_pattern = 0;
    int bus_width_bytes = data_width / 8;
    int burst_size_bytes = (1 << size);
    
    // アドレスの下位ビットからバーストサイズ分のSTROBEを有効化
    // アドレスの下位ビットがバーストサイズの境界に合わせて調整される
    int addr_offset = address % bus_width_bytes;  // バス幅内でのオフセット（バイト単位）
    int strobe_start = addr_offset;               // STROBE開始位置（バイト単位）
    int strobe_end = strobe_start + burst_size_bytes - 1;  // STROBE終了位置（バイト単位）
    
    // アドレスとサイズの整合性チェック
    if (strobe_end >= bus_width_bytes) begin
        $error("FIXED transfer error: Address 0x%h with size %0d exceeds bus width %0d bytes. strobe_end=%0d", 
               address, burst_size_bytes, bus_width_bytes, strobe_end);
        $finish;
    end
    
    // STROBEパターンを生成（バイト単位）
    for (int byte = strobe_start; byte <= strobe_end; byte++) begin
        strobe_pattern[byte] = 1'b1;
    end
    
    return strobe_pattern;
endfunction
```

#### 2.3.5 Writeデータチャネルのテストデータ生成

Writeデータチャネルのペイロードデータを時間0で生成し、associated arrayに格納します。Writeアドレスチャネルのペイロードと連携して、適切なデータとストローブを生成します。

```verilog
// Writeデータチャネルのペイロード構造体
typedef struct {
    int                         test_count; // テストカウント（配列インデックスと一致）
    logic [AXI_DATA_WIDTH-1:0] data;       // データ
    logic [AXI_STRB_WIDTH-1:0] strb;       // ストローブ
    logic                       last;       // 最後の転送フラグ
    logic                       valid;      // 有効信号
    int                         phase;      // フェーズ番号
} write_data_payload_t;

// Writeデータチャネルのペイロード配列（ストールなし）
write_data_payload_t write_data_payloads[int];

// Writeデータチャネルのペイロード配列（ストールあり）
write_data_payload_t write_data_payloads_with_stall[int];

// Writeデータチャネルのペイロード生成関数
function automatic void generate_write_data_payloads();
    int test_count = 0;  // テストカウント（アドレス1回で1インクリメント）
    
    // Writeアドレスチャネルの配列からデータペイロードを生成
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t addr_payload = write_addr_payloads[i];
        
        // バースト長に応じてデータペイロードを生成
        int burst_length = addr_payload.len + 1;
        
        for (int burst_idx = 0; burst_idx < burst_length; burst_idx++) begin
            // データを生成（ランダム値）
            logic [AXI_DATA_WIDTH-1:0] random_data = $urandom();
            
            // ストローブを生成（バースト長とバーストタイプに応じて）
            logic [AXI_STRB_WIDTH-1:0] strobe_pattern;
            if (addr_payload.burst == 2'b00) begin // FIXED
                // FIXED転送：アドレスとSIZEに基づいてSTROBEの位置を決定
                strobe_pattern = generate_fixed_strobe_pattern(
                    addr_payload.addr, 
                    addr_payload.size, 
                    AXI_DATA_WIDTH
                );
            end else begin // INCR, WRAP
                // INCR/WRAP転送：全てのストローブを有効
                strobe_pattern = {AXI_STRB_WIDTH{1'b1}};
            end
            
            // データをSTROBEでマスク（使用していないビットを0に）
            // STROBEはバイト単位なので、各バイトの8ビットに拡張してマスク
            logic [AXI_DATA_WIDTH-1:0] strobe_mask = 0;
            for (int byte = 0; byte < AXI_STRB_WIDTH; byte++) begin
                if (strobe_pattern[byte]) begin
                    // 該当バイトの8ビットを1に設定
                    strobe_mask[byte*8 +: 8] = 8'hFF;
                end
            end
            logic [AXI_DATA_WIDTH-1:0] masked_data = random_data & strobe_mask;
            
            // 最後の転送フラグを設定
            logic is_last = (burst_idx == burst_length - 1);
            
            // ペイロードを生成
            write_data_payloads[test_count] = '{
                test_count: addr_payload.test_count,
                data: masked_data,
                strb: strobe_pattern,
                last: is_last,
                valid: 1'b1,
                phase: addr_payload.phase
            };
            
            test_count++;
        end
    end
endfunction

// Writeデータチャネルのストール込みペイロード生成関数
function automatic void generate_write_data_payloads_with_stall();
    int stall_index = 0;
    
    // 基本ペイロードをコピーし、ストールを挿入
    foreach (write_data_payloads[i]) begin
        // ストールなしのペイロードをコピー
        write_data_payloads_with_stall[stall_index] = write_data_payloads[i];
        stall_index++;
        
        // ストールを挿入（重み付き乱数で決定）
        int[] stall_weights = extract_weights_generic(write_data_bubble_weights, write_data_bubble_weights.size());
        int stall_total = calculate_total_weight_generic(stall_weights);
        int stall_index_selected = generate_weighted_random_index(stall_weights, stall_total);
        
        int stall_cycles = $urandom_range(
            write_data_bubble_weights[stall_index_selected].cyc_cnt_start,
            write_data_bubble_weights[stall_index_selected].cyc_cnt_end
        );
        
        // ストールサイクル分のペイロードを挿入
        for (int stall = 0; stall < stall_cycles; stall++) begin
            write_data_payloads_with_stall[stall_index] = '{
                test_count: -1,  // ストール時は無効なテストカウント
                data: 0,
                strb: 0,
                last: 1'b0,
                valid: 1'b0,
                phase: -1  // ストール時は無効なフェーズ番号
            };
            stall_index++;
        end
    end
endfunction


#### 2.3.6 Writeアドレスチャネルの制御回路

```verilog
// Writeアドレスチャネルの制御信号
logic write_addr_phase_done = 1'b0;
logic write_addr_phase_busy = 1'b0;

// Writeアドレスチャネルの出力信号
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr;
logic [1:0]                axi_aw_burst;
logic [2:0]                axi_aw_size;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id;
logic [7:0]                axi_aw_len;
logic                      axi_aw_valid;

// Writeアドレスチャネルの制御状態
typedef enum logic [1:0] {
    WRITE_ADDR_IDLE,        // 待機状態
    WRITE_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_ADDR_FINISH       // 終了処理状態
} write_addr_state_t;

write_addr_state_t write_addr_state = WRITE_ADDR_IDLE;

// Writeアドレスチャネルの制御用変数
int write_addr_phase_counter = 0;     // 制御用：Phase内のアドレスカウント
int write_addr_payload_index = 0;     // 制御用：ペイロード配列のインデックス

// Writeアドレスチャネルのレポート用変数
int report_write_addr_stall_cycles = 0;  // レポート用：累積ストールサイクル数

// Writeアドレスチャネルのデバッグ用変数
int debug_write_addr_current_test_count = 0;  // デバッグ用：現在のテストカウント

// Writeアドレスチャネルの制御回路
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は停止、初期値0
        write_addr_state <= WRITE_ADDR_IDLE;
        write_addr_phase_done <= 1'b0;
        write_addr_phase_busy <= 1'b0;
        write_addr_test_counter <= 0;
        write_addr_payload_index <= 0;
        report_write_addr_stall_cycles <= 0;
        debug_write_addr_current_test_count <= 0;
        
        // 出力信号を初期化
        axi_aw_addr <= 0;
        axi_aw_burst <= 0;
        axi_aw_size <= 0;
        axi_aw_id <= 0;
        axi_aw_len <= 0;
        axi_aw_valid <= 1'b0;
        
    end else begin
        case (write_addr_state)
            WRITE_ADDR_IDLE: begin
                // 待機状態：phase_startが1になるまで待機
                // phase_doneを0にリセット
                write_addr_phase_done <= 1'b0;
                
                if (write_addr_phase_start) begin
                    write_addr_state <= WRITE_ADDR_ACTIVE;
                    write_addr_phase_busy <= 1'b1;
                    write_addr_payload_index <= 0;
                    write_addr_phase_counter <= 0;
                end
            end
            
            WRITE_ADDR_ACTIVE: begin
                // アクティブ状態：ペイロードを順次出力
                if (write_addr_payload_index < write_addr_payloads_with_stall.size()) begin
                    write_addr_payload_t payload = write_addr_payloads_with_stall[write_addr_payload_index];
                    
                    // Readyがアサートされている場合のみペイロードを出力・更新
                    if (axi_aw_ready) begin
                        // ペイロードを出力
                        axi_aw_addr <= payload.addr;
                        axi_aw_burst <= payload.burst;
                        axi_aw_size <= payload.size;
                        axi_aw_id <= payload.id;
                        axi_aw_len <= payload.len;
                        axi_aw_valid <= payload.valid;
                        
                        // デバッグ用：テストカウントを読み出し
                        debug_write_addr_current_test_count = payload.test_count;
                        
                        // 次のペイロードへ
                        write_addr_payload_index <= write_addr_payload_index + 1;
                        
                        // 有効なペイロードの場合のみカウンタをインクリメント
                        if (payload.valid) begin
                            write_addr_phase_counter <= write_addr_phase_counter + 1;
                        end
                    end else begin
                        // Readyがネゲートされている場合は現在のペイロードを保持
                        // ストールカウンタをインクリメント
                        report_write_addr_stall_cycles <= report_write_addr_stall_cycles + 1;
                    end
                end else begin
                    // 配列の最後に到達：終了処理ステートに移行
                    write_addr_state <= WRITE_ADDR_FINISH;
                    write_addr_phase_done <= 1'b1;
                    
                    // 出力信号をクリア
                    axi_aw_valid <= 1'b0;
                end
            end
            
            WRITE_ADDR_FINISH: begin
                // 終了処理状態：phase_doneをネゲートしてからIDLEに移行
                write_addr_phase_done <= 1'b0;
                write_addr_phase_busy <= 1'b0;
                write_addr_state <= WRITE_ADDR_IDLE;
            end
        endcase
    end
end

// フェーズ完了の検出と次のフェーズの開始
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は何もしない
    end else begin
        // フェーズ完了を検出したら、次のフェーズの準備
        if (write_addr_phase_done) begin
            write_addr_phase_done <= 1'b0;
            
            // PHASE_TEST_COUNT回数実行したかチェック
            if (write_addr_phase_counter >= PHASE_TEST_COUNT) begin
                // フェーズ完了：次のフェーズ待ち
                $display("Write Address Phase Counter %0d completed. Total transfers: %0d", 
                         write_addr_phase_counter, write_addr_phase_counter);
            end else begin
                // フェーズ途中：次のフェーズを開始
                $display("Write Address Phase Counter %0d started. Target: %0d", 
                         write_addr_phase_counter + 1, PHASE_TEST_COUNT);
            end
        end
    end
end

// デバッグ用の監視信号
always @(posedge clk) begin
    if (axi_aw_valid && axi_aw_ready) begin
        // 現在のペイロードの情報を取得
        write_addr_payload_t current_payload = write_addr_payloads_with_stall[write_addr_payload_index];
        $display("Write Address Transfer: TestCount=%0d, Addr=0x%h, Burst=%b, Size=%0d, ID=%0d, Len=%0d, Phase=%0d", 
                 current_payload.test_count, axi_aw_addr, axi_aw_burst, axi_aw_size, axi_aw_id, axi_aw_len, current_payload.phase);
    end
end
```

#### 2.3.7 Readアドレスチャネルの制御回路

Readアドレスチャネルの制御回路を実装します。Writeアドレスチャネルと同様の構造で、DUTにスティミュラスを与える制御を行います。

```verilog
// Readアドレスチャネルの制御信号
logic read_addr_phase_done = 1'b0;
logic read_addr_phase_busy = 1'b0;

// Readアドレスチャネルの出力信号
logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr;
logic [1:0]                axi_ar_burst;
logic [2:0]                axi_ar_size;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id;
logic [7:0]                axi_ar_len;
logic                      axi_ar_valid;

// Readアドレスチャネルの制御状態
typedef enum logic [1:0] {
    READ_ADDR_IDLE,        // 待機状態
    READ_ADDR_ACTIVE,      // アクティブ状態（ストール処理も含む）
    READ_ADDR_FINISH       // 終了処理状態
} read_addr_state_t;

read_addr_state_t read_addr_state = READ_ADDR_IDLE;

// Readアドレスチャネルの制御用変数
int read_addr_phase_counter = 0;     // 制御用：Phase内のアドレスカウント
int read_addr_payload_index = 0;     // 制御用：ペイロード配列のインデックス

// Readアドレスチャネルのレポート用変数
int report_read_addr_stall_cycles = 0;  // レポート用：累積ストールサイクル数

// Readアドレスチャネルのデバッグ用変数
int debug_read_addr_current_test_count = 0;  // デバッグ用：現在のテストカウント

// Readアドレスチャネルの制御回路
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は停止、初期値0
        read_addr_state <= READ_ADDR_IDLE;
        read_addr_phase_done <= 1'b0;
        read_addr_phase_busy <= 1'b0;
        read_addr_phase_counter <= 0;
        read_addr_payload_index <= 0;
        report_read_addr_stall_cycles <= 0;
        debug_read_addr_current_test_count <= 0;
        
        // 出力信号を初期化
        axi_ar_addr <= 0;
        axi_ar_burst <= 0;
        axi_ar_size <= 0;
        axi_ar_id <= 0;
        axi_ar_len <= 0;
        axi_ar_valid <= 1'b0;
        
    end else begin
        case (read_addr_state)
            READ_ADDR_IDLE: begin
                // 待機状態：phase_startが1になるまで待機
                // phase_doneを0にリセット
                read_addr_phase_done <= 1'b0;
                
                if (read_addr_phase_start) begin
                    read_addr_state <= READ_ADDR_ACTIVE;
                    read_addr_phase_busy <= 1'b1;
                    read_addr_payload_index <= 0;
                    read_addr_phase_counter <= 0;
                end
            end
            
            READ_ADDR_ACTIVE: begin
                // アクティブ状態：ペイロードを順次出力
                if (read_addr_payload_index < read_addr_payloads_with_stall.size()) begin
                    read_addr_payload_t payload = read_addr_payloads_with_stall[read_addr_payload_index];
                    
                    // Readyがアサートされている場合のみペイロードを出力・更新
                    if (axi_ar_ready) begin
                        // ペイロードを出力
                        axi_ar_addr <= payload.addr;
                        axi_ar_burst <= payload.burst;
                        axi_ar_size <= payload.size;
                        axi_ar_id <= payload.id;
                        axi_ar_len <= payload.len;
                        axi_ar_valid <= payload.valid;
                        
                        // デバッグ用：テストカウントを読み出し
                        debug_read_addr_current_test_count = payload.test_count;
                        
                        // 次のペイロードへ
                        read_addr_payload_index <= read_addr_payload_index + 1;
                        
                        // 有効なペイロードの場合のみカウンタをインクリメント
                        if (payload.valid) begin
                            read_addr_phase_counter <= read_addr_phase_counter + 1;
                        end
                    end else begin
                        // Readyがネゲートされている場合は現在のペイロードを保持
                        // ストールカウンタをインクリメント
                        report_read_addr_stall_cycles <= report_read_addr_stall_cycles + 1;
                    end
                end else begin
                    // 配列の最後に到達：終了処理ステートに移行
                    read_addr_state <= READ_ADDR_FINISH;
                    read_addr_phase_done <= 1'b1;
                    
                    // 出力信号をクリア
                    axi_ar_valid <= 1'b0;
                end
            end
            
            READ_ADDR_FINISH: begin
                // 終了処理状態：phase_doneをネゲートしてからIDLEに移行
                read_addr_phase_done <= 1'b0;
                read_addr_phase_busy <= 1'b0;
                read_addr_state <= READ_ADDR_IDLE;
            end
        endcase
    end
end

// フェーズ完了の検出と次のフェーズの開始
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は何もしない
    end else begin
        // フェーズ完了を検出したら、次のフェーズの準備
        if (read_addr_phase_done) begin
            read_addr_phase_done <= 1'b0;
            
            // PHASE_TEST_COUNT回数実行したかチェック
            if (read_addr_phase_counter >= PHASE_TEST_COUNT) begin
                // フェーズ完了：次のフェーズ待ち
                $display("Read Address Phase Counter %0d completed. Total transfers: %0d", 
                         read_addr_phase_counter, read_addr_phase_counter);
            end else begin
                // フェーズ途中：次のフェーズを開始
                $display("Read Address Phase Counter %0d started. Target: %0d", 
                         read_addr_phase_counter + 1, PHASE_TEST_COUNT);
            end
        end
    end
end

// デバッグ用の監視信号
always @(posedge clk) begin
    if (axi_ar_valid && axi_ar_ready) begin
        // 現在のペイロードの情報を取得
        read_addr_payload_t current_payload = read_addr_payloads_with_stall[read_addr_payload_index];
        $display("Read Address Transfer: TestCount=%0d, Addr=0x%h, Burst=%b, Size=%0d, ID=%0d, Len=%0d, Phase=%0d", 
                 current_payload.test_count, axi_ar_addr, axi_ar_burst, axi_ar_size, axi_ar_id, axi_ar_len, current_payload.phase);
    end
end

#### 2.3.8 Writeデータチャネルの制御回路

Writeデータチャネルの制御回路を実装します。Writeアドレスチャネルと連携して、適切なタイミングでデータとストローブを出力します。

```verilog
// Writeデータチャネルの制御信号
logic write_data_phase_done = 1'b0;
logic write_data_phase_busy = 1'b0;

// Writeデータチャネルの出力信号
logic [AXI_DATA_WIDTH-1:0] axi_w_data;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb;
logic                       axi_w_last;
logic                       axi_w_valid;

// Writeデータチャネルの制御状態
typedef enum logic [1:0] {
    WRITE_DATA_IDLE,        // 待機状態
    WRITE_DATA_ACTIVE,      // アクティブ状態（ストール処理も含む）
    WRITE_DATA_FINISH       // 終了処理状態
} write_data_state_t;

write_data_state_t write_data_state = WRITE_DATA_IDLE;

// Writeデータチャネルの制御用変数
int write_data_phase_counter = 0;     // 制御用：Phase内のデータカウント
int write_data_payload_index = 0;     // 制御用：ペイロード配列のインデックス

// Writeデータチャネルのレポート用変数
int report_write_data_stall_cycles = 0;  // レポート用：累積ストールサイクル数

// Writeデータチャネルのデバッグ用変数
int debug_write_data_current_test_count = 0;  // デバッグ用：現在のテストカウント

// Writeデータチャネルの制御回路
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は停止、初期値0
        write_data_state <= WRITE_DATA_IDLE;
        write_data_phase_done <= 1'b0;
        write_data_phase_busy <= 1'b0;
        write_data_phase_counter <= 0;
        write_data_payload_index <= 0;
        report_write_data_stall_cycles <= 0;
        debug_write_data_current_test_count <= 0;
        
        // 出力信号を初期化
        axi_w_data <= 0;
        axi_w_strb <= 0;
        axi_w_last <= 1'b0;
        axi_w_valid <= 1'b0;
        
    end else begin
        case (write_data_state)
            WRITE_DATA_IDLE: begin
                // 待機状態：phase_startが1になるまで待機
                // phase_doneを0にリセット
                write_data_phase_done <= 1'b0;
                
                if (write_data_phase_start) begin
                    write_data_state <= WRITE_DATA_ACTIVE;
                    write_data_phase_busy <= 1'b1;
                    write_data_payload_index <= 0;
                    write_data_phase_counter <= 0;
                end
            end
            
            WRITE_DATA_ACTIVE: begin
                // アクティブ状態：ペイロードを順次出力
                if (write_data_payload_index < write_data_payloads_with_stall.size()) begin
                    write_data_payload_t payload = write_data_payloads_with_stall[write_data_payload_index];
                    
                    // Readyがアサートされている場合のみペイロードを出力・更新
                    if (axi_w_ready) begin
                        // ペイロードを出力
                        axi_w_data <= payload.data;
                        axi_w_strb <= payload.strb;
                        axi_w_last <= payload.last;
                        axi_w_valid <= payload.valid;
                        
                        // デバッグ用：テストカウントを読み出し
                        debug_write_data_current_test_count = payload.test_count;
                        
                        // 次のペイロードへ
                        write_data_payload_index <= write_data_payload_index + 1;
                        
                        // 有効なペイロードの場合のみカウンタをインクリメント
                        if (payload.valid) begin
                            write_data_phase_counter <= write_data_phase_counter + 1;
                        end
                    end else begin
                        // Readyがネゲートされている場合は現在のペイロードを保持
                        // ストールカウンタをインクリメント
                        report_write_data_stall_cycles <= report_write_data_stall_cycles + 1;
                    end
                end else begin
                    // 配列の最後に到達：終了処理ステートに移行
                    write_data_state <= WRITE_DATA_FINISH;
                    write_data_phase_done <= 1'b1;
                    
                    // 出力信号をクリア
                    axi_w_valid <= 1'b0;
                end
            end
            
            WRITE_DATA_FINISH: begin
                // 終了処理状態：phase_doneをネゲートしてからIDLEに移行
                write_data_phase_done <= 1'b0;
                write_data_phase_busy <= 1'b0;
                write_data_state <= WRITE_DATA_IDLE;
            end
        endcase
    end
end

// フェーズ完了の検出と次のフェーズの開始
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は何もしない
    end else begin
        // フェーズ完了を検出したら、次のフェーズの準備
        if (write_data_phase_done) begin
            write_data_phase_done <= 1'b0;
            
            // PHASE_TEST_COUNT回数実行したかチェック
            if (write_data_phase_counter >= PHASE_TEST_COUNT) begin
                // フェーズ完了：次のフェーズ待ち
                $display("Write Data Phase Counter %0d completed. Total transfers: %0d", 
                         write_data_phase_counter, write_data_phase_counter);
            end else begin
                // フェーズ途中：次のフェーズを開始
                $display("Write Data Phase Counter %0d started. Target: %0d", 
                         write_data_phase_counter + 1, PHASE_TEST_COUNT);
            end
        end
    end
end

// デバッグ用の監視信号
always @(posedge clk) begin
    if (axi_w_valid && axi_w_ready) begin
        // 現在のペイロードの情報を取得
        write_data_payload_t current_payload = write_data_payloads_with_stall[write_data_payload_index];
        $display("Write Data Transfer: TestCount=%0d, Data=0x%h, Strb=%b, Last=%b, Phase=%0d", 
                 current_payload.test_count, axi_w_data, axi_w_strb, axi_w_last, current_payload.phase);
    end
end
```

#### 2.3.9 Readデータチャネルの期待値生成

Readデータチャネルの期待値を生成し、associated arrayに格納します。Writeデータチャネルのペイロードと連携して、適切な期待値を生成します。

```verilog
// Readデータチャネルの期待値構造体
typedef struct {
    int                         test_count; // テストカウント（配列インデックスと一致）
    logic [AXI_DATA_WIDTH-1:0] expected_data; // 期待値データ
    int                         phase;      // フェーズ番号
} read_data_expected_t;

// Readデータチャネルの期待値配列
read_data_expected_t read_data_expected[int];

// Readデータチャネルの期待値生成関数
function automatic void generate_read_data_expected();
    int test_count = 0;  // テストカウント（アドレス1回で1インクリメント）
    
    // Writeデータチャネルのペイロード配列から期待値を生成
    // write_data_payloadsには既にSTROBEでマスク済みのデータが格納されている
    foreach (write_data_payloads[i]) begin
        write_data_payload_t write_payload = write_data_payloads[i];
        
        if (write_payload.valid) begin
            // 有効なWriteペイロードの場合、対応するRead期待値を生成
            // Writeデータ（STROBEマスク済み）がそのままRead期待値になる
            read_data_expected[test_count] = '{
                test_count: write_payload.test_count,
                expected_data: write_payload.data,  // 既にマスク済みのデータ
                phase: write_payload.phase
            };
            
            test_count++;
        end
    end
    
    $display("Read Data Expected Values Generated: %0d", test_count);
endfunction

#### 2.3.10 Writeレスポンスチャネルの期待値生成

Writeレスポンスチャネルの期待値を生成し、associated arrayに格納します。Writeアドレスチャネルのペイロードと連携して、適切なレスポンス期待値を生成します。

```verilog
// Writeレスポンスチャネルの期待値構造体
typedef struct {
    int                         test_count; // テストカウント（配列インデックスと一致）
    logic [1:0]                expected_resp; // 期待値レスポンス（OKAY）
    logic [AXI_ID_WIDTH-1:0]   expected_id;   // 期待値ID
    int                         phase;         // フェーズ番号
} write_resp_expected_t;

// Writeレスポンスチャネルの期待値配列
write_resp_expected_t write_resp_expected[int];

// Writeレスポンスチャネルの期待値生成関数
function automatic void generate_write_resp_expected();
    int test_count = 0;  // テストカウント（アドレス1回で1インクリメント）
    
    // Writeアドレスチャネルのペイロード配列から期待値を生成
    foreach (write_addr_payloads[i]) begin
        write_addr_payload_t addr_payload = write_addr_payloads[i];
        
        if (addr_payload.valid) begin
            // 有効なWriteアドレスペイロードの場合、対応するレスポンス期待値を生成
            // 正常なWrite転送の場合、レスポンスは常にOKAY（2'b00）
            
            write_resp_expected[test_count] = '{
                test_count: addr_payload.test_count,
                expected_resp: 2'b00,  // 常にOKAY
                expected_id: addr_payload.id,  // Writeアドレスと同じID
                phase: addr_payload.phase
            };
            
            test_count++;
        end
    end
    
    $display("Write Response Expected Values Generated: %0d", test_count);
endfunction

#### 2.3.11 Readデータチャネルの制御回路

Readデータチャネルの制御回路を実装します。Readアドレスチャネルと連携して、適切なタイミングでデータを受信し、期待値と比較します。

```verilog
// Readデータチャネルの制御信号
logic read_data_phase_done = 1'b0;
logic read_data_phase_busy = 1'b0;

// Readデータチャネルの入力信号
logic [AXI_DATA_WIDTH-1:0] axi_r_data;
logic [1:0]                axi_r_resp;
logic                       axi_r_last;
logic                       axi_r_valid;
logic                       axi_r_ready;

// Readデータチャネルの制御状態
typedef enum logic [1:0] {
    READ_DATA_IDLE,        // 待機状態
    READ_DATA_ACTIVE,      // アクティブ状態（ストール処理も含む）
    READ_DATA_FINISH       // 終了処理状態
} read_data_state_t;

read_data_state_t read_data_state = READ_DATA_IDLE;

// Readデータチャネルの制御用変数
int read_data_phase_counter = 0;     // 制御用：Phase内のデータカウント
int read_data_payload_index = 0;     // 制御用：ペイロード配列のインデックス

// Readデータチャネルのレポート用変数
int report_read_data_stall_cycles = 0;  // レポート用：累積ストールサイクル数

// Readデータチャネルのデバッグ用変数
int debug_read_data_current_test_count = 0;  // デバッグ用：現在のテストカウント

// Readデータチャネルの制御回路
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は停止、初期値0
        read_data_state <= READ_DATA_IDLE;
        read_data_phase_done <= 1'b0;
        read_data_phase_busy <= 1'b0;
        read_data_phase_counter <= 0;
        read_data_payload_index <= 0;
        report_read_data_stall_cycles <= 0;
        debug_read_data_current_test_count <= 0;
        
        // 出力信号を初期化
        axi_r_ready <= 1'b0;
        
    end else begin
        case (read_data_state)
            READ_DATA_IDLE: begin
                // 待機状態：phase_startが1になるまで待機
                // phase_doneを0にリセット
                read_data_phase_done <= 1'b0;
                
                if (read_data_phase_start) begin
                    read_data_state <= READ_DATA_ACTIVE;
                    read_data_phase_busy <= 1'b1;
                    read_data_payload_index <= 0;
                    read_data_phase_counter <= 0;
                    axi_r_ready <= 1'b1;  // Readデータ受信準備完了
                end
            end
            
            READ_DATA_ACTIVE: begin
                // アクティブ状態：データを受信して期待値と比較
                if (axi_r_valid && axi_r_ready) begin
                    // データを受信、期待値と比較
                    read_data_expected_t expected = read_data_expected[read_data_payload_index];
                    
                    // デバッグ用：テストカウントを読み出し
                    debug_read_data_current_test_count = expected.test_count;
                    
                    // データの比較と検証
                    if (axi_r_data !== expected.expected_data) begin
                        $error("Read Data Mismatch: TestCount=%0d, Expected=0x%h, Actual=0x%h, Phase=%0d", 
                               expected.test_count, expected.expected_data, axi_r_data, expected.phase);
                    end else begin
                        $display("Read Data Match: TestCount=%0d, Data=0x%h, Phase=%0d", 
                                expected.test_count, axi_r_data, expected.phase);
                    end
                    
                    // 次のペイロードへ
                    read_data_payload_index <= read_data_payload_index + 1;
                    
                    // 有効なデータの場合のみカウンタをインクリメント
                    if (expected.test_count >= 0) begin
                        read_data_phase_counter <= read_data_phase_counter + 1;
                    end
                    
                    // 配列の最後に到達したかチェック
                    if (read_data_payload_index >= read_data_expected.size() - 1) begin
                        read_data_state <= READ_DATA_FINISH;
                        read_data_phase_done <= 1'b1;
                        axi_r_ready <= 1'b0;
                    end
                end else if (!axi_r_ready) begin
                    // Readyがネゲートされている場合はストールカウンタをインクリメント
                    report_read_data_stall_cycles <= report_read_data_stall_cycles + 1;
                end
            end
            
            READ_DATA_FINISH: begin
                // 終了処理状態：phase_doneをネゲートしてからIDLEに移行
                read_data_phase_done <= 1'b0;
                read_data_phase_busy <= 1'b0;
                read_data_state <= READ_DATA_IDLE;
            end
        endcase
    end
end

// フェーズ完了の検出と次のフェーズの開始
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は何もしない
    end else begin
        // フェーズ完了を検出したら、次のフェーズの準備
        if (read_data_phase_done) begin
            read_data_phase_done <= 1'b0;
            
            // PHASE_TEST_COUNT回数実行したかチェック
            if (read_data_phase_counter >= PHASE_TEST_COUNT) begin
                // フェーズ完了：次のフェーズ待ち
                $display("Read Data Phase Counter %0d completed. Total transfers: %0d", 
                         read_data_phase_counter, read_data_phase_counter);
            end else begin
                // フェーズ途中：次のフェーズを開始
                $display("Read Data Phase Counter %0d started. Target: %0d", 
                         read_data_phase_counter + 1, PHASE_TEST_COUNT);
            end
        end
    end
end

// デバッグ用の監視信号
always @(posedge clk) begin
    if (axi_r_valid && axi_r_ready) begin
        // 現在の期待値の情報を取得
        read_data_expected_t current_expected = read_data_expected[read_data_payload_index];
        $display("Read Data Transfer: TestCount=%0d, Data=0x%h, Resp=%b, Last=%b, Phase=%0d", 
                 current_expected.test_count, axi_r_data, axi_r_resp, axi_r_last, current_expected.phase);
    end
end
```

### 2.4 プロトコル検証系

プロトコル検証系では、AXI4仕様の準拠性を確認し、Ready/Validハンドシェイクの動作を検証します。

#### 2.4.1 Readyネゲート時のペイロードホールド確認

Ready信号がネゲートされた時に、ペイロード（データ信号とValid信号を含む）が適切にホールドされているかを各チャネル毎に確認します。監視はリセット解除後から開始されます。

```verilog
// プロトコル検証用の遅延信号
logic [AXI_ADDR_WIDTH-1:0] axi_aw_addr_delayed;
logic [1:0]                axi_aw_burst_delayed;
logic [2:0]                axi_aw_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_aw_id_delayed;
logic [7:0]                axi_aw_len_delayed;
logic                      axi_aw_valid_delayed;

logic [AXI_ADDR_WIDTH-1:0] axi_ar_addr_delayed;
logic [1:0]                axi_ar_burst_delayed;
logic [2:0]                axi_ar_size_delayed;
logic [AXI_ID_WIDTH-1:0]   axi_ar_id_delayed;
logic [7:0]                axi_ar_len_delayed;
logic                      axi_ar_valid_delayed;

logic [AXI_DATA_WIDTH-1:0] axi_w_data_delayed;
logic [AXI_STRB_WIDTH-1:0] axi_w_strb_delayed;
logic                       axi_w_last_delayed;
logic                       axi_w_valid_delayed;

logic                       axi_r_ready_delayed;
logic                       axi_w_ready_delayed;

// 1クロック遅延回路
always_ff @(posedge clk) begin
    // Writeアドレスチャネル
    axi_aw_addr_delayed <= axi_aw_addr;
    axi_aw_burst_delayed <= axi_aw_burst;
    axi_aw_size_delayed <= axi_aw_size;
    axi_aw_id_delayed <= axi_aw_id;
    axi_aw_len_delayed <= axi_aw_len;
    axi_aw_valid_delayed <= axi_aw_valid;
    
    // Readアドレスチャネル
    axi_ar_addr_delayed <= axi_ar_addr;
    axi_ar_burst_delayed <= axi_ar_burst;
    axi_ar_size_delayed <= axi_ar_size;
    axi_ar_id_delayed <= axi_ar_id;
    axi_ar_len_delayed <= axi_ar_len;
    axi_ar_valid_delayed <= axi_ar_valid;
    
    // Writeデータチャネル
    axi_w_data_delayed <= axi_w_data;
    axi_w_strb_delayed <= axi_w_strb;
    axi_w_last_delayed <= axi_w_last;
    axi_w_valid_delayed <= axi_w_valid;
    
    // Ready信号
    axi_r_ready_delayed <= axi_r_ready;
    axi_w_ready_delayed <= axi_w_ready;
end

// Writeアドレスチャネルのペイロードホールド確認（リセット解除後に監視開始）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は監視しない
    end else begin
        if (!axi_aw_ready_delayed) begin
            // Readyがネゲートされている時にペイロードが変わっていないかチェック
            if (axi_aw_addr !== axi_aw_addr_delayed) begin
                $error("Write Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_aw_addr, axi_aw_addr_delayed);
                $finish;
            end
            if (axi_aw_burst !== axi_aw_burst_delayed) begin
                $error("Write Address Channel: Burst changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_aw_burst, axi_aw_burst_delayed);
                $finish;
            end
            if (axi_aw_size !== axi_aw_size_delayed) begin
                $error("Write Address Channel: Size changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_aw_size, axi_aw_size_delayed);
                $finish;
            end
            if (axi_aw_id !== axi_aw_id_delayed) begin
                $error("Write Address Channel: ID changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_aw_id, axi_aw_id_delayed);
                $finish;
            end
            if (axi_aw_len !== axi_aw_len_delayed) begin
                $error("Write Address Channel: Length changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_aw_len, axi_aw_len_delayed);
                $finish;
            end
            if (axi_aw_valid !== axi_aw_valid_delayed) begin
                $error("Write Address Channel: Valid changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_aw_valid, axi_aw_valid_delayed);
                $finish;
            end
        end
    end
end

// Readアドレスチャネルのペイロードホールド確認（リセット解除後に監視開始）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は監視しない
    end else begin
        if (!axi_ar_ready_delayed) begin
            // Readyがネゲートされている時にペイロードが変わっていないかチェック
            if (axi_ar_addr !== axi_ar_addr_delayed) begin
                $error("Read Address Channel: Address changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_ar_addr, axi_ar_addr_delayed);
                $finish;
            end
            if (axi_ar_burst !== axi_ar_burst_delayed) begin
                $error("Read Address Channel: Burst changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_ar_burst, axi_ar_burst_delayed);
                $finish;
            end
            if (axi_ar_size !== axi_ar_size_delayed) begin
                $error("Read Address Channel: Size changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_ar_size, axi_ar_size_delayed);
                $finish;
            end
            if (axi_ar_id !== axi_ar_id_delayed) begin
                $error("Read Address Channel: ID changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_ar_id, axi_ar_id_delayed);
                $finish;
            end
            if (axi_ar_len !== axi_ar_len_delayed) begin
                $error("Read Address Channel: Length changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_ar_len, axi_ar_len_delayed);
                $finish;
            end
            if (axi_ar_valid !== axi_ar_valid_delayed) begin
                $error("Read Address Channel: Valid changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_ar_valid, axi_ar_valid_delayed);
                $finish;
            end
        end
    end
end

// Writeデータチャネルのペイロードホールド確認（リセット解除後に監視開始）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は監視しない
    end else begin
        if (!axi_w_ready_delayed) begin
            // Readyがネゲートされている時にペイロードが変わっていないかチェック
            if (axi_w_data !== axi_w_data_delayed) begin
                $error("Write Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_w_data, axi_w_data_delayed);
                $finish;
            end
            if (axi_w_strb !== axi_w_strb_delayed) begin
                $error("Write Data Channel: Strobe changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_w_strb, axi_w_strb_delayed);
                $finish;
            end
            if (axi_w_last !== axi_w_last_delayed) begin
                $error("Write Data Channel: Last changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_w_last, axi_w_last_delayed);
                $finish;
            end
            if (axi_w_valid !== axi_w_valid_delayed) begin
                $error("Write Data Channel: Valid changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_w_valid, axi_w_valid_delayed);
                $finish;
            end
        end
    end
end

// Readデータチャネルのペイロードホールド確認（リセット解除後に監視開始）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // リセット中は監視しない
    end else begin
        if (!axi_r_ready_delayed) begin
            // Readyがネゲートされている時にペイロードが変わっていないかチェック
            if (axi_r_data !== axi_r_data_delayed) begin
                $error("Read Data Channel: Data changed during Ready negated. Current: 0x%h, Delayed: 0x%h", 
                       axi_r_data, axi_r_data_delayed);
                $finish;
            end
            if (axi_r_resp !== axi_r_resp_delayed) begin
                $error("Read Data Channel: Response changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_r_resp, axi_r_resp_delayed);
                $finish;
            end
            if (axi_r_last !== axi_r_last_delayed) begin
                $error("Read Data Channel: Last changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_r_last, axi_r_last_delayed);
                $finish;
            end
            if (axi_r_valid !== axi_r_valid_delayed) begin
                $error("Read Data Channel: Valid changed during Ready negated. Current: %b, Delayed: %b", 
                       axi_r_valid, axi_r_valid_delayed);
                $finish;
            end
        end
    end
end
```

### 2.5 監視・ログ系

監視・ログ系では、テスト実行中の動作監視とログ出力を行います。

#### 2.5.1 基本ログ機能

基本ログ機能では、フェーズ実行、転送、エラーの詳細な記録を行います。

```verilog
// ログ制御用パラメータ
parameter LOG_ENABLE = 1'b1;           // ログ機能の有効/無効
parameter DEBUG_LOG_ENABLE = 1'b1;     // デバッグログの有効/無効
parameter LOG_FILE_PATH = "axi4_testbench.log";  // ログファイルパス

// ログ出力用ファイルハンドル
integer log_file_handle;

// ログ出力関数
function automatic void write_log(input string message);
    if (LOG_ENABLE) begin
        $fwrite(log_file_handle, "[%0t] %s\n", $time, message);
        $fflush(log_file_handle);
    end
endfunction

// デバッグログ出力関数
function automatic void write_debug_log(input string message);
    if (LOG_ENABLE && DEBUG_LOG_ENABLE) begin
        $fwrite(log_file_handle, "[%0t] [DEBUG] %s\n", $time, message);
        $fflush(log_file_handle);
    end
endfunction

// エラーログ出力関数
function automatic void write_error_log(input string message);
    if (LOG_ENABLE) begin
        $fwrite(log_file_handle, "[%0t] [ERROR] %s\n", $time, message);
        $fflush(log_file_handle);
        // コンソールにもエラーを表示
        $error("%s", message);
    end
endfunction

// ログファイルの初期化
initial begin
    if (LOG_ENABLE) begin
        log_file_handle = $fopen(LOG_FILE_PATH, "w");
        if (log_file_handle == 0) begin
            $error("Failed to open log file: %s", LOG_FILE_PATH);
        end else begin
            write_log("=== AXI4 Testbench Log Start ===");
            write_log("Test Parameters:");
            write_log("  - MEMORY_SIZE_BYTES: " + $sformatf("%0d", MEMORY_SIZE_BYTES));
            write_log("  - AXI_DATA_WIDTH: " + $sformatf("%0d", AXI_DATA_WIDTH));
            write_log("  - TOTAL_TEST_COUNT: " + $sformatf("%0d", TOTAL_TEST_COUNT));
            write_log("  - PHASE_TEST_COUNT: " + $sformatf("%0d", PHASE_TEST_COUNT));
        end
    end
end

// フェーズ実行ログ
always_ff @(posedge clk) begin
    if (LOG_ENABLE && !rst_n) begin
        // リセット解除時のログ
        write_log("Reset deasserted - Test execution started");
    end
end

// フェーズ開始ログ
always @(posedge clk) begin
    if (LOG_ENABLE && write_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Write Address Channel started", current_phase));
    end
    if (LOG_ENABLE && read_addr_phase_start) begin
        write_log($sformatf("Phase %0d: Read Address Channel started", current_phase));
    end
    if (LOG_ENABLE && write_data_phase_start) begin
        write_log($sformatf("Phase %0d: Write Data Channel started", current_phase));
    end
    if (LOG_ENABLE && read_data_phase_start) begin
        write_log($sformatf("Phase %0d: Read Data Channel started", current_phase));
    end
end

// フェーズ完了ログ
always @(posedge clk) begin
    if (LOG_ENABLE && write_addr_phase_done) begin
        write_log($sformatf("Phase %0d: Write Address Channel completed", current_phase));
    end
    if (LOG_ENABLE && read_addr_phase_done) begin
        write_log($sformatf("Phase %0d: Read Address Channel completed", current_phase));
    end
    if (LOG_ENABLE && write_data_phase_done) begin
        write_log($sformatf("Phase %0d: Write Data Channel completed", current_phase));
    end
    if (LOG_ENABLE && read_data_phase_done) begin
        write_log($sformatf("Phase %0d: Read Data Channel completed", current_phase));
    end
end

// 転送ログ（Writeアドレスチャネル）
always @(posedge clk) begin
    if (LOG_ENABLE && axi_aw_valid && axi_aw_ready) begin
        write_debug_log($sformatf("Write Address Transfer: Addr=0x%h, Burst=%b, Size=%b, ID=%b, Len=%0d, Phase=%0d", 
                                 axi_aw_addr, axi_aw_burst, axi_aw_size, axi_aw_id, axi_aw_len, current_phase));
    end
end

// 転送ログ（Readアドレスチャネル）
always @(posedge clk) begin
    if (LOG_ENABLE && axi_ar_valid && axi_ar_ready) begin
        write_debug_log($sformatf("Read Address Transfer: Addr=0x%h, Burst=%b, Size=%b, ID=%b, Len=%0d, Phase=%0d", 
                                 axi_ar_addr, axi_ar_burst, axi_ar_size, axi_ar_id, axi_ar_len, current_phase));
    end
end

// 転送ログ（Writeデータチャネル）
always @(posedge clk) begin
    if (LOG_ENABLE && axi_w_valid && axi_w_ready) begin
        write_debug_log($sformatf("Write Data Transfer: Data=0x%h, Strobe=%b, Last=%b, Phase=%0d", 
                                 axi_w_data, axi_w_strb, axi_w_last, current_phase));
    end
end

// 転送ログ（Readデータチャネル）
always @(posedge clk) begin
    if (LOG_ENABLE && axi_r_valid && axi_r_ready) begin
        write_debug_log($sformatf("Read Data Transfer: Data=0x%h, Resp=%b, Last=%b, Phase=%0d", 
                                 axi_r_data, axi_r_resp, axi_r_last, current_phase));
    end
end

// ストールログ
always @(posedge clk) begin
    if (LOG_ENABLE && axi_aw_valid && !axi_aw_ready) begin
        write_debug_log($sformatf("Write Address Stall: Addr=0x%h, Phase=%0d", axi_aw_addr, current_phase));
    end
    if (LOG_ENABLE && axi_ar_valid && !axi_ar_ready) begin
        write_debug_log($sformatf("Read Address Stall: Addr=0x%h, Phase=%0d", axi_ar_addr, current_phase));
    end
    if (LOG_ENABLE && axi_w_valid && !axi_w_ready) begin
        write_debug_log($sformatf("Write Data Stall: Data=0x%h, Phase=%0d", axi_w_data, current_phase));
    end
    if (LOG_ENABLE && axi_r_valid && !axi_r_ready) begin
        write_debug_log($sformatf("Read Data Stall: Data=0x%h, Phase=%0d", axi_r_data, current_phase));
    end
end

// エラー・警告ログ
always @(posedge clk) begin
    // プロトコル違反のログは既存の$error文で出力される
    // ここでは追加のエラー情報をログに記録
end

// テスト完了時の結果まとめ出力
initial begin
    // テスト完了を待機
    wait(generate_stimulus_expected_done);
    
    // 結果まとめをテキストで表示（ファイルには出力しない）
    $display("\n=== AXI4 Testbench Results Summary ===");
    $display("Test Configuration:");
    $display("  - Memory Size: %0d bytes (%0d MB)", MEMORY_SIZE_BYTES, MEMORY_SIZE_BYTES/1024/1024);
    $display("  - Data Width: %0d bits", AXI_DATA_WIDTH);
    $display("  - Total Test Count: %0d", TOTAL_TEST_COUNT);
    $display("  - Phase Test Count: %0d", PHASE_TEST_COUNT);
    $display("  - Number of Phases: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT));
    
    // ログファイルに結果まとめを記録
    if (LOG_ENABLE) begin
        write_log("=== Test Results Summary ===");
        write_log($sformatf("Total Test Count: %0d", TOTAL_TEST_COUNT));
        write_log($sformatf("Number of Phases: %0d", (TOTAL_TEST_COUNT / PHASE_TEST_COUNT)));
        write_log("Test execution completed successfully");
        write_log("=== AXI4 Testbench Log End ===");
        $fclose(log_file_handle);
    end
end
```

#### 2.5.2 ログ機能の特徴

1. **ファイル出力制御**: `LOG_ENABLE`パラメータでログ機能の有効/無効を制御
2. **デバッグログ制御**: `DEBUG_LOG_ENABLE`パラメータでデバッグログの有効/無効を制御
3. **時間スタンプ**: 全てのログにシミュレーション時間を記録
4. **リアルタイム出力**: `$fflush`でログファイルへの即座な出力を保証
5. **結果まとめ**: テスト完了時の結果はコンソールに表示、詳細ログはファイルに記録

### 2.6 重み付き乱数発生系

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

## 3. テストベンチのコード

**テストベンチのコード**: [axi_simple_dual_port_ram_tb.v](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_simple_dual_port_ram_tb.v)

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
