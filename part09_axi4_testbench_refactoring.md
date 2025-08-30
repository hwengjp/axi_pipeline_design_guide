# AXIバス設計ガイド 第9回 AXI4バス・テストベンチの機能分類

## 目次

  - [1. はじめに](#1-はじめに)
  - [2. 機能分類によるファイル分割の設計方針](#2-機能分類によるファイル分割の設計方針)
    - [2.1 ファイル分割の基本方針](#21-ファイル分割の基本方針)
    - [2.2 分割ファイルの名称と役割](#22-分割ファイルの名称と役割)
  - [3. 実行時に発生した問題](#3-実行時に発生した問題)
    - [3.1 コード分割時の指示と問題](#31-コード分割時の指示と問題)
    - [3.2 分割と検証のスクリプト](#32-分割と検証のスクリプト)
  - [4. まとめ](#4-まとめ)
    - [4.1 機能分類によるファイル分割](#41-機能分類によるファイル分割)
    - [4.2 段階的リファクタリング](#42-段階的リファクタリング)
    - [4.3 include文による依存関係管理](#43-include文による依存関係管理)
  - [ライセンス](#ライセンス)

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

#### **メインテストベンチ**

`注：このコードは第11回の元になったコードです。現在はエラーで終了します。動作するコードは第11回のコードとなります。`

- **[axi_simple_dual_port_ram_tb_refactored.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_simple_dual_port_ram_tb_refactored.sv)** ← リファクタリングされたメインテストベンチ

#### **共通定義・パラメータ**
- **[axi_common_defs.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_common_defs.svh)** ← 共通定義、パラメータ、typedef

#### **機能別モジュール（always ブロック分割）**
- **[axi_protocol_verification_module.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_protocol_verification_module.sv)** ← プロトコル検証（Payload hold check等）
- **[axi_monitoring_module.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_monitoring_module.sv)** ← モニタリング・ログ出力・テストサマリー
- **[axi_write_channel_control_module.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_write_channel_control_module.sv)** ← Write Channel制御（Address/Data/Response）
- **[axi_read_channel_control_module.sv](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_read_channel_control_module.sv)** ← Read Channel制御（Address/Data）

#### **関数ライブラリ（include 分割）**
- **[axi_utility_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_utility_functions.svh)** ← ユーティリティ関数
- **[axi_random_generation.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_random_generation.svh)** ← 乱数生成関数
- **[axi_stimulus_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_stimulus_functions.svh)** ← テスト刺激生成関数
- **[axi_verification_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_verification_functions.svh)** ← 検証・期待値生成関数
- **[axi_monitoring_functions.svh](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/axi_monitoring_functions.svh)** ← ログ・監視・表示関数

**分割方式**: 初期は`include`による関数分割、後期は`always`ブロックのモジュール分割を実施。TOPレベル信号への直接アクセスにより構造体型不一致エラーを解決。

## 3 実行時に発生した問題

### 3.1 コード分割時の指示と問題

以下のような指示をAIに与えてファイル分割を試みましたができませんでした。
```
提示された分割案に従ってファイルの分割をお願いします。
分割の時の注意点。
・基本的に単純分割してincludeで読み込むだけにしたい。昨日の教訓でパッケージ化はグローバル変数が使用できないので煩雑化する。
・コードは分割するだけで、コメント分以外は削除、変更、追加は一切変更しないでください。
・変更の必要がある場合はまずレポートしてください。
```

Cursorが使用しているAIは関数をファイルAから読み込んで、そのままファイルBに書くということがでないようです。読み込んだ関数を読解して、理解した内容で変換されてちょっと違う関数になります。そのため、AIにファイル分割をさせるという作業は断念して、ファイル分割をするスクリプトを作成させました。

### 3.2 分割と検証のスクリプト

ファイル分割の自動化を実現するため、以下のPythonスクリプトを開発しました：

- **[自動分割スクリプト（auto_split_functions.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/auto_split_functions.py)**: 元のファイルから関数を正確に抽出して、新しいヘッダファイルに自動生成
- **[自動更新スクリプト（auto_update_main_file.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/auto_update_main_file.py)**: メインファイルを自動更新して、分割されたヘッダファイルを使用するように変更
- **[品質保証スクリプト（function_check_list.py）](https://github.com/hwengjp/axi_pipeline_design_guide/blob/main/part09_axi4_testbench_refactoring/function_check_list.py)**: 分割された関数の正確性を自動検証

## 4. まとめ

今回の第9回では、第8回で作成したAXI4バス・テストベンチの機能分類とファイル分割を実現しました。以下、3つの重要な視点から成果をまとめます。

### 4.1 機能分類によるファイル分割

**論理的な機能グループ化の実現**
- **共通定義・パラメータ系**: `axi_common_defs.svh`に集約し、テストベンチ全体で使用される設定値を一元管理
- **テスト刺激生成系**: `axi_stimulus_functions.svh`に集約し、AXI4プロトコルに準拠したテストデータ生成機能を統合
- **検証・期待値生成系**: `axi_verification_functions.svh`に集約し、テスト結果の検証に必要な期待値計算機能を整理
- **ログ・監視系**: `axi_monitoring_functions.svh`に集約し、テスト実行中の状態監視とログ出力機能を統合
- **ユーティリティ関数系**: `axi_utility_functions.svh`に集約し、汎用的なヘルパー関数を整理

**モジュール分割による高度な構造化**
- **プロトコル検証モジュール**: AXI4プロトコル準拠性の検証機能を独立したモジュールとして分離
- **チャネル制御モジュール**: Write/Read Channel制御を独立したモジュールとして分離し、状態管理の独立性を確保
- **モニタリングモジュール**: ログ出力とテストサマリー機能を独立したモジュールとして分離

**単一責任の原則の適用**
各ファイルが明確な責任を持つことで、コードの可読性と保守性が大幅に向上しました。開発者が特定の機能を修正する際、関連するファイルのみを確認すれば良くなり、開発効率が向上しています。

### 4.2 段階的リファクタリング

**リスク最小化アプローチ**
- **Phase 1**: 共通定義の分離により、パラメータ管理の基盤を確立
- **Phase 2**: テスト刺激生成関数の分離により、テストデータ生成の独立性を確保
- **Phase 3**: 検証・期待値生成関数の分離により、テスト結果検証の信頼性を向上
- **Phase 4**: ログ・監視機能の分離により、デバッグ・トラブルシューティングの効率化
- **Phase 5**: ユーティリティ関数の分離により、再利用可能な機能の整理
- **Phase 6**: モジュール分割による高度なリファクタリングにより、`always`ブロックの独立性を確保

**自動化による品質保証**
Pythonスクリプトによる自動分割により、手動作業によるエラーを排除し、100%の正確性を実現しました。`function_check_list.py`による自動検証により、分割前後の機能同一性を保証しています。

### 4.3 include文による依存関係管理

**シンプルな依存関係の実現**
- **パッケージ化の回避**: 複雑なスコープルールやパラメータ引き渡しの問題を回避
- **include文による直接参照**: 必要な機能を必要な場所で直接参照できるシンプルな構造
- **依存関係の可視化**: ファイルの先頭でinclude文を確認することで、依存関係が一目で分かる

**保守性と再利用性の向上**
- **設定変更の容易性**: 共通パラメータの変更が一箇所で済み、全体への影響を最小限に抑制
- **機能追加の簡素化**: 新しい機能を適切なファイルに追加するだけで、既存機能への影響なし
- **他プロジェクトでの再利用**: 分割されたファイルを他のAXI4テストベンチプロジェクトで直接利用可能

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
