# AXI パイプライン回路 - 使用例とインテグレーションパターン

## 目次

- [AXI パイプライン回路 - 使用例とインテグレーションパターン](#axi-パイプライン回路---使用例とインテグレーションパターン)
  - [目次](#目次)
  - [1. 概要](#1-概要)
  - [2. 基本的な使用例](#2-基本的な使用例)
    - [2.1 単一モジュールの実装](#21-単一モジュールの実装)
    - [2.2 パラメータ設定のバリエーション](#22-パラメータ設定のバリエーション)
  - [3. 高度なインテグレーションパターン](#3-高度なインテグレーションパターン)
    - [3.1 カスケード接続](#31-カスケード接続)
    - [3.2 並列処理パターン](#32-並列処理パターン)
    - [3.3 データ分散・合成パターン](#33-データ分散合成パターン)
  - [4. AXI インターフェース実装例](#4-axi-インターフェース実装例)
    - [4.1 AXI4-Lite マスター接続](#41-axi4-lite-マスター接続)
    - [4.2 AXI4 ストリーム実装](#42-axi4-ストリーム実装)
  - [5. テストパターンと検証](#5-テストパターンと検証)
    - [5.1 基本動作テスト](#51-基本動作テスト)
    - [5.2 ストレステスト](#52-ストレステスト)
    - [5.3 エラー条件テスト](#53-エラー条件テスト)
  - [6. パフォーマンス最適化例](#6-パフォーマンス最適化例)
    - [6.1 レイテンシ最適化](#61-レイテンシ最適化)
    - [6.2 スループット最適化](#62-スループット最適化)
  - [7. 実用的な設計例](#7-実用的な設計例)
    - [7.1 画像処理パイプライン](#71-画像処理パイプライン)
    - [7.2 ネットワークパケット処理](#72-ネットワークパケット処理)
    - [7.3 暗号化処理パイプライン](#73-暗号化処理パイプライン)
  - [8. デバッグとトラブルシューティング](#8-デバッグとトラブルシューティング)
    - [8.1 一般的な問題と解決策](#81-一般的な問題と解決策)
    - [8.2 シミュレーション技法](#82-シミュレーション技法)
  - [ライセンス](#ライセンス)

---

## 1. 概要

このドキュメントでは、`pipeline_4stage` モジュールの具体的な使用例とインテグレーションパターンを詳しく解説します。基本的な使用方法から高度な設計パターンまで、実践的な実装例を提供します。

## 2. 基本的な使用例

### 2.1 単一モジュールの実装

#### 2.1.1 最小構成での実装

```verilog
module minimal_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    // 最小構成での pipeline_4stage の使用
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_in),
        .u_valid (valid_in),
        .u_ready (ready_out),
        .d_data  (data_out),
        .d_valid (valid_out),
        .d_ready (ready_in)
    );

endmodule
```

#### 2.1.2 制御信号付きの実装

```verilog
module controlled_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in,
    output wire        pipeline_active
);

    // 制御信号の生成
    wire internal_valid;
    wire internal_ready;
    
    assign internal_valid = valid_in & enable;
    assign ready_out = internal_ready & enable;
    assign pipeline_active = valid_out;

    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_in),
        .u_valid (internal_valid),
        .u_ready (internal_ready),
        .d_data  (data_out),
        .d_valid (valid_out),
        .d_ready (ready_in)
    );

endmodule
```

### 2.2 パラメータ設定のバリエーション

#### 2.2.1 異なるデータ幅での実装

```verilog
module multi_width_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    
    // 8ビット パイプライン
    input  wire [7:0]  data8_in,
    input  wire        valid8_in,
    output wire        ready8_out,
    output wire [7:0]  data8_out,
    output wire        valid8_out,
    input  wire        ready8_in,
    
    // 64ビット パイプライン
    input  wire [63:0] data64_in,
    input  wire        valid64_in,
    output wire        ready64_out,
    output wire [63:0] data64_out,
    output wire        valid64_out,
    input  wire        ready64_in
);

    // 8ビット パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(8)
    ) u_pipeline8 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data8_in),
        .u_valid (valid8_in),
        .u_ready (ready8_out),
        .d_data  (data8_out),
        .d_valid (valid8_out),
        .d_ready (ready8_in)
    );

    // 64ビット パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(64)
    ) u_pipeline64 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data64_in),
        .u_valid (valid64_in),
        .u_ready (ready64_out),
        .d_data  (data64_out),
        .d_valid (valid64_out),
        .d_ready (ready64_in)
    );

endmodule
```

## 3. 高度なインテグレーションパターン

### 3.1 カスケード接続

#### 3.1.1 直列接続による深いパイプライン

```verilog
module deep_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    // 中間信号の定義
    wire [31:0] stage1_data, stage2_data;
    wire        stage1_valid, stage2_valid;
    wire        stage1_ready, stage2_ready;

    // 第1段（クロック 0-3）
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_stage1 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_in),
        .u_valid (valid_in),
        .u_ready (ready_out),
        .d_data  (stage1_data),
        .d_valid (stage1_valid),
        .d_ready (stage1_ready)
    );

    // 第2段（クロック 4-7）
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_stage2 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (stage1_data),
        .u_valid (stage1_valid),
        .u_ready (stage1_ready),
        .d_data  (stage2_data),
        .d_valid (stage2_valid),
        .d_ready (stage2_ready)
    );

    // 第3段（クロック 8-11）
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_stage3 (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (stage2_data),
        .u_valid (stage2_valid),
        .u_ready (stage2_ready),
        .d_data  (data_out),
        .d_valid (valid_out),
        .d_ready (ready_in)
    );

    // 総レイテンシ: 12クロック
    // 総段数: 12段

endmodule
```

### 3.2 並列処理パターン

#### 3.2.1 データ分散処理

```verilog
module parallel_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [63:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    // データ分割
    wire [31:0] data_low, data_high;
    assign data_low  = data_in[31:0];
    assign data_high = data_in[63:32];

    // 並列パイプライン出力
    wire [31:0] out_low, out_high;
    wire        valid_low, valid_high;
    wire        ready_low, ready_high;

    // 低位32ビット用パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline_low (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_low),
        .u_valid (valid_in),
        .u_ready (ready_low),
        .d_data  (out_low),
        .d_valid (valid_low),
        .d_ready (ready_in)
    );

    // 高位32ビット用パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_pipeline_high (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_high),
        .u_valid (valid_in),
        .u_ready (ready_high),
        .d_data  (out_high),
        .d_valid (valid_high),
        .d_ready (ready_in)
    );

    // 出力統合
    assign data_out = {out_high, out_low};
    assign valid_out = valid_low & valid_high;
    assign ready_out = ready_low & ready_high;

endmodule
```

### 3.3 データ分散・合成パターン

#### 3.3.1 ラウンドロビン分散器付きパイプライン

```verilog
module round_robin_pipeline_example (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    // ラウンドロビンカウンタ
    reg [1:0] rr_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_counter <= 2'b00;
        end else if (valid_in && ready_out) begin
            rr_counter <= rr_counter + 1;
        end
    end

    // 4つのパイプラインに分散
    wire [31:0] pipe_data [3:0];
    wire        pipe_valid [3:0];
    wire        pipe_ready [3:0];
    wire [31:0] pipe_out [3:0];
    wire        pipe_out_valid [3:0];

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_pipelines
            assign pipe_data[i] = data_in;
            assign pipe_valid[i] = valid_in && (rr_counter == i);

            pipeline_4stage #(
                .DATA_WIDTH(32)
            ) u_pipeline (
                .clk     (clk),
                .rst_n   (rst_n),
                .u_data  (pipe_data[i]),
                .u_valid (pipe_valid[i]),
                .u_ready (pipe_ready[i]),
                .d_data  (pipe_out[i]),
                .d_valid (pipe_out_valid[i]),
                .d_ready (ready_in)
            );
        end
    endgenerate

    // 出力選択（最初に有効なデータを選択）
    assign ready_out = pipe_ready[rr_counter];
    
    // 出力マルチプレクサ
    reg [31:0] selected_data;
    reg        selected_valid;
    
    always @(*) begin
        selected_data = 32'h0;
        selected_valid = 1'b0;
        for (int j = 0; j < 4; j = j + 1) begin
            if (pipe_out_valid[j]) begin
                selected_data = pipe_out[j];
                selected_valid = pipe_out_valid[j];
            end
        end
    end

    assign data_out = selected_data;
    assign valid_out = selected_valid;

endmodule
```

## 4. AXI インターフェース実装例

### 4.1 AXI4-Lite マスター接続

```verilog
module axi_lite_pipeline_master (
    input  wire        aclk,
    input  wire        aresetn,
    
    // AXI4-Lite マスターインターフェース
    output wire [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awprot,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    
    // 内部データインターフェース
    input  wire [67:0] write_data, // {addr[31:0], data[31:0], strb[3:0]}
    input  wire        write_valid,
    output wire        write_ready
);

    // パイプライン出力
    wire [67:0] pipe_data;
    wire        pipe_valid;
    wire        pipe_ready;

    // 書き込みリクエストパイプライン
    pipeline_4stage #(
        .DATA_WIDTH(68) // アドレス32 + データ32 + ストローブ4
    ) u_write_pipeline (
        .clk     (aclk),
        .rst_n   (aresetn),
        .u_data  (write_data),
        .u_valid (write_valid),
        .u_ready (write_ready),
        .d_data  (pipe_data),
        .d_valid (pipe_valid),
        .d_ready (pipe_ready)
    );

    // AXI信号への分解
    assign m_axi_awaddr  = pipe_data[67:36];
    assign m_axi_wdata   = pipe_data[35:4];
    assign m_axi_wstrb   = pipe_data[3:0];
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awvalid = pipe_valid;
    assign m_axi_wvalid  = pipe_valid;
    assign m_axi_bready  = 1'b1;

    // Ready信号の統合
    assign pipe_ready = m_axi_awready & m_axi_wready;

endmodule
```

### 4.2 AXI4 ストリーム実装

```verilog
module axi_stream_pipeline (
    input  wire        aclk,
    input  wire        aresetn,
    
    // AXI4-Stream スレーブ
    input  wire [31:0] s_axis_tdata,
    input  wire [3:0]  s_axis_tkeep,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    
    // AXI4-Stream マスター
    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    // ストリームデータのパッキング
    wire [36:0] packed_data;
    assign packed_data = {s_axis_tlast, s_axis_tkeep, s_axis_tdata};

    // パイプライン出力
    wire [36:0] pipe_out;
    wire        pipe_valid;

    // AXI ストリームパイプライン
    pipeline_4stage #(
        .DATA_WIDTH(37) // last(1) + keep(4) + data(32)
    ) u_stream_pipeline (
        .clk     (aclk),
        .rst_n   (aresetn),
        .u_data  (packed_data),
        .u_valid (s_axis_tvalid),
        .u_ready (s_axis_tready),
        .d_data  (pipe_out),
        .d_valid (pipe_valid),
        .d_ready (m_axis_tready)
    );

    // 出力信号の分解
    assign m_axis_tdata  = pipe_out[31:0];
    assign m_axis_tkeep  = pipe_out[35:32];
    assign m_axis_tlast  = pipe_out[36];
    assign m_axis_tvalid = pipe_valid;

endmodule
```

## 5. テストパターンと検証

### 5.1 基本動作テスト

```verilog
module basic_function_test;

    // テスト信号
    reg         clk;
    reg         rst_n;
    reg  [31:0] test_data;
    reg         test_valid;
    wire        test_ready;
    wire [31:0] result_data;
    wire        result_valid;
    reg         result_ready;

    // DUT
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (test_data),
        .u_valid (test_valid),
        .u_ready (test_ready),
        .d_data  (result_data),
        .d_valid (result_valid),
        .d_ready (result_ready)
    );

    // クロック生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 基本動作テスト
    initial begin
        // 初期化
        rst_n = 0;
        test_data = 0;
        test_valid = 0;
        result_ready = 1;

        // リセット解放
        repeat(5) @(posedge clk);
        rst_n = 1;

        // 連続データテスト
        @(posedge clk);
        for (int i = 0; i < 20; i++) begin
            test_data = i + 100;
            test_valid = 1;
            @(posedge clk);
            while (!test_ready) @(posedge clk); // Ready待ち
        end
        test_valid = 0;

        // 結果確認
        repeat(10) @(posedge clk);
        $display("Basic function test completed");
        $stop;
    end

    // データ検証
    int expected_data[$];
    int received_data[$];

    always @(posedge clk) begin
        if (test_valid && test_ready) begin
            expected_data.push_back(test_data);
        end
        if (result_valid && result_ready) begin
            received_data.push_back(result_data);
        end
    end

endmodule
```

### 5.2 ストレステスト

```verilog
module stress_test;

    // テスト信号
    reg         clk;
    reg         rst_n;
    reg  [31:0] test_data;
    reg         test_valid;
    wire        test_ready;
    wire [31:0] result_data;
    wire        result_valid;
    reg         result_ready;

    // DUT
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (test_data),
        .u_valid (test_valid),
        .u_ready (test_ready),
        .d_data  (result_data),
        .d_valid (result_valid),
        .d_ready (result_ready)
    );

    // クロック生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ランダムストレステスト
    initial begin
        rst_n = 0;
        test_data = 0;
        test_valid = 0;
        result_ready = 1;

        repeat(5) @(posedge clk);
        rst_n = 1;

        // ランダムな Valid パターン
        fork
            begin
                for (int i = 0; i < 1000; i++) begin
                    @(posedge clk);
                    test_data = $random;
                    test_valid = ($random % 100) < 70; // 70%の確率でValid
                end
            end

            begin
                for (int j = 0; j < 1000; j++) begin
                    @(posedge clk);
                    result_ready = ($random % 100) < 80; // 80%の確率でReady
                end
            end
        join

        repeat(20) @(posedge clk);
        $display("Stress test completed");
        $stop;
    end

    // 性能測定
    int valid_cycles = 0;
    int total_cycles = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            total_cycles++;
            if (result_valid && result_ready) begin
                valid_cycles++;
            end
        end
    end

    final begin
        real efficiency = real'(valid_cycles) / real'(total_cycles) * 100.0;
        $display("Pipeline efficiency: %.2f%% (%0d/%0d)", 
                 efficiency, valid_cycles, total_cycles);
    end

endmodule
```

### 5.3 エラー条件テスト

```verilog
module error_condition_test;

    // テスト信号
    reg         clk;
    reg         rst_n;
    reg  [31:0] test_data;
    reg         test_valid;
    wire        test_ready;
    wire [31:0] result_data;
    wire        result_valid;
    reg         result_ready;

    // DUT
    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (test_data),
        .u_valid (test_valid),
        .u_ready (test_ready),
        .d_data  (result_data),
        .d_valid (result_valid),
        .d_ready (result_ready)
    );

    // クロック生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // エラー条件テスト
    initial begin
        // 初期化
        rst_n = 0;
        test_data = 0;
        test_valid = 0;
        result_ready = 1;

        repeat(5) @(posedge clk);
        rst_n = 1;

        // テスト1: Ready=0でのストール動作
        $display("Test 1: Stall behavior with ready=0");
        test_data = 32'hDEADBEEF;
        test_valid = 1;
        result_ready = 0; // Ready を落とす

        repeat(10) @(posedge clk);
        result_ready = 1; // Ready を戻す
        repeat(10) @(posedge clk);

        // テスト2: Valid=0でのバブル動作
        $display("Test 2: Bubble behavior with valid=0");
        test_valid = 0;
        repeat(8) @(posedge clk);

        // テスト3: リセット中の動作
        $display("Test 3: Reset behavior");
        test_valid = 1;
        repeat(2) @(posedge clk);
        rst_n = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(8) @(posedge clk);

        $display("Error condition tests completed");
        $stop;
    end

    // アサーション: Ready信号の整合性チェック
    property ready_consistency;
        @(posedge clk) disable iff (!rst_n)
        test_ready == result_ready;
    endproperty
    assert property (ready_consistency)
    else $error("Ready signal inconsistency detected");

    // アサーション: Valid信号のタイミングチェック
    property valid_delay;
        @(posedge clk) disable iff (!rst_n)
        test_valid && test_ready |-> ##4 result_valid;
    endproperty
    assert property (valid_delay)
    else $error("Valid signal timing violation");

endmodule
```

## 6. パフォーマンス最適化例

### 6.1 レイテンシ最適化

#### 6.1.1 バイパス回路付きパイプライン

```verilog
module low_latency_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bypass_enable,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    // 通常のパイプライン
    wire [31:0] pipe_data;
    wire        pipe_valid;
    wire        pipe_ready;

    pipeline_4stage #(
        .DATA_WIDTH(32)
    ) u_normal_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (data_in),
        .u_valid (valid_in & ~bypass_enable),
        .u_ready (pipe_ready),
        .d_data  (pipe_data),
        .d_valid (pipe_valid),
        .d_ready (ready_in)
    );

    // バイパス経路
    reg [31:0] bypass_data;
    reg        bypass_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bypass_data <= 32'h0;
            bypass_valid <= 1'b0;
        end else if (ready_in) begin
            bypass_data <= data_in;
            bypass_valid <= valid_in & bypass_enable;
        end
    end

    // 出力選択
    assign data_out = bypass_enable ? bypass_data : pipe_data;
    assign valid_out = bypass_enable ? bypass_valid : pipe_valid;
    assign ready_out = bypass_enable ? ready_in : pipe_ready;

endmodule
```

### 6.2 スループット最適化

#### 6.2.1 並列パイプライン with アービター

```verilog
module high_throughput_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] data_in,
    input  wire        valid_in,
    output wire        ready_out,
    output wire [31:0] data_out,
    output wire        valid_out,
    input  wire        ready_in
);

    parameter NUM_PIPELINES = 4;

    // 並列パイプライン
    wire [31:0] pipe_data [NUM_PIPELINES-1:0];
    wire        pipe_valid [NUM_PIPELINES-1:0];
    wire        pipe_ready [NUM_PIPELINES-1:0];

    // 入力分散カウンタ
    reg [$clog2(NUM_PIPELINES)-1:0] input_select;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_select <= 0;
        end else if (valid_in && ready_out) begin
            input_select <= (input_select == NUM_PIPELINES-1) ? 0 : input_select + 1;
        end
    end

    // 並列パイプライン生成
    genvar i;
    generate
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin : gen_parallel_pipes
            pipeline_4stage #(
                .DATA_WIDTH(32)
            ) u_pipeline (
                .clk     (clk),
                .rst_n   (rst_n),
                .u_data  (data_in),
                .u_valid (valid_in && (input_select == i)),
                .u_ready (pipe_ready[i]),
                .d_data  (pipe_data[i]),
                .d_valid (pipe_valid[i]),
                .d_ready (ready_in)
            );
        end
    endgenerate

    // 出力アービター（ラウンドロビン）
    reg [$clog2(NUM_PIPELINES)-1:0] output_select;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_select <= 0;
        end else if (valid_out && ready_in) begin
            // 次の有効な出力を探す
            output_select <= (output_select == NUM_PIPELINES-1) ? 0 : output_select + 1;
        end
    end

    // 出力選択
    assign ready_out = pipe_ready[input_select];
    assign data_out = pipe_data[output_select];
    assign valid_out = pipe_valid[output_select];

endmodule
```

## 7. 実用的な設計例

### 7.1 画像処理パイプライン

```verilog
module image_processing_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    
    // 画像データ入力
    input  wire [23:0] pixel_in,     // RGB888
    input  wire        pixel_valid,
    output wire        pixel_ready,
    input  wire        line_start,
    input  wire        frame_start,
    
    // 処理済み画像データ出力
    output wire [23:0] pixel_out,    // RGB888
    output wire        pixel_out_valid,
    input  wire        pixel_out_ready,
    output wire        line_out_start,
    output wire        frame_out_start
);

    // 制御信号を含むデータパッキング
    wire [25:0] packed_input;
    assign packed_input = {frame_start, line_start, pixel_in};

    // パイプライン出力
    wire [25:0] packed_output;
    wire        pipe_valid;

    // 画像処理パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(26) // frame_start(1) + line_start(1) + RGB(24)
    ) u_image_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (packed_input),
        .u_valid (pixel_valid),
        .u_ready (pixel_ready),
        .d_data  (packed_output),
        .d_valid (pipe_valid),
        .d_ready (pixel_out_ready)
    );

    // 出力信号の分解
    assign pixel_out        = packed_output[23:0];
    assign line_out_start   = packed_output[24];
    assign frame_out_start  = packed_output[25];
    assign pixel_out_valid  = pipe_valid;

    // 画像処理統計
    reg [31:0] frame_counter;
    reg [31:0] pixel_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_counter <= 0;
            pixel_counter <= 0;
        end else begin
            if (pixel_out_valid && pixel_out_ready) begin
                pixel_counter <= pixel_counter + 1;
                if (frame_out_start) begin
                    frame_counter <= frame_counter + 1;
                end
            end
        end
    end

endmodule
```

### 7.2 ネットワークパケット処理

```verilog
module network_packet_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    
    // パケット入力
    input  wire [63:0] packet_data,
    input  wire [7:0]  packet_keep,
    input  wire        packet_last,
    input  wire        packet_valid,
    output wire        packet_ready,
    
    // 処理済みパケット出力
    output wire [63:0] packet_out_data,
    output wire [7:0]  packet_out_keep,
    output wire        packet_out_last,
    output wire        packet_out_valid,
    input  wire        packet_out_ready
);

    // パケットデータのパッキング
    wire [72:0] packed_packet;
    assign packed_packet = {packet_last, packet_keep, packet_data};

    // パイプライン出力
    wire [72:0] pipe_output;
    wire        pipe_valid;

    // パケット処理パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(73) // last(1) + keep(8) + data(64)
    ) u_packet_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (packed_packet),
        .u_valid (packet_valid),
        .u_ready (packet_ready),
        .d_data  (pipe_output),
        .d_valid (pipe_valid),
        .d_ready (packet_out_ready)
    );

    // 出力信号の分解
    assign packet_out_data  = pipe_output[63:0];
    assign packet_out_keep  = pipe_output[71:64];
    assign packet_out_last  = pipe_output[72];
    assign packet_out_valid = pipe_valid;

    // パケット統計
    reg [31:0] packet_count;
    reg [31:0] byte_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_count <= 0;
            byte_count <= 0;
        end else if (packet_out_valid && packet_out_ready) begin
            if (packet_out_last) begin
                packet_count <= packet_count + 1;
            end
            byte_count <= byte_count + $countones(packet_out_keep);
        end
    end

endmodule
```

### 7.3 暗号化処理パイプライン

```verilog
module crypto_pipeline (
    input  wire         clk,
    input  wire         rst_n,
    
    // データ入力
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    input  wire         crypto_valid,
    output wire         crypto_ready,
    
    // 暗号化結果出力
    output wire [127:0] ciphertext,
    output wire         cipher_valid,
    input  wire         cipher_ready
);

    // 鍵とデータの結合
    wire [255:0] crypto_input;
    assign crypto_input = {key, plaintext};

    // パイプライン出力
    wire [255:0] pipe_output;
    wire         pipe_valid;

    // 暗号化パイプライン
    pipeline_4stage #(
        .DATA_WIDTH(256) // key(128) + plaintext(128)
    ) u_crypto_pipeline (
        .clk     (clk),
        .rst_n   (rst_n),
        .u_data  (crypto_input),
        .u_valid (crypto_valid),
        .u_ready (crypto_ready),
        .d_data  (pipe_output),
        .d_valid (pipe_valid),
        .d_ready (cipher_ready)
    );

    // 簡単な暗号化処理（XOR）- 実際にはより複雑な処理
    assign ciphertext = pipe_output[127:0] ^ pipe_output[255:128];
    assign cipher_valid = pipe_valid;

    // 暗号化レート監視
    reg [31:0] encrypt_count;
    reg [31:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            encrypt_count <= 0;
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (cipher_valid && cipher_ready) begin
                encrypt_count <= encrypt_count + 1;
            end
        end
    end

endmodule
```

## 8. デバッグとトラブルシューティング

### 8.1 一般的な問題と解決策

#### 8.1.1 Ready信号の組み合わせループ

**問題**: Ready信号が組み合わせ回路で伝播するため、組み合わせループが発生する可能性があります。

**解決策**:
```verilog
// 問題のあるコード
assign u_ready = d_ready; // 直接接続は危険

// 改善されたコード - レジスタ経由
reg ready_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ready_reg <= 1'b0;
    end else begin
        ready_reg <= d_ready;
    end
end
assign u_ready = ready_reg;
```

#### 8.1.2 タイミング制約の問題

**問題**: Ready信号の伝播遅延がクリティカルパスになる場合があります。

**解決策**:
```tcl
# SDCファイルでの制約例
set_max_delay -from [get_ports d_ready] -to [get_ports u_ready] 2.0
set_false_path -from [get_clocks clk] -through [get_nets ready]
```

### 8.2 シミュレーション技法

#### 8.2.1 詳細ログ出力

```verilog
module debug_pipeline_wrapper (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] u_data,
    input  wire        u_valid,
    output wire        u_ready,
    output wire [31:0] d_data,
    output wire        d_valid,
    input  wire        d_ready
);

    // DUT
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

    // デバッグ用ログ出力
    always @(posedge clk) begin
        if (rst_n) begin
            if (u_valid && u_ready) begin
                $display("[%0t] INPUT: data=%h", $time, u_data);
            end
            if (d_valid && d_ready) begin
                $display("[%0t] OUTPUT: data=%h", $time, d_data);
            end
            if (!d_ready) begin
                $display("[%0t] STALL: Pipeline stalled", $time);
            end
        end
    end

    // 内部状態の監視
    always @(posedge clk) begin
        if (rst_n) begin
            $display("[%0t] INTERNAL: T0=%h(v=%b) T1=%h(v=%b) T2=%h(v=%b) T3=%h(v=%b)",
                     $time,
                     dut.t_data[0], dut.t_valid[0],
                     dut.t_data[1], dut.t_valid[1],
                     dut.t_data[2], dut.t_valid[2],
                     dut.t_data[3], dut.t_valid[3]);
        end
    end

endmodule
```

#### 8.2.2 カバレッジ測定

```verilog
// 機能カバレッジ
covergroup pipeline_coverage @(posedge clk);
    // データ転送カバレッジ
    cp_data_transfer: coverpoint {u_valid, u_ready, d_valid, d_ready} {
        bins normal_flow = {4'b1111};
        bins input_stall = {4'b10??};
        bins output_stall = {4'b??10};
        bins no_transfer = {4'b0000};
    }
    
    // データパターンカバレッジ
    cp_data_pattern: coverpoint u_data {
        bins zero = {32'h00000000};
        bins all_ones = {32'hFFFFFFFF};
        bins alternating = {32'hAAAAAAAA, 32'h55555555};
        bins random = default;
    }
endgroup

pipeline_coverage cov_inst = new();
```

---

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details.

このドキュメントは、AIがハードウェア設計を学習するための教師データとしても活用できるよう設計されています。