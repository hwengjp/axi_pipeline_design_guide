# AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプランAXIデータチャネルの模擬

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第４回 データがN倍に増えるパイプランAXIデータチャネルの模擬](#axiバスのパイプライン回路設計ガイド--第４回-データがn倍に増えるパイプランaxiデータチャネルの模擬)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 動作原理](#2-動作原理)
    - [2.1 データ増幅とは](#21-データ増幅とは)
    - [2.2 通常のReadyのシーケンス](#22-通常のreadyのシーケンス)
    - [2.3 Payloadが４つに増える場合のシーケンス](#23-payloadが４つに増える場合のシーケンス)
      - [パイプライン構成](#パイプライン構成)
  - [3. サンプルコード](#3-サンプルコード)
  - [4. テストベンチの設計と実装](#4-テストベンチの設計と実装)
  - [5. シミュレーション結果の分析](#5-シミュレーション結果の分析)
  - [6. 実用的な応用例](#6-実用的な応用例)
  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントはAIに読み込ませてコードを自動生成することを目標としています。

本記事では、パイプラン処理においてデータがN倍に増える場合のAXIデータチャネルの動作を模擬します。前回までに学んだパイプラン処理の基本概念を応用し、実際のハードウェア設計でよく遭遇する「バーストアクセス」シナリオを扱います。

バーストアクセスは、1つのアドレスリクエストに対して複数のデータ応答が返されるシナリオです。パイプランの途中で1つのペイロード（アドレスに対するデータ）がバースト回数分に膨らみます。このような状況では、ペイロードの個数が増えるパイプラインステージより上流のパイプラインを停止して待機させる必要があります。できるだけ無駄なサイクルが発生しない実装を考えます。

## 2. 動作原理

### 2.1 データ増幅とは

データ増幅とは、パイプラン処理において1つの入力データが複数の出力データに変換される現象です。特に**バーストアクセス**では、1つのリクエストに対して複数のデータ応答が返されます：

### 2.2 通常のReadyのシーケンス

第１回で学んだReadyのシーケンスをおさらいしましょう。
シーケンスチャートを簡便にするためにデータもアドレスもPayloadと呼ぶことにします。
ReadyがHの時はデータを受信し、ReadyがLの時はパイプラインは停止（ストール）します。ValidがHの時はデータが有効、ValidがLの時はデータは無効です。
```
Clock    : 123456789012345678
Payload  : xxxxxx0001222345xx
Valid    : ______HHHHHHHHHH__
Ready    : HHHHHH__HH__HHHHHH
```
下の図は４段パイプラインです。上で説明したReadyとValidのルールはパイプラインのどこを輪切りにしても同じルールになっています。
```
Payload -> [T0] -> [T1] -> [T2] -> [T3] -> Payload
            |       |       |       |
Ready   <- -+-------+-------+-------+-- <- Ready
```

### 2.3 Payloadが４つに増える場合のシーケンス

ペイロードが４つに増えるシナリオつまり、バースト長４のリードシーケンスを考えてみます。

#### パイプライン構成

T0はアドレスをカウントする回路。ここで上流に対するReadyの制御を行います。T2は下流のd_readyで制御されると同時に、上流に対するu_Readyを生成します。u_Readyは今までのルールであるd_ReadyがU_Readyに非同期でつながる回路に、T0でバースト中に待たせるためのT0_Readyを非同期で論理ANDした信号です。T0_ReadyはT0ステージで同期回路で生成します。
T1はメモリです。Read Enableとアドレスをラッチして次のクロックでデータを出力します。T1は下流のd_Readyで制御されます。
```
u_Payload -> [T0] -> [T1] -> d_Payload
              ^       ^   
              |       |   
u_Ready   <- [OR]<----+-- <- d_Ready
              ^                    
              |
          [T0_Ready]
```
| 段階 | 機能 | 説明 | データ増幅 |
|------|------|------|------------|
| T0 | アドレスカウンタとRE | バースト転送の制御とアドレス生成 | **1→４個に増加** |
| T1 | メモリアクセス| メモリからのデータ読み出し | 3個維持 |

#### バースト長４、d_readyがH のシーケンス

アドレスは0から+4インクリメントで送られて、T0でAddress~Address+3の4つのアクセスを生成します。
Lengthはバースト長-1の値です。下流からくるd_readyはHの場合です。

T0_Stateは４つのステートで管理されます。
初期値はステート=アイドル、T0_Count=F、T0_Mem_Adr=0、T0_Mem_RE=L、T0_LAST=L、T0_Ready=H、です。
0:アイドル：T0_Count=Fの時。T0_u_Ready && T0_u_ValidでAddressとLengthからT0_Count、T0_Mem_Adr、T0_Mem_REを生成します。
生成時の値は、T0_CountはLengthの値、T0_Mem_AdrはAddressの値、T0_Mem_RE=H、T0_LASTはLengthが0ならHそれ以外の時L、T0_ReadyはLengthが0ならHそれ以外の時Lです。
1:バースト中　：T0_CountがFと0以外の時
2:最終サイクル：T0_Countが0の時
```
Clock       : 123456789012345678901
Address     : xxxxxx044448888xxxxxx
Length      : xxxxxx333333333xxxxxx
Valid       : ______HHHHHHHHHHHH___
Ready       : HHHHHHH___H___H___HHH

T0_State    : 000000011121112111200
T0_Count    : FFFFFFF321032103210FF
T0_Mem_Adr  : xxxxxxx0123456789ABxx
T0_Mem_RE   : _______HHHHHHHHHHHH__
T0_Valid    : _______HHHHHHHHHHHH__
T0_Last     : __________H___H___H__
T0_Ready    : HHHHHHH___H___H___HHH
T0_u_Ready  : HHHHHHH___H___H___HHH
T0_d_Ready  : HHHHHHHHHHHHHHHHHHHHH

T1_Data     : _______0123456789AB__
T1_Valid    : _______HHHHHHHHHHHH__
T1_Last     : __________H___H___H__
T1_u_Ready  : HHHHHHHHHHHHHHHHHHHHH
T1_d_Ready  : HHHHHHHHHHHHHHHHHHHHH
```

#### バースト長４、d_readyがトグルするシーケンス
T0とT1はどちらもd_Ready(=T1_d_Ready=T1_u_Ready=T0_d_Ready)で論理全体のイネーブル制御を行います。T0_Readyもこの_Readyでイネーブル制御されます。

```
Clock       : 123456789012345678901234567890123456
Address     : xxxxxx044444444888888888xxxxxxxxxxxx
Length      : xxxxxx333333333333333333xxxxxxxxxxxx
Valid       : ______HHHHHHHHHHHHHHHHHH____________
Ready       : HHHHHHH_______H________H_______HHHHH

T0_Count    : FFFFFFF3322110033322110033221100FFFF
T0_Mem_Adr  : xxxxxxx001122334445566778899AABBxxxx
T0_Mem_RE   : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Valid    : _______HHHHHHHHHHHHHHHHHHHHHHHHH____
T0_Last     : _____________HH_______HH______HH____
T0_Ready    : HHHHHHH______HH_______HH______HHHHHH
T0_u_Ready  : HHHHHHH_______H________H_______HHHHH
T0_d_Ready  : HHHHHHH_H_H_H_H__H_H_H_H_H_H_H_HHHHH

T1_Data     : xxxxxxxxx001122333445566778899AABB__
T1_Valid    : _________HHHHHHHHHHHHHH_____________
T1_Last     : _______________HHH______HH______HH__
T1_u_Ready  : HHHHHHH_H_H_H_H__H_H_H_H_H_H_H_H_HHH
T1_d_Ready  : HHHHHHH_H_H_H_H__H_H_H_H_H_H_H_H_HHH
```

## 3. サンプルコード

以下の指示でコードとテストベンチを生成します。
```
メモリはリードのみ、レイテンシ１、出力のデータ＝アドレスとします。パイプラインの入力アドレスとメモリのアドレスは同じとします。
このドキュメントを読んでコードを生成してください。

テストベンチも実装お願いします。テストベンチはpipeline_tb.svを参考にしてください。
```
ここまでの説明を読み込ませてAIに自動生成させたコードです。たった２段のパイプラインですので非常ににシンプルです。
このコードはアドレスチャネルと、データチャネルが合体しています。分離する方法として例えば、pipeline_insertモジュールをアドレスチャネルとする方法もあるでしょうし、アドレスチャネルとしてFIFOを使う方法もあるでしょう。

```systemverilog
// 拡張されたAXIデータチャネル
typedef struct packed {
    logic [31:0] data;      // データ
    logic [3:0]  id;        // ID
    logic [3:0]  dest;      // 宛先
    logic        last;       // 最後のデータ
    logic [1:0]  count;     // データ数（増幅時）
} axi_data_t;
```
## 4. 実行用スクリプトの生成

シミュレータのコンパイル・実行スクリプトは以下のように指示して自動生成させます
```
modelsim用にコンパイルと実行を行うスクリプトを作成してください。スクリプト名はテストベンチ名に合わせます。
```

## ライセンス

このプロジェクトは [Apache License 2.0](LICENSE) の下で公開されています。 