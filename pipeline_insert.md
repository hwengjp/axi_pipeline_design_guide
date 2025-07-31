# AXIバスのパイプライン回路の設計ガイド ～ 第２回 Ready信号とデータにFFを１段挿入する回路

## 目次

- [AXIバスのパイプライン回路の設計ガイド ～ 第２回 Ready信号とデータにFFを１段挿入する回路](#axiバスのパイプライン回路の設計ガイド--第２回-ready信号とデータにffを１段挿入する回路)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 Readyのシーケンス](#21-readyのシーケンス)
    - [2.2 FF挿入による遅延](#22-ff挿入による遅延)
  - [5. サンプルコード](#5-サンプルコード)
  - [15. 総当たり探索法](#15-総当たり探索法)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

パイプライン動作する回路のデータとReadyに1段のFFを挿入する回路です。Ready信号はデータパイプラインの全てのFFのイネーブル信号として使用されます。そのためファンアウトが大きくなります。対策としてReady信号に１段のFFを挿入しますがデータが遅れて停止します。この章ではパイプラインのデータとReadyの基本ルールを守りながらFFを1段挿入する回路を実現します。

## 2. 動作原理

### 2.1 Readyのシーケンス

第１回で学んだReadyのシーケンスをおさらいしましょう。
理解しやすくするために、２クロックのReadyネゲートがある場合の(T3)出力段のシーケンスを書いてみます。
ReadyがLの時、パイプラインは停止（ストール）します。ReadyがLになると、その次のサイクルでデータが保持され、現在のサイクルと同じ値になります。ReadyがLからHになったサイクルのT0,T1,T2,T3は、ReadyがLのサイクルと同じデータになります。

```
Clock    : 123456789012345678
T3       : xxxxxx0001222345xx
T3_Valid : ______HHHHHHHHHH__
Ready    : HHHHHH__HH__HHHHHH
```
```
[T2] -> [T3] -> Output
 |       |
 +-------+-- <- Ready In
```
### 2.2 FF挿入による遅延

下流側のReady_dと1クロック遅れた上流側のReady_uとReady_uで制御された追加のパイプラインT4をこのシーケンスに追加します。State=[Ready_u,Ready_d]です。T4は上流側のReadyで制御されていますので下流側のReady_dのルールに従っていません。
Ready_dで制御される下流側のデータData_dはとりあえず理想の期待値を記述します。

```
Clock        : 123456789012345678
T3           : xxxx01233345556xxx
Ready_u      : HHHHHHH__HH__HHHHH

T4           : xxxxx01222344456xx
Ready_d      : HHHHHH__HH__HHHHHH
State        : 333333201320133333

Data_d       : xxxxx01112333456xx
```

```
[T2] -> [T3] -> Data_u  -> [T4] -----> T4
 |       |                  |
 +-------+-- <- Ready_u <---+--[FF] <- Ready_d
```

Stateの値に対して、次のクロックでどのデータを出力すればよいかを真理値表にします。

| State | 次のクロックで出力する値 | 説明 |
|-------|------------------------|------|
| 0 | ホールド | 現在の値を保持 |
| 1 | T4 | パイプラインT4の値を出力 |
| 2 | T4 | パイプラインT4の値を出力 |
| 3 | T3 | パイプラインT3の値を出力 |

## 5. サンプルコード

ここまでの説明を読み込ませてAIに自動生成させたコードです。この回路を使用するとAXIバスのどのチャネル(リードアドレスチャネル、ライトアドレスチャネル、リードデータチャネル、ライトデータチャネル、ライトレスポンスチャネル)にも簡単に１段のフリップフロップが挿入できます。

```verilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module pipeline_insert #(
    parameter DATA_WIDTH = 64
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input) - axi_ram_core側
    input  wire [DATA_WIDTH-1:0]    u_data,
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output) - バス側
    output wire [DATA_WIDTH-1:0]    d_data,
    output wire                     d_valid,
    input  wire                     d_ready
);

    // Internal signals for 1-stage pipeline
    reg [DATA_WIDTH-1:0] pipe_data;
    reg                   pipe_valid;
    
    // d_readyの1クロック遅延信号
    reg                   d_ready_d;
    
    // State信号（State=[Ready_u,Ready_d]）
    wire [1:0] state;
    assign state = {u_ready, d_ready_d};
    
    // u_readyで制御された1段のパイプライン
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_data  <= {DATA_WIDTH{1'b0}};
            pipe_valid <= 1'b0;
        end else if (u_ready) begin
            pipe_data  <= u_data;
            pipe_valid <= u_valid;
        end
    end
    
    // d_readyの1クロック遅延
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_ready_d <= 1'b0;
        end else begin
            d_ready_d <= d_ready;
        end
    end
    
    // d_ready_dをu_readyに接続
    assign u_ready = d_ready_d;
    
    // Stateに基づくd_dataとd_validの生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_data  <= {DATA_WIDTH{1'b0}};
            d_valid <= 1'b0;
        end else begin
            case (state)
                2'b00: begin // State=0: ホールド（現在の値を保持）
                    // 出力値を保持（変更なし）
                end
                2'b01: begin // State=1: T4（パイプラインT4の値を出力）
                    d_data  <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b10: begin // State=2: T4（パイプラインT4の値を出力）
                    d_data  <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b11: begin // State=3: T3（パイプラインT3の値を出力）
                    d_data  <= u_data;
                    d_valid <= u_valid;
                end
            endcase
        end
    end

endmodule
```




## 15. 総当たり探索法

この回路を初めて設計したときは、役に立ちそうな信号をいくつか作って総当たりで正しい論理となる真理値表を作っています。このような設計手法を（私は）総当たり探索法と呼んでいます。実際にこの機能を設計したときに、役に立ちそうな信号、Readyの1クロック遅れ、２クロック遅れ、データの１クロック遅れ、２クロック遅れ、データパイプラインの１段追加、２段追加したシーケンスを書いてみてその中なら正しい論理となるパーツを集めて回路を完成しています。

---

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details.


