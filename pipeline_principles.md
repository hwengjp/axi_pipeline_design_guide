# AXIバスのパイプライン回路の設計ガイド ～ 第１回 パイプラインの動作原理

## 目次

- [AXIバスのパイプライン回路の設計ガイド ～ 第１回 パイプラインの動作原理](#axiバスのパイプライン回路の設計ガイド--第１回-パイプラインの動作原理)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. パイプラインの動作原理](#2-パイプラインの動作原理)
    - [2.1 基本的な考え方](#21-基本的な考え方)
    - [2.2 Ready/Validハンドシェイク](#22-readyvalidハンドシェイク)
    - [2.3 ストール動作](#23-ストール動作)
    - [2.4 バブル動作](#24-バブル動作)
  - [3. パイプライン構造](#3-パイプライン構造)
    - [3.1 基本構造](#31-基本構造)
    - [3.2 パイプライン構成表](#32-パイプライン構成表)
    - [3.3 FF詳細仕様](#33-ff詳細仕様)
  - [4. パイプライン動作シーケンス](#4-パイプライン動作シーケンス)
    - [4.1 Readyがアサート状態のシーケンス](#41-readyがアサート状態のシーケンス)
    - [4.2 Validが途中でネゲートされるケース](#42-validが途中でネゲートされるケース)
    - [4.3 Readyが途中でネゲートされるケース](#43-readyが途中でネゲートされるケース)
      - [4.3.1 1クロックネゲートのケース](#431-1クロックネゲートのケース)
      - [4.3.2 2クロックネゲートのケース](#432-2クロックネゲートのケース)
  - [5. サンプルコード](#5-サンプルコード)
  - [6. 帰納法的設計](#6-帰納法的設計)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

パイプライン回路の動作原理の説明を説明してサンプルコードを提供します。

## 2. パイプラインの動作原理

パイプラインは複数の処理段階を並列に実行することで、全体の処理能力を向上させる手法です。各段階は独立して動作し、データを次の段階に順次受け渡します。

### 2.1 基本的な考え方

パイプラインは制御されるデータ(ペイロードとも呼ばれる)と制御信号であるReadyとValidで構成されます。Validは各パイプラインステージに有効なデータがあるかどうかを示します。Readyは上流の回路に対してデータを受け取れるかどうかを示します。Readyがネゲートされるとパイプラインが停止してデータはReadyがHになるまでホールドされます。下流の回路がデータを受け取れない状態の時にReadyをネゲートします。パイプラインが停止すると、上流の回路にReadyをネゲートしてデータを受け取れないことを知らせます。

### 2.2 Ready/Validハンドシェイク

パイプラインの制御にはReady/Validハンドシェイクが使用されます：

- **Valid信号**: データが有効であることを示す
- **Ready信号**: 次の段階がデータを受け取れることを示す
- **転送条件**: Valid=H かつ Ready=H の時のみデータが転送される

### 2.3 ストール動作

ReadyがLの時、パイプラインは停止（ストール）します：
- データは現在の段階で保持される
- Valid信号も同様に保持される
- 上流の回路にReady=Lを伝播させる

### 2.4 バブル動作

ValidがLの時、無効なデータ（バブル）がパイプラインを流れます：
- データは転送されるが、Valid=Lにより無効として扱われる
- 下流の回路はValidを確認してデータの有効性を判断する

## 3. パイプライン構造

### 3.1 基本構造

- **シフトレジスタ構造**: パイプラインはシンプルにシフトレジスタ構造
- **データの種類**: アドレス、データ、IDなどパイプラインで受け取るデータすべてが含まれる
- **Validパイプライン**: データパイプラインに並行して同じ段数のValidパイプラインが存在
- **Valid信号の役割**: データと一緒に入力され、出力までデータと一緒に流れ、出力データが有効かどうかのフラグとして使用
- **Ready信号の接続**: シンプルにすべてのFFのイネーブルピンに接続
- **Ready信号の流れ**: 下流側から入ったReadyはそのまま非同期で上流側に出力されます。

この制御方法は非常にシンプルで実装が容易です。ただし、Readyが非同期で下流から上流に突き抜けてしまう点とReadyのファンアウトが大きい点がデメリットです。対策は別途解説します。

```
  Input -> [T0] -> [T1] -> [T2] -> [T3] -> Output
            |       |       |       |
Ready Out <-+-------+-------+-------+-<- Ready In
                                        (Common)
```
### 3.2 パイプライン構成表

| 段階 | データFF | Valid FF | イネーブル信号 | 説明 |
|------|----------|----------|----------------|------|
| T0 | N-bit FF | 1-bit FF | Ready (共通) | 入力段階 |
| T1 | N-bit FF | 1-bit FF | Ready (共通) | 第1段階 |
| T2 | N-bit FF | 1-bit FF | Ready (共通) | 第2段階 |
| T3 | N-bit FF | 1-bit FF | Ready (共通) | 出力段階 |

### 3.3 FF詳細仕様

| 項目 | データFF | Valid FF | Ready信号 |
|------|----------|----------|-----------|
| ビット幅 | N-bit | 1-bit | 1-bit (共通) |
| 個数 | 4個 | 4個 | 1本 |
| イネーブル信号 | Ready (共通) | Ready (共通) | - |
| 同期方式 | 同期 | 同期 | - |

## 4. パイプライン動作シーケンス

### 4.1 Readyがアサート状態のシーケンス

ReadyがHの期間は、Validとデータはパイプラインに順番に流れます。

```
Clock    : 12345678901234
Input    : xx012345xxxxxx
Valid    : __HHHHHH______
T0       : xxx012345xxxxx
T0_Valid : ___HHHHHH_____
T1       : xxxx012345xxxx
T1_Valid : ____HHHHHH____
T2       : xxxxx012345xxx
T2_Valid : _____HHHHHH___
T3       : xxxxxx012345xx
T3_Valid : ______HHHHHH__
Ready    : HHHHHHHHHHHHHH
```

### 4.2 Validが途中でネゲートされるケース

ValidがLの場合、無効なデータ（バブル）がパイプラインを流れます。

```
Clock    : 123456789012345
Input    : xx012x345xxxxxx
Valid    : __HHH_HHH______
T0       : xxx012x345xxxxx
T0_Valid : ___HHH_HHH_____
T1       : xxxx012x345xxxx
T1_Valid : ____HHH_HHH____
T2       : xxxxx012x345xxx
T2_Valid : _____HHH_HHH___
T3       : xxxxxx012x345xx
T3_Valid : ______HHH_HHH__
Ready    : HHHHHHHHHHHHHHH
```

### 4.3 Readyが途中でネゲートされるケース

ReadyがLの時、パイプラインは停止（ストール）します。ReadyがLになると、その次のサイクルでデータが保持され、現在のサイクルと同じ値になります。ReadyがLからHになったサイクルのT0,T1,T2,T3は、ReadyがLのサイクルと同じデータになります。

#### 4.3.1 1クロックネゲートのケース

```
Clock    : 123456789012345
Input    : xx0123445xxxxxx
Valid    : __HHHHHHH______
T0       : xxx0123345xxxxx
T0_Valid : ___HHHHHHH_____
T1       : xxxx0122345xxxx
T1_Valid : ____HHHHHHH____
T2       : xxxxx0112345xxx
T2_Valid : _____HHHHHHH___
T3       : xxxxxx0012345xx
T3_Valid : ______HHHHHHH__
Ready    : HHHHHH_HHHHHHHH
```
1. **Ready信号の動作**:
   - 7クロック目でReadyがL（'_'）になる
   - 8クロック目でReadyがHに戻る

2. **パイプラインのストール動作**:
   - 7クロック目（Ready=L）: 6クロック目でReady=Hだったため、7クロック目でデータが更新される。FFのイネーブルがネゲートされるため、8クロック目でデータが保持される
   - 8クロック目（Ready=H）: 7クロック目でReady=Lだったため、T0,T1,T2,T3の値が7クロック目と同じ値で保持される
   - 9クロック目以降: 正常にデータが流れ始める

3. **具体的なデータの流れ**:
   - **7クロック目**: T0=3, T1=2, T2=1, T3=0
   - **8クロック目**: T0=3, T1=2, T2=1, T3=0（同じ値）
   - **9クロック目**: T0=4, T1=3, T2=2, T3=1（正常に流れ始める）

4. **Valid信号の動作**:
   - Valid信号も同様にストールされる
   - 8クロック目は7クロック目と同じ値が保持される

#### 4.3.2 2クロックネゲートのケース

```
Clock    : 1234567890123456
Input    : xx01234445xxxxxx
Valid    : __HHHHHHHH______
T0       : xxx01233345xxxxx
T0_Valid : ___HHHHHHHH_____
T1       : xxxx01222345xxxx
T1_Valid : ____HHHHHHHH____
T2       : xxxxx01112345xxx
T2_Valid : _____HHHHHHHH___
T3       : xxxxxx00012345xx
T3_Valid : ______HHHHHHHH__
Ready    : HHHHHH__HHHHHHHH
```
1. **Ready信号の動作**:
   - 7-8クロック目でReadyがL（'_'）になる（2クロック間）
   - 9クロック目でReadyがHに戻る

2. **パイプラインのストール動作**:
   - 7-8クロック目（Ready=L）: 6クロック目でReady=Hだったため、7クロック目でデータが更新される。FFのイネーブルがネゲートされるため、8-9クロック目でデータが保持される
   - 9クロック目（Ready=H）: 8クロック目でReady=Lだったため、T0,T1,T2,T3の値が8クロック目と同じ値で保持される
   - 10クロック目以降: 正常にデータが流れ始める

3. **具体的なデータの流れ**:
   - **7クロック目**: T0=3, T1=2, T2=1, T3=0（ストール開始）
   - **8クロック目**: T0=3, T1=2, T2=1, T3=0（ストール継続）
   - **9クロック目**: T0=3, T1=2, T2=1, T3=0（ストール解除、同じ値）
   - **10クロック目**: T0=4, T1=3, T2=2, T3=1（正常に流れ始める）
   - **11クロック目**: T0=4, T1=4, T2=3, T3=2（正常に流れ続ける）

4. **Valid信号の動作**:
   - Valid信号も同様にストールされる
   - 7-8クロック目と9クロック目で同じ値が保持される
   - データとValidは2クロック間ホールドされる

## 5. サンプルコード

ここまでの説明を読み込ませてAIに自動生成させたコードです。非常にシンプルで難しいところはありません。AXIバスの基本シーケンスはこのようなReadyとValidを使用したシフトレジスタ構造なのです。

```verilog
module pipeline #(
    parameter DATA_WIDTH = 32,
    parameter PIPELINE_STAGES = 4
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Upstream Interface (Input)
    input  wire [DATA_WIDTH-1:0]    u_data,
    input  wire                     u_valid,
    output wire                     u_ready,
    
    // Downstream Interface (Output)
    output wire [DATA_WIDTH-1:0]    d_data,
    output wire                     d_valid,
    input  wire                     d_ready
);

    // Internal signals for pipeline stages
    wire [DATA_WIDTH-1:0]   t_data [PIPELINE_STAGES-1:0]; // t_data[0]=T0, t_data[1]=T1, ..., t_data[PIPELINE_STAGES-1]=T(PIPELINE_STAGES-1)
    wire                    t_valid[PIPELINE_STAGES-1:0]; // t_valid[0]=T0, t_valid[1]=T1, ..., t_valid[PIPELINE_STAGES-1]=T(PIPELINE_STAGES-1)
    
    // Ready signal (common to all FFs)
    wire ready;
    
    // Assign ready signal
    assign ready = d_ready;
    
    // Pipeline stages T0->T1->...->T(PIPELINE_STAGES-1)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < PIPELINE_STAGES; i = i + 1) begin
                t_data[i]  <= {DATA_WIDTH{1'b0}};
                t_valid[i] <= 1'b0;
            end
        end else if (ready) begin
            t_data[0]  <= u_data;
            t_valid[0] <= u_valid;
            for (integer i = 1; i < PIPELINE_STAGES; i = i + 1) begin
                t_data[i]  <= t_data[i-1];
                t_valid[i] <= t_valid[i-1];
            end
        end
    end
    
    // Output assignments
    assign d_data  = t_data[PIPELINE_STAGES-1];
    assign d_valid = t_valid[PIPELINE_STAGES-1];
    assign u_ready = ready;

endmodule
```
## 6. 帰納法的設計

この回路はN段のパイプラインをN+1段に増やしても同じロジックが使えます。このように小さな回路でルールを考えて1つ段増やしても同じルールを使う設計手法を（私は）帰納法的設計と呼んでいます。この設計方法は例えば乗算器を設計する時に8ビットくらいでロジックを考えておいて全ケーステストをした後に16bitに拡張するとか（全ケーステストはとても時間がかかる場合に、縮小した回路のテストで論理の正常性を担保できる）。他の例としては、Readyのネゲートの動作を確認するときは1クロックネゲート、2クロックネゲート、Nクロックネゲートというように解析します。この方法はテストパターンを端折る場合などにも応用できます。


## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](LICENSE) file for details.

