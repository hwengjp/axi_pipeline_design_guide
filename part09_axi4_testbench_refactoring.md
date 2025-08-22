# AXIバスのパイプライン回路設計ガイド ～ 第9回 AXI4バス・テストベンチの機能分類

## 目次

- [AXIバスのパイプライン回路設計ガイド ～ 第9回 AXI4バス・テストベンチの機能分類](#axiバスのパイプライン回路設計ガイド--第9回-axi4バス・テストベンチの機能分類)
  - [目次](#目次)
  - [1. はじめに](#1-はじめに)
  - [2. 機能分類によるファイル分割の設計方針](#2-機能分類によるファイル分割の設計方針)
    - [2.1 ファイル分割の基本方針](#21-ファイル分割の基本方針)
    - [2.2 分割対象の機能分類](#22-分割対象の機能分類)
      - [2.2.1 共通定義・パラメータ系](#221-共通定義・パラメータ系)
      - [2.2.2 テスト刺激生成系](#222-テスト刺激生成系)
      - [2.2.3 検証・期待値生成系](#223-検証・期待値生成系)
      - [2.2.4 ログ・監視系](#224-ログ・監視系)
      - [2.2.5 ユーティリティ関数系](#225-ユーティリティ関数系)
  - [3. 段階的なファイル分割実装](#3-段階的なファイル分割実装)
    - [3.1 Phase 1: 共通定義の分離](#31-phase-1-共通定義の分離)
    - [3.2 Phase 2: テスト刺激生成関数の分離](#32-phase-2-テスト刺激生成関数の分離)
    - [3.3 Phase 3: 検証・期待値生成関数の分離](#33-phase-3-検証・期待値生成関数の分離)
    - [3.4 Phase 4: ログ・監視機能の分離](#34-phase-4-ログ・監視機能の分離)
    - [3.5 Phase 5: ユーティリティ関数の分離](#35-phase-5-ユーティリティ関数の分離)
  - [4. ファイル分割の実装例](#4-ファイル分割の実装例)
    - [4.1 共通定義ファイル（axi_common_defs.svh）](#41-共通定義ファイルaxi_common_defssvh)
    - [4.2 テスト刺激生成ファイル（axi_stimulus_functions.svh）](#42-テスト刺激生成ファイルaxi_stimulus_functionssvh)
    - [4.3 検証・期待値生成ファイル（axi_verification_functions.svh）](#43-検証・期待値生成ファイルaxi_verification_functionssvh)
    - [4.4 ログ・監視ファイル（axi_monitoring_functions.svh）](#44-ログ・監視ファイルaxi_monitoring_functionssvh)
    - [4.5 ユーティリティ関数ファイル（axi_utility_functions.svh）](#45-ユーティリティ関数ファイルaxi_utility_functionssvh)
  - [5. メインテストベンチファイルの整理](#5-メインテストベンチファイルの整理)
    - [5.1 include文の追加](#51-include文の追加)
    - [5.2 関数定義の削除](#52-関数定義の削除)
    - [5.3 依存関係の整理](#53-依存関係の整理)
  - [6. コンパイル・シミュレーション環境の調整](#6-コンパイル・シミュレーション環境の調整)
    - [6.1 .doファイルの更新](#61-doファイルの更新)
    - [6.2 コンパイル順序の最適化](#62-コンパイル順序の最適化)
    - [6.3 エラーハンドリングの改善](#63-エラーハンドリングの改善)
  - [7. 動作確認とテスト](#7-動作確認とテスト)
    - [7.1 分割前後の動作比較](#71-分割前後の動作比較)
    - [7.2 各機能の独立性確認](#72-各機能の独立性確認)
    - [7.3 パラメータ変更による動作確認](#73-パラメータ変更による動作確認)

  - [ライセンス](#ライセンス)

---

## 1. はじめに

このドキュメントは、第8回で作成したAXI4バス・テストベンチのコードを、機能毎にファイルを分けて汎用化することを目的としています。

第8回では、テストベンチの本質要素を抽象化し、包括的な設計を行いました。しかし、単一ファイルに全ての機能が集約されているため、コードの可読性や保守性に課題がありました。

第9回では、これらの課題を解決するため、以下の方針でファイル分割を実施します：

1. **機能分類による論理的な分割**: 関連する機能をグループ化して適切なファイルに分離
2. **include文による依存関係管理**: 複雑なパッケージ化を避け、シンプルなinclude文でファイル間の関係を管理
3. **段階的な移行**: リスクを最小化するため、段階的にファイル分割を実施
4. **汎用化の実現**: 分割されたファイルを他のプロジェクトでも再利用可能な形で整理

このアプローチにより、コードの保守性と再利用性を大幅に向上させ、今後の開発効率の向上を目指します。

## 2. 機能分類によるファイル分割の設計方針

### 2.1 ファイル分割の基本方針

ファイル分割の基本方針として、以下の原則を設定します：

#### **分割の原則**
1. **単一責任の原則**: 各ファイルは一つの明確な責任を持つ
2. **依存関係の最小化**: ファイル間の依存関係を最小限に抑制
3. **再利用性の最大化**: 分割されたファイルを他のプロジェクトでも使用可能
4. **保守性の向上**: 機能の追加・修正が容易な構造

#### **ファイル命名規則**
- **拡張子**: `.svh`（SystemVerilog Header）を使用
- **命名**: `axi_[機能名]_[用途].svh`の形式
- **例**: `axi_common_defs.svh`, `axi_stimulus_functions.svh`

### 2.2 分割ファイルの名称と役割
[axi_simple_dual_port_ram_tb.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_simple_dual_port_ram_tb.sv)              ← 既存ファイル（変更なし）
[axi_simple_dual_port_ram_tb_refactored.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_simple_dual_port_ram_tb_refactored.sv)   ← 新規作成（include文で分割ファイルを統合）
├── [axi_common_defs.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_common_defs.svh)                     ← 共通定義
├── [axi_utility_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_utility_functions.svh)               ← ユーティリティ関数
├── [axi_random_generation.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_random_generation.svh)               ← 乱数生成
├── [axi_stimulus_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_stimulus_functions.svh)              ← テスト刺激生成
├── [axi_verification_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_verification_functions.svh)          ← 検証・期待値生成
└── [axi_monitoring_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/axi_monitoring_functions.svh)            ← ログ・監視・表示

### 2.3 分割と検証のスクリプト

ファイル分割の自動化を実現するため、以下のPythonスクリプトを開発しました：

- **[自動分割スクリプト（auto_split_functions.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/auto_split_functions.py)**: 元のファイルから関数を正確に抽出して、新しいヘッダファイルに自動生成
- **[自動更新スクリプト（auto_update_main_file.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/auto_update_main_file.py)**: メインファイルを自動更新して、分割されたヘッダファイルを使用するように変更
- **[品質保証スクリプト（function_check_list.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/function_check_list.py)**: 分割された関数の正確性を自動検証

### 2.4 実行時に発生した問題

以下のような指示をAIに与えてファイル分割を試みましたができませんでした。
'''
分割の時の注意点。
・基本的に単純分割してincludeで読み込むだけにしたい。昨日の教訓でパッケージ化はグローバル変数が使用できないので煩雑化する。
・コードは分割するだけで、コメント分以外は削除、変更、追加は一切変更しないでください。
・変更の必要がある場合はまずレポートしてください。
'''

Cursorが使用しているAIは関数をファイルAから読み込んで、そのままファイルBに書くということができません。読み込んだ関数を読解して、理解した内容で変換されてちょっと違う関数になります。そのため、AIにファイル分割をさせるという作業は断念して、ファイル分割をするスクリプトを作成させました。

### 3 まとめ







---

## ライセンス

このドキュメントは、MITライセンスの下で公開されています。

Copyright (c) 2024 AXI Pipeline Design Guide

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
