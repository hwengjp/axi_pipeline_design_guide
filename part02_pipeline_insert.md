# AXIバスのパイプライン回路設計ガイド ～ 第２回 Ready信号とデータにFFを１段挿入する回路

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第２回 Ready信号とデータにFFを１段挿入する回路](#axiバスのパイプライン回路設計ガイド--第２回-ready信号とデータにffを１段挿入する回路)
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

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

パイプライン動作する回路のデータとReadyに1段のFFを挿入する回路です。Ready信号はデータパイプラインの全てのFFのイネーブル信号として使用されます。そのためファンアウトが大きくなります。対策としてReady信号に１段のFFを挿入しますがデータが遅れて停止します。この章ではパイプラインのデータとReadyの基本ルールを守りながらFFを1段挿入する回路を実現します。

この回路をの利点は、回路の単純化・モジュラー化ができると同時に、シーケンスの設計を動作周波数のチューニングと分離できる点です。シーケンス設計の時点では動作周波数を気にせず設計しておいて、シーケンスの設計が終わって動作周波数が問題になればこのモジュールを挿入するという対処が可能です。設計の後戻りなく開発を進めることが可能となります。

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

上流のu_Readyは下流側のd_Readyを1クロック遅延させた信号です。u_Readyとu_Readyで制御された追加のパイプラインT4をこのシーケンスに追加します。State=[u_Ready,d_Ready]です。T4は上流側のu_Readyで制御されていますので下流側のd_Readyのルールに従っていません。
d_Readyで制御される下流側のデータd_Dataはとりあえず理想の期待値を記述します。

```
Clock        : 123456789012345678
T3           : xxxx01233345556xxx
u_Ready      : HHHHHHH__HH__HHHHH

T4           : xxxxx01222344456xx
d_Ready      : HHHHHH__HH__HHHHHH
State        : 333333201320133333

d_Data       : xxxxx01112333456xx
```

Data_dはT3, T4, Ready_u, Ready_dから生成するロジックです。
```
<-前段のモジュールの範囲-><- この章で設計するモジュールの範囲 ->
                             +---------------+
                             |               | 
[T2] -> [T3] -->   Data_u ->-+-> [T4] -> [Dtata_d] -> Data_d
 |       |                        |
 +-------+--- <-  Ready_u <-------+----- [FF] ---- <- Ready_d
```

State=[u_Ready,d_Ready]の値に対して、次のクロックでどのデータを出力すればよいかを真理値表にします。

| State | 次のクロックで出力する値 | 説明 |
|-------|------------------------|------|
| 0 | ホールド | 現在の値を保持 |
| 1 | T4 | パイプラインT4の値を出力 |
| 2 | T4 | パイプラインT4の値を出力 |
| 3 | T3 | パイプラインT3の値を出力 |

## 5. サンプルコード

ここまでの説明を読み込ませてAIに自動生成させたコードです。この回路を使用するとAXIバスのどのチャネル(リードアドレスチャネル、ライトアドレスチャネル、リードデータチャネル、ライトデータチャネル、ライトレスポンスチャネル)にも簡単に１段のフリップフロップが挿入できます。

```systemverilog
// Licensed under the Apache License, Version 2.0 - see LICENSE file for details.

module pipeline_insert #(
    parameter DATA_WIDTH = 32        // Data width in bits
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,

    // Upstream Interface (Input)
    input  wire [DATA_WIDTH-1:0]   u_data,
    input  wire                     u_valid,
    output reg                      u_ready,

    // Downstream Interface (Output)
    output reg [DATA_WIDTH-1:0]    d_data,
    output reg                      d_valid,
    input  wire                     d_ready
);

    // Internal signals for 1-stage pipeline
    reg [DATA_WIDTH-1:0]           pipe_data;
    reg                             pipe_valid;

    // State signal (State=[u_ready, d_ready])
    wire [1:0]                     state;
    assign state = {u_ready, d_ready};

    // Pipeline stage controlled by u_ready
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_data <= {DATA_WIDTH{1'b0}};
            pipe_valid <= 1'b0;
        end else if (u_ready) begin
            pipe_data <= u_data;
            pipe_valid <= u_valid;
        end
    end

    // u_ready generation with 1-clock delay from d_ready
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_ready <= 1'b0;
        end else begin
            u_ready <= d_ready;
        end
    end

    // Output generation based on state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_data <= {DATA_WIDTH{1'b0}};
            d_valid <= 1'b0;
        end else begin
            case (state)
                2'b00: begin // State=0: Hold current values
                    // Keep current output values (no change)
                end
                2'b01: begin // State=1: Output pipeline stage
                    d_data <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b10: begin // State=2: Output pipeline stage
                    d_data <= pipe_data;
                    d_valid <= pipe_valid;
                end
                2'b11: begin // State=3: Output bypass (direct from input)
                    d_data <= u_data;
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


