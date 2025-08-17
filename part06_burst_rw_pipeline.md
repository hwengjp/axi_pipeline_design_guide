# AXIバスのパイプライン回路設計ガイド ～ 第６回 統合ステート管理によるリードライトパイプラインの実装

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第６回 統合ステート管理によるリードライトパイプラインの実装](#axiバスのパイプライン回路設計ガイド--第６回-統合ステート管理によるリードライトパイプラインの実装)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 リードライトの合流シナリオ](#21-リードライトの合流シナリオ)
    - [2.2 優先順位の調停シナリオ](#22-優先順位の調停シナリオ)
  - [3. リードライトが合流するパイプライン](#3-リードライトが合流するパイプライン)
    - [3.1 Readパイプライン（第４回のサンプルコードより）](#31-readパイプライン第４回のサンプルコードより)
    - [3.2 Writeパイプライン（第５回のサンプルコードより）](#32-writeパイプライン第５回のサンプルコードより)
  - [4. シーケンス　リードとライトが混在するバーストアクセスのシーケンス](#4-シーケンスリードとライトが混在するバーストアクセスのシーケンス)
  - [5. サンプルコード](#5-サンプルコード)
    - [5.1 リードライトパイプラインモジュール](#51-リードライトパイプラインモジュール)
    - [5.2 リードライトパイプラインテストベンチ](#52-リードライトパイプラインテストベンチ)
  - [6. 条件網羅法と条件刈込法](#6-条件網羅法と条件刈込法)
    - [6.1 条件網羅法とは](#61-条件網羅法とは)
    - [6.2 条件刈込法とは](#62-条件刈込法とは)
    - [6.3 実装例での適用](#63-実装例での適用)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、パイプライン処理においてリードとライトの統合制御を実現するAXIリードライトパイプラインの実装について説明します。前回までに学んだパイプライン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「リードライト統合制御」シナリオを扱います。

リードライト統合制御は、リードリクエストとライトリクエストを単一のパイプラインで効率的に処理する仕組みです。T1ステージでの統合されたステート管理により、明確な優先度制御とパイプライン制御を実現します。この統合制御により、リードとライトの処理順序が制御され、データの整合性が保たれます。

**統合パイプラインの特徴**:
- **Readパイプライン**: 3段構成でデータ増幅、ステート制御、メモリアクセスを実現
- **Writeパイプライン**: 5段構成でアドレス・データ合流、ステート制御、メモリアクセス、レスポンス生成を実現
- **T1ステージ統合**: 両パイプラインの優先度制御とステート管理を**共通ステートマシン**で統合
- **制御信号の統合**: `t1_r_ready`、`t1_w_ready`によるパイプライン制御の統合

AXIリードライトチャネルの特徴を整理します：

- **リードチャネル**: 読み出しアドレスとバースト情報を伝達
- **ライトチャネル**: 書き込みアドレス、データ、バースト情報を伝達
- **レスポンスチャネル**: 書き込み完了の応答を伝達

リード・ライト独立動作の場合は、第4回と第5回の両方を実装するだけですが、シングルポートのRAMにアクセスする場合は、同一時間でのリード・ライト両方はできないため、順番を決めてRAMにアクセスします。統合ステート管理は第5回のライトのアドレス・データの合流と類似のロジックが使えます。違いは、リードとライトのどちらを優先して、どのような順番で実行するかという点です。

**統合パイプラインの利点**:
- **効率的なリソース利用**: 単一のパイプラインでリード・ライト両方を処理
- **明確な優先度制御**: T1ステージでの統合されたステート管理
- **共通ステートマシン**: Read・Write両方のパイプラインを同一のステートマシンで制御
- **分離された機能**: T1ステージ（ステート制御）とT2ステージ（メモリアクセス）の役割分離
- **統一されたメモリアクセス**: Read・Write両方のT2ステージでメモリアクセスを実現
- **拡張性**: 3段・5段構成による柔軟なパイプライン設計
- **制御の統一**: `t1_r_ready`、`t1_w_ready`による統合制御

## 2. 動作原理

### 2.1 リードライトの合流シナリオ

リードライトの合流は、パイプライン処理においてリードリクエストとライトリクエストが同じパイプラインを通過する現象です。リードライトの合流の実装方法はすでに学んだ第５回のライトのアドレス、データの合流と同様の方法を使用します。

### 2.2 優先順位の調停シナリオ

優先順位の調停は、リードとライトのリクエストが同時に存在する場合に、どちらを優先して処理するかを決定する仕組みです。この調停により、リードとライトの処理順序が制御され、データの整合性が保たれます。

優先順位の調停方式には以下の3種類があります：

- **リード優先方式**: リードリクエストが常にライトリクエストより優先される
- **ライト優先方式**: ライトリクエストが常にリードリクエストより優先される  
- **ラウンドロビン方式（今回採用）**: リードとライトのリクエストを交互に処理する

ラウンドロビン方式では、リードとライトのリクエストを交互に処理します。この方式の特徴は以下の通りです：

- **メリット**: リードとライトの公平性が保たれる、スタベーションが発生しにくい
- **デメリット**: 最適なレイテンシが得られない場合がある
- **適用場面**: バランスの取れた性能が要求されるシステム、リードとライトの処理量が同程度の場合

**今回の実装方針**:
T1ステージで5つのステートを使用して状態管理を行います：

- `STATE_IDLE`: アイドル状態（0: 3'b000）
- `STATE_R_NLAST`: リード実行中（1: 3'b001）
- `STATE_R_LAST`: リード完了（2: 3'b010）
- `STATE_W_NLAST`: ライト実行中（3: 3'b011）
- `STATE_W_LAST`: ライト完了（4: 3'b100）

**パイプライン構成**:
- **Readパイプライン**: 3段構成（T0 → T1 → T2）
  - T0: データ増幅とアドレス生成
  - T1: ステートマシン制御（Read/Write優先度制御）
  - T2: メモリアクセスとデータ出力
- **Writeパイプライン**: 5段構成（T0A → T0D → T1 → T2 → T3）
  - T0A: アドレス生成とバースト制御
  - T0D: データパイプライン処理
  - T1: ステートマシン制御（Read/Write優先度制御）**共通ステートマシン**
  - T2: メモリアクセス（メモリへの書き込み）
  - T3: レスポンス生成
- **統合制御**: T1ステージでの優先度制御とステート管理

**ステートの動作**:

- `STATE_IDLE`: リード・ライトの要求待ち状態
- `STATE_R_NLAST/STATE_R_LAST`: リード実行中・完了状態
- `STATE_W_NLAST/STATE_W_LAST`: ライト実行中・完了状態

**初期値**: 

- `t1_current_state = STATE_IDLE`（アイドル状態として開始）

**優先度制御**:

1. **アイドル状態**: 書き込み要求を優先（`d_w_ready && (w_t0a_valid && w_t0d_valid)`）
2. **リード状態**: 書き込み要求を優先（`d_w_ready && (w_t0a_valid && w_t0d_valid)`）
3. **ライト状態**: リード要求を優先（`d_r_ready && r_t0_valid`）
4. **パイプライン制御**: `d_r_ready`、`d_w_ready`、`t1_r_ready`、`t1_w_ready`が各状態の遷移を制御

この方式により、書き込み優先の制御が実現され、データの整合性が保たれます。

## 3. リードライトが合流するパイプライン

本章では、リードライトが合流するパイプラインの構造について説明します。まず、ReadとWriteの各パイプラインの基本構造を説明し、その後で結合部分の動作について詳しく説明します。

### 3.1 Readパイプライン（第４回のサンプルコードより）

Readパイプラインは3段構成で、データ増幅を行うパイプラインです。

#### T0ステージ（アドレスカウンタとRE制御）
- バースト転送の制御とアドレス生成
- 1つのPayload（アドレス）がバースト回数分に増幅（1→4個に増加）
- 上流に対するReady制御

#### T1ステージ（ステートマシン制御）
- ReadとWriteの優先度制御
- ステート遷移の管理
- 下流のd_Readyで制御される

#### T2ステージ（メモリアクセス）
- メモリからのデータ読み出し
- ステートに応じたデータの有効化
- アドレス値をデータとして出力

**パイプライン構成**:

```
u_r_Payload -> [T0] -> [T1] -> [T2] -> d_r_Payload
                ^       ^       ^
                |       |       |
u_r_Ready   <-[AND]<----+-------+-- <- d_r_Ready
                ^
                |
            [T0_State_Ready]
```

**T1ステージの役割**: ReadとWriteのステートマシン制御
**T2ステージの役割**: メモリアクセスとデータ出力

### 3.2 Writeパイプライン（第５回のサンプルコードより）

Writeパイプラインは5段構成で、2つのペイロードが合流するパイプラインです。

#### T0Aステージ（アドレスカウンタ）
- バースト転送の制御とアドレス生成
- 1つのPayload（アドレス）がバースト回数分に増幅（1→4個に増加）

#### T0Dステージ（データパイプライン）
- データのパイプライン処理
- データ増幅なし（4個維持）

#### T1ステージ（ステートマシン制御）
- ReadとWriteの優先度制御
- ステート遷移の管理

#### T2ステージ（メモリアクセス）
- アドレスとデータの保持
- メモリへの書き込みアクセス

#### T3ステージ（レスポンス生成）
- 書き込み完了の応答生成
- アドレスとデータが一致し、書き込みが有効な場合のみアドレス値をレスポンスとして出力

**パイプライン構成**:

```
u_w_Payload_D=> [T0D]=======++
                 ^          ||
                 |          ||
u_w_Ready_D   <-[AND]---+   ||
                 ^      |   ||
                 |      |   ||
       [T0D_Ready]      |   ||
                        |   ||
u_w_Payload_A=> [T0A] ===> [T1] => [T2] => [T3] => d_w_Payload
                 ^      |   ^       ^       ^   
                 |      |   |       |       |   
u_w_Ready_A   <-[AND]<--+---+-------+-------+--- <- d_w_Ready
                 ^ ^                     
                 | |        
       [T0A_Ready] |        
              [T0A_M_Ready]
```

### 3.3 結合部分の説明

リードライトパイプラインでは、ReadとWriteのパイプラインが合流し、優先順位の調停を行います。

**合流のポイント**:

- Readパイプライン: T0 → T1 → T2 → 出力
- Writeパイプライン: T0A + T0D → T1 → T2 → T3 → 出力（T0AとT0DがT1で合流）
- 両パイプラインがT1ステージで合流

**T1ステージでの結合**:

- T1ステージでリード・ライトの優先度制御を実行（**共通ステートマシン**）
- RE（Read Enable）とWE（Write Enable）は排他的にアサート可能
- 6つの制御信号（`d_r_ready`, `r_t0_valid`, `d_w_ready`, `w_t0a_valid && w_t0d_valid`, `t1_r_ready`, `t1_w_ready`）で状態遷移を制御
- Read・Write両方のパイプラインが同一のT1ステージで統合制御

**優先度制御**:

- T1ステージで5つのステート（`STATE_IDLE`, `STATE_R_NLAST`, `STATE_R_LAST`, `STATE_W_NLAST`, `STATE_W_LAST`）による状態管理
- アイドル状態とリード状態では書き込み要求を優先
- ライト状態ではリード要求を優先
- 各状態で`d_r_ready`と`d_w_ready`によるパイプライン制御

**制御の統合**:

- リードパイプラインは`d_r_ready`と`t1_r_ready`信号で制御
- ライトパイプラインは`d_w_ready`と`t1_w_ready`信号で制御
- T1ステージでステート遷移ロジックを統合管理
- 各ステージの動作はReadyがHの時のみ実行
- if文ベースの優先度制御による明確な制御構造
- 優先度制御信号（`t1_r_ready`, `t1_w_ready`）によるパイプライン制御の統合

## 4. シーケンス - リードとライトが混在するバーストアクセスのシーケンス
```
[Write]-------------------------------------
Clock           : 12345678901234567890123456
w_T0A_Count     : FFFFFFF321033333210FFFFFFF
w_T0A_Valid     : _______HHHHHHHHHHHH_______
w_T0A_Last      : __________H_______H_______
w_T0A_Ready     : HHHHHHH___H_______HHHHHHHH

w_T1_Address    : xxxxxxxx012333334567777xxx
w_T1_Valid      : ________HHHHHHHHHHHH______
w_T1_Last       : ___________H_______H______

[State]-------------------------------------
t1_next_state   : IIIIIIIWWWwRRRrWWWwRRRrIII
t1_current_state: IIIIIIIIWWWwRRRrWWWwRRRrII
t1_w_ready      : HHHHHHHHHHH____HHHH____HHH
t1_r_ready      : HHHHHHH____HHHH____HHHHHHH

[Read]--------------------------------------
r_T0_Count      : FFFFFFF3333321033333210FFF
r_T0_Valid      : _______HHHHHHHHHHHHHHHH___
r_T0_Last       : ______________H_______H___

r_T1_Address    : xxxxxxxx0000012344444567xx
r_T1_Valid      : ________HHHHHHHHHHHHHHHH__
r_T1_Last       : _______________H_______H__
```

## 5. サンプルコード

AIに以下のように指示してコードを作成してください：

```
ここまでのドキュメントの記述を読んで、コードを実装してください。モジュール名はburst_rw_pipeline、ファイル名はburst_rw_pipeline.vとします。2つのソースコードburst_write_pipeline.v、burst_read_pipeline.vを改良して新しいファイルの中に記述して、そこに追加の機能を実装してください。参照する2つのファイルには同じ信号名が出てきますので仕様書を注意深く読んで信号のリネームを行ってください。リードとライトの両方にT1ステージを挿入して、このT1ステージを優先順位の調停に使用します。

テストベンチはburst_read_pipeline_tb.svとburst_write_pipeline_tb.svの構造とテスト内容をそのまま継承してください。
```
### 5.1 リードライトパイプラインモジュール

**サンプルコード**: [burst_rw_pipeline.v](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/burst_rw_pipeline.v)

### 5.2 リードライトパイプラインテストベンチ

**サンプルコード**: [burst_rw_pipeline_tb.v](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/burst_rw_pipeline_tb.v)

## 6. 条件網羅法と条件刈込法

本章の設計において、3つの段階とテクニックが使用されています。

まず、**本質要素抽象化**により、設計箇所をReadとWriteの順番を制御するT1ステートだけに絞り込み、その他のコードはここまでの設計内容を変更せずにそのまま使用しています。

次に、**条件網羅法**でT1ステートで使用する全ての条件、つまりT1のステート、Ready、Validの全組み合わせ表を作成し、casez文で記述します。

最後に、**条件刈込法**で、作成したcasez文を共通項で論理圧縮します。また、最初に行った本質要素抽象化による記述箇所の絞り込みも、条件刈込法でT1ステージのみの設計として抽出しています。

### 6.1 条件網羅法とは

条件網羅法は、ハードウェア設計において、すべての可能な入力条件の組み合わせを網羅的に記述する手法です。この手法により、設計の完全性と動作の正確性を保証することができます。

以下に、最初に条件網羅法で記述したコードを示します。読解するには分かりにくいですが、条件漏れを調べるには、この表のように網羅された記述が有効です。

#### **条件網羅法の特徴**:
- **完全性**: すべての入力条件の組み合わせをテスト
- **網羅性**: 境界値やエッジケースも含む包括的なテスト
- **品質保証**: 設計のバグや不具合を早期発見

#### **適用場面**:
- ステートマシンの状態遷移テスト
- 組み合わせ回路の真理値表検証
- パイプライン制御の動作確認

```verilog
    always @(*) begin
        casez ({t1_current_state, d_r_ready, r_t0_valid, d_w_ready, (w_t0a_valid && w_t0d_valid)})
            // Idle state - no execution
            {STATE_IDLE, 1'b0, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state; 
            {STATE_IDLE, 1'b1, 1'b0, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_IDLE, 1'b0, 1'b?, 1'b1, 1'b0}: t1_next_state = t1_current_state;
            {STATE_IDLE, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = t1_current_state;

            // Read execution from idle (d_r_ready && r_t0_valid)
            {STATE_IDLE, 1'b1, 1'b1, 1'b0, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b0, 1'b1}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            //{STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b1}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                
            // Write execution from idle (d_w_ready && w_t0a_valid && w_t0d_valid)
            {STATE_IDLE, 1'b0, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b0, 1'b1, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b1, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_IDLE, 1'b1, 1'b1, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            // State transitions during execution
            {STATE_R_NLAST, 1'b0, 1'b?, 1'b?, 1'b?}: t1_next_state = t1_current_state;
            {STATE_R_NLAST, 1'b1, 1'b?, 1'b?, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            
            {STATE_W_NLAST, 1'b?, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_W_NLAST, 1'b?, 1'b?, 1'b1, 1'b?}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            // Return to idle after completion
            {STATE_R_LAST, 1'b0, 1'b?, 1'b?, 1'b?}: t1_next_state = t1_current_state;
            {STATE_R_LAST, 1'b1, 1'b0, 1'b0, 1'b?}: t1_next_state = STATE_IDLE;
            {STATE_R_LAST, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_R_LAST, 1'b1, 1'b1, 1'b0, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_R_LAST, 1'b1, 1'b1, 1'b1, 1'b0}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            {STATE_R_LAST, 1'b1, 1'b?, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;

            {STATE_W_LAST, 1'b?, 1'b?, 1'b0, 1'b?}: t1_next_state = t1_current_state;
            {STATE_W_LAST, 1'b0, 1'b?, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_W_LAST, 1'b1, 1'b0, 1'b1, 1'b0}: t1_next_state = STATE_IDLE;
            {STATE_W_LAST, 1'b0, 1'b?, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_W_LAST, 1'b1, 1'b0, 1'b1, 1'b1}: t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            {STATE_W_LAST, 1'b1, 1'b1, 1'b1, 1'b?}: t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;

            default: t1_next_state = 3'bx;
        endcase
    end    
```
### 6.2 条件刈込法とは

条件刈込法は、条件網羅法からさらに分かりやすいコードにするために、共通条件を選び出し、論理圧縮を行います。また、実際の動作に影響しない条件を除外することで、さらにシンプルなコードになります。

この条件刈込法により、アイドル・リード・ライトの3状態があり、それぞれ異なるReady信号で制御されていることが明確に浮き上がってきます。

#### **条件刈込法の特徴**:
- **効率性**: 不要なテストケースを除外
- **実用性**: 実際の動作に影響する条件のみに焦点
- **保守性**: テストケースの管理が容易

#### **適用場面**:
- パイプラインの優先度制御テスト
- バースト転送の制御信号テスト
- リード・ライト統合制御の動作確認

```verilog
// 全状態での全条件の組み合わせ
always @(*) begin
    case (t1_current_state)
        STATE_IDLE: begin
            // 4つの制御信号の全組み合わせ
            if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
            end else if (d_r_ready && r_t0_valid) begin
                t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        STATE_R_NLAST, STATE_R_LAST: begin
            // リード状態での全条件
            if (d_r_ready) begin
                if (d_w_ready && (w_t0a_valid && w_t0d_valid)) begin
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else if (r_t0_valid) begin
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else begin
                    t1_next_state = STATE_IDLE;
                end
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        STATE_W_NLAST, STATE_W_LAST: begin
            // ライト状態での全条件
            if (d_w_ready) begin
                if (d_r_ready && r_t0_valid) begin
                    t1_next_state = (r_t0_last) ? STATE_R_LAST : STATE_R_NLAST;
                end else if ((w_t0a_valid && w_t0d_valid)) begin
                    t1_next_state = (w_t0a_last) ? STATE_W_LAST : STATE_W_NLAST;
                end else begin
                    t1_next_state = STATE_IDLE;
                end
            end else begin
                t1_next_state = t1_current_state;
            end
        end
        
        default: t1_next_state = 3'bx;
    endcase
end
```

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
