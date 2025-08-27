# AXI4 SIZE制約の分析と修正要件

## 概要

ARM公式仕様書「IHI0022B_AMBAaxi.txt」の確認結果に基づき、PART11のAXI4テストベンチ実装におけるSIZE制約の問題点と修正要件を整理します。

## 1. ARM公式仕様書での確認結果

### 1.1 基本仕様

#### Chapter 4.3「Burst size」
- **転送サイズ**: 各転送のバイト数（1〜128バイト）を指定
- **バス幅制約**: 「転送サイズはバス幅を超えてはいけないが、小さい分には問題ない」
- **明記**: "The size of any transfer must not exceed the data bus width of the components in the transaction."

#### Chapter 9.3「Narrow transfers」
- **部分転送**: 転送サイズがバス幅より小さい場合の処理
- **バイトレーン制御**: アドレスと制御情報による使用バイトレーンの決定
- **図解例**: 8ビット転送を32ビットバスで行うケース

#### Chapter 2.2/2.5「Signal Descriptions」
- **SIZE信号**: バーストサイズは8〜1024ビット（1〜128バイト）
- **範囲**: バス幅より小さいサイズも含む

### 1.2 技術的な動作

#### WSTRB（ライトストローブ）の役割
- **有効バイト指定**: 使用するバイトの明示
- **部分書き込み**: バス幅の一部のみを使用した転送
- **アドレスアライメント**: 正しい境界でのアクセス

#### バースト転送での動作
- **各ビート**: 異なるバイトレーンの使用
- **アドレス計算**: SIZEに基づく適切な増分
- **一貫性**: バースト中のSIZE変更なし

## 2. 現在の実装の問題点

### 2.1 SIZE生成の制限

#### 現在の実装
```systemverilog
// ❌ 間違い: バースト転送でSIZEを固定
if (selected_length > 0) begin
    // Burst access (LEN > 0): SIZE fixed to bus width for efficiency
    selected_size = $clog2(AXI_DATA_WIDTH / 8);  // 固定
end else begin
    // Single access (LEN = 0): Random SIZE for flexibility
    selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));
end
```

#### 問題点
- **バースト転送**: SIZEが固定（柔軟性なし）
- **単一転送**: SIZEがランダム（柔軟性あり）
- **仕様違反**: バースト転送でもSIZE < バス幅が可能なのに制限

### 2.2 アドレス境界の丸め処理が不十分

#### 現在の実装
```systemverilog
// ❌ 不十分: バス幅境界での丸めのみ
int addr_offset = address % bus_width_bytes;
```

#### 必要な処理
```systemverilog
// ✅ 正しい: SIZEに基づくアドレス境界の丸め
function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_to_size_boundary(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size
);
    int size_bytes = size_to_bytes(size);
    // SIZEに基づく境界での丸め
    return (address / size_bytes) * size_bytes;
endfunction
```

### 2.3 有効バイト位置の計算が不正確

#### 現在の問題
- **SIZE=0（1バイト）**: アドレスの下位ビットでバイト位置決定
- **SIZE=1（2バイト）**: アドレスの下位1ビットで2バイト境界決定
- **SIZE=2（4バイト）**: アドレスの下位2ビットで4バイト境界決定

#### 正確な計算が必要
```systemverilog
// ✅ 正しい: SIZEに基づく有効バイト位置の計算
function automatic logic [AXI_STRB_WIDTH-1:0] calculate_strobe_by_size_and_address(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input int bus_width_bytes
);
    logic [AXI_STRB_WIDTH-1:0] strobe = '0;
    int size_bytes = size_to_bytes(size);
    
    // SIZEに基づくアドレス境界での丸め
    int aligned_addr = (address / size_bytes) * size_bytes;
    
    // 丸められたアドレスと元のアドレスの差分
    int offset = address - aligned_addr;
    
    // 有効バイト位置の計算
    for (int byte_idx = 0; byte_idx < size_bytes; byte_idx++) begin
        int strobe_pos = offset + byte_idx;
        if (strobe_pos < bus_width_bytes) begin
            strobe[strobe_pos] = 1'b1;
        end
    end
    
    return strobe;
endfunction
```

## 3. バースト実装の根本的な問題

### 3.1 現在の実装の問題

#### 誤ったアドレス増分
```systemverilog
// ❌ 間違い: ワードアドレスでのインクリメント
r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);  // 例: 4バイト増加
w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8); // 例: 4バイト増加
```

#### 問題の詳細
- **現在の実装**: バーストの各ビートでワードアドレス（4バイト）をインクリメント
- **正しい仕様**: バーストの各ビートでバイトアドレスをSIZEで指定されたバイト数だけカウントアップ
- **影響**: アドレス計算が不正確、メモリアクセスが間違った位置になる

### 3.2 正しい実装の要件

#### AXI4仕様でのバースト転送
```systemverilog
// ✅ 正しい: SIZEに基づくバイトアドレスの増分
r_t0_addr <= r_t0_addr + size_to_bytes(r_t0_size);
w_t0a_addr <= w_t0a_addr + size_to_bytes(w_t0a_size);
```

#### 具体的な例
- **SIZE=0（1バイト）**: アドレス +1 バイト
- **SIZE=1（2バイト）**: アドレス +2 バイト  
- **SIZE=2（4バイト）**: アドレス +4 バイト
- **SIZE=3（8バイト）**: アドレス +8 バイト

### 3.3 実装への影響

#### メモリアクセスの正確性
- **現在**: 4バイト境界でのみアクセス（柔軟性なし）
- **修正後**: SIZEに基づく任意のバイト境界でのアクセス（柔軟性あり）

#### バースト転送の効率性
- **現在**: 常にフルバス幅使用（無駄な転送の可能性）
- **修正後**: SIZEに基づく必要最小限の転送（効率的）

#### テストの網羅性
- **現在**: 限定的なアドレスパターンのみテスト
- **修正後**: 様々なSIZEとアドレスパターンのテストが可能

### 3.4 修正の優先度

この問題は、STROBE生成の問題よりも**根本的で重要**です：

1. **最優先**: バースト内アドレス計算の修正
2. **次優先**: STROBE生成の修正
3. **最後**: その他の最適化

## 4. AXI4 WRAPバーストの仕様詳細

### 4.1 WRAPバーストの定義（Chapter 4.4.3）

WRAPバーストは、アドレスが一定の境界を超えると、下位アドレスに巻き戻る（wrap）動作をします。

各転送のアドレスは、前の転送のアドレス + 転送サイズ（Number_Bytes）で計算されますが、Wrap_Boundaryを超えると、アドレスが境界の先頭に戻ります。

#### ✅ WRAPバーストの制約
- **開始アドレス**: 転送サイズにアラインされている必要がある
- **バースト長**: 2, 4, 8, 16 のいずれかでなければならない
- **Wrap_Boundary**: Number_Bytes × Burst_Length

**例**: 転送サイズが4バイト、バースト長が4なら、Wrap_Boundaryは16バイト

### 4.2 WRAP時のアドレス計算式（Chapter 4.5）

仕様書では以下のような式が提示されています：

```
Wrap_Boundary = INT(Start_Address / (Number_Bytes × Burst_Length)) × (Number_Bytes × Burst_Length)
Address_N = Wrap_Boundary + ((Start_Address + (N – 1) × Number_Bytes) MOD (Number_Bytes × Burst_Length))
```

この式により、N番目の転送アドレスがWrap_Boundaryを超えると、MOD演算によってアドレスが境界内に巻き戻されます。

### 4.3 WRAPバーストの図解例（Chapter 10.2）

仕様書の Figure 10-3 に、64ビットバス上でのWRAPバーストの例が示されています：

- **開始アドレス**: 0x04
- **転送サイズ**: 32ビット（4バイト）
- **バースト長**: 4
- **バーストタイプ**: WRAP

この例では、転送が進むにつれてアドレスが増加し、4回目の転送でアドレスがWrap_Boundaryに戻る様子が図で示されています。

### 4.4 技術的な意味合い

WRAPバーストは主に以下の用途で使われます：

- **キャッシュラインのフェッチ**: 例：128バイトのキャッシュラインを16回の8バイト転送で取得
- **リングバッファのような構造へのアクセス**: アドレス境界を越えない連続アクセスの最適化
- **メモリ効率の向上**: 境界内での連続アクセスによる最適化

### 4.5 実装上の注意点

#### 開始アドレスのアライメントチェック
```verilog
// 開始アドレスがSIZEにアラインされているかチェック
if (axi_ar_addr % size_to_bytes(axi_ar_size) != 0) begin
    $error("WRAP burst: Start address not aligned to transfer size");
    $finish;
end
```

#### バースト長の制約チェック
```verilog
// バースト長が2, 4, 8, 16のいずれかかチェック
if (!((axi_ar_len + 1) inside {2, 4, 8, 16})) begin
    $error("WRAP burst: Burst length must be 2, 4, 8, or 16");
    $finish;
end
```

#### アドレス計算の実装
```verilog
// AXI4仕様書準拠のWRAP実装
r_t0_addr <= axi_ar_addr + ((r_t0_addr - axi_ar_addr + size_to_bytes(r_t0_size)) % (size_to_bytes(r_t0_size) * (axi_ar_len + 1)));
```

## 6. burst_config_weightsの設計と実装

### 6.1 現在の実装

#### 既存のburst_config_weights構造
```systemverilog
// 現在の実装（strobe_strategy使用）
typedef struct {
    int weight;
    int length_min;
    int length_max;
    string burst_type;
    string strobe_strategy;  // 現在はstrobe_strategy
} burst_config_t;

// 設定例
burst_config_t burst_config_weights[] = '{
    '{weight: 4, length_min: 1, length_max: 3, burst_type: "INCR", strobe_strategy: "FULL"},
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR", strobe_strategy: "RANDOM"},
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "WRAP", strobe_strategy: "FULL"},
    '{weight: 2, length_min: 0, length_max: 0, burst_type: "FIXED", strobe_strategy: "FULL"}
};
```

### 6.2 修正後の実装

#### size_strategyへの変更
```systemverilog
// 修正後の実装（size_strategy使用）
typedef struct {
    int weight;
    int length_min;
    int length_max;
    string burst_type;
    string size_strategy;  // strobe_strategyからsize_strategyに変更
} burst_config_t;

// 修正後の設定例
burst_config_t burst_config_weights[] = '{
    '{weight: 4, length_min: 1, length_max: 3, burst_type: "INCR", size_strategy: "FULL"},
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR", size_strategy: "RANDOM"},
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "WRAP", size_strategy: "FULL"},
    '{weight: 2, length_min: 0, length_max: 0, burst_type: "FIXED", size_strategy: "FULL"}
};
```

### 6.3 size_strategyの動作

#### FULL戦略
```systemverilog
// FULL戦略: バス幅とSIZE一致
if (size_strategy == "FULL") begin
    // バス幅に一致するSIZEを設定
    selected_size = $clog2(AXI_DATA_WIDTH / 8);
    
    // 例: 64ビットバス → SIZE = 3 (8バイト)
    // 例: 32ビットバス → SIZE = 2 (4バイト)
    
    // アドレス丸め: バス幅境界での丸め
    aligned_addr = (address / bus_width_bytes) * bus_width_bytes;
    
    // バイト位置: 全ビット有効
    strobe = '1;  // 全ビット1
end
```

#### RANDOM戦略
```systemverilog
// RANDOM戦略: バス幅以下でSIZEの乱数発生
if (size_strategy == "RANDOM") begin
    // バス幅以下の範囲でSIZEをランダム選択
    selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));
    
    // 制約チェック: SIZEはバス幅以下である必要
    if (size_to_bytes(selected_size) > AXI_DATA_WIDTH / 8) begin
        $error("SIZE constraint violation: SIZE %0d exceeds bus width %0d bytes", 
               size_to_bytes(selected_size), AXI_DATA_WIDTH / 8);
        $finish;
    end
    
    // アドレス丸め: SIZEに基づく境界での丸め
    int size_bytes = size_to_bytes(selected_size);
    aligned_addr = (address / size_bytes) * size_bytes;
    
    // バイト位置: SIZEとアドレスに基づく計算
    strobe = calculate_strobe_by_size_and_address(address, selected_size, AXI_DATA_WIDTH);
end
```

### 6.4 実装の詳細

#### SIZE生成関数
```systemverilog
// SIZE生成関数（size_strategy対応）
function automatic logic [2:0] generate_size_by_strategy(
    input string size_strategy,
    input int bus_width_bits
);
    int bus_width_bytes = bus_width_bits / 8;
    
    case (size_strategy)
        "FULL": begin
            // バス幅に一致するSIZE
            return $clog2(bus_width_bytes);
        end
        "RANDOM": begin
            // バス幅以下の範囲でランダム
            return $urandom_range(0, $clog2(bus_width_bytes));
        end
        default: begin
            // デフォルトはFULL
            return $clog2(bus_width_bytes);
        end
    endcase
endfunction
```

#### アドレス丸め関数
```systemverilog
// アドレス丸め関数（SIZE対応）
function automatic logic [AXI_ADDR_WIDTH-1:0] align_address_by_size(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input string size_strategy
);
    case (size_strategy)
        "FULL": begin
            // バス幅境界での丸め
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            return (address / bus_width_bytes) * bus_width_bytes;
        end
        "RANDOM": begin
            // SIZEに基づく境界での丸め
            int size_bytes = size_to_bytes(size);
            return (address / size_bytes) * size_bytes;
        end
        default: begin
            // デフォルトはバス幅境界
            int bus_width_bytes = AXI_DATA_WIDTH / 8;
            return (address / bus_width_bytes) * bus_width_bytes;
        end
    endcase
endfunction
```

#### STROBE生成関数
```systemverilog
// STROBE生成関数（SIZE対応）
function automatic logic [AXI_STRB_WIDTH-1:0] generate_strobe_by_size_strategy(
    input logic [AXI_ADDR_WIDTH-1:0] address,
    input logic [2:0] size,
    input string size_strategy,
    input int bus_width_bits
);
    case (size_strategy)
        "FULL": begin
            // 全ビット有効
            return '1;
        end
        "RANDOM": begin
            // SIZEとアドレスに基づく計算
            return calculate_strobe_by_size_and_address(address, size, bus_width_bits);
        end
        default: begin
            // デフォルトは全ビット有効
            return '1;
        end
    endcase
endfunction
```

## 7. 具体的な動作例

### 7.1 SIZE=0（1バイト）の場合

#### アドレス0x01（64ビットバス）
```verilog
// アドレス境界: 丸めなし（1バイト単位）
aligned_addr = 0x01;  // 丸めなし
offset = 0x01 - 0x01 = 0;

// 有効バイト位置: bit8~15（アドレス0x01に対応）
strobe = 8'b0000_0010;  // bit1のみ1
```

#### アドレス0x02（64ビットバス）
```verilog
// アドレス境界: 丸めなし（1バイト単位）
aligned_addr = 0x02;  // 丸めなし
offset = 0x02 - 0x02 = 0;

// 有効バイト位置: bit16~23（アドレス0x02に対応）
strobe = 8'b0000_0100;  // bit2のみ1
```

### 7.2 SIZE=1（2バイト）の場合

#### アドレス0x01（64ビットバス）
```verilog
// アドレス境界: 2バイト境界で丸め
aligned_addr = (0x01 / 2) * 2 = 0x00;  // 下位1ビットを丸め
offset = 0x01 - 0x00 = 1;

// 有効バイト位置: bit8~15（2バイト連続）
strobe = 8'b0000_0011;  // bit0,1が1
```

#### アドレス0x02（64ビットバス）
```verilog
// アドレス境界: 2バイト境界で丸め
aligned_addr = (0x02 / 2) * 2 = 0x02;  // 下位1ビットを丸め
offset = 0x02 - 0x02 = 0;

// 有効バイト位置: bit16~23（2バイト連続）
strobe = 8'b0000_1100;  // bit2,3が1
```

### 7.3 SIZE=2（4バイト）の場合

#### アドレス0x01（64ビットバス）
```verilog
// アドレス境界: 4バイト境界で丸め
aligned_addr = (0x01 / 4) * 4 = 0x00;  // 下位2ビットを丸め
offset = 0x01 - 0x00 = 1;

// 有効バイト位置: bit8~31（4バイト連続）
strobe = 8'b0000_1111;  // bit0,1,2,3が1
```



## 8. 修正が必要な実装箇所

### 8.1 SIZE生成の修正

```systemverilog
// ✅ 正しい実装: size_strategyに基づくSIZE生成
selected_size = generate_size_by_strategy(burst_cfg.size_strategy, AXI_DATA_WIDTH);

// 制約: SIZEはバス幅以下である必要
if (size_to_bytes(selected_size) > AXI_DATA_WIDTH / 8) begin
    $error("SIZE constraint violation: SIZE %0d exceeds bus width %0d bytes", 
           size_to_bytes(selected_size), AXI_DATA_WIDTH / 8);
    $finish;
end
```

### 8.2 アドレス境界の丸め処理

```systemverilog
// 現在の不十分な実装
int addr_offset = address % bus_width_bytes;

// 修正後の正しい実装
int aligned_addr = align_address_by_size(address, selected_size, burst_cfg.size_strategy);
int offset = address - aligned_addr;
```

### 8.3 STROBE生成の修正

```systemverilog
// 現在の不正確な実装
for (int byte_idx = 0; byte_idx < min_required_bytes && byte_idx < bus_width_bytes; byte_idx++) begin
    strobe_pattern[byte_idx] = 1'b1;
end

// 修正後の正しい実装
strobe_pattern = generate_strobe_by_size_strategy(address, selected_size, burst_cfg.size_strategy, AXI_DATA_WIDTH);
```

### 8.4 バースト転送でのアドレス計算（最優先修正項目）

```systemverilog
// ❌ 現在の根本的に間違った実装
r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);  // ワードアドレス増分
w_t0a_addr <= w_t0a_addr + (AXI_DATA_WIDTH/8); // ワードアドレス増分

// ✅ 修正後の正しい実装
r_t0_addr <= r_t0_addr + size_to_bytes(r_t0_size);  // SIZEに基づくバイトアドレス増分
w_t0a_addr <= w_t0a_addr + size_to_bytes(w_t0a_size); // SIZEに基づくバイトアドレス増分
```

#### 修正の重要性
- **最優先**: この修正なしでは、バースト転送が根本的に動作しない
- **影響範囲**: すべてのバースト転送（READ/WRITE）に影響
- **テスト結果**: 現在のテスト結果は誤った動作に基づいている

## 9. 修正後の利点

### 9.1 仕様準拠
- **ARM公式仕様書**: 要件を完全に満たす
- **柔軟性**: バースト転送でも適切なSIZE選択
- **正確性**: SIZEとアドレスに基づく適切なSTROBE制御

### 9.2 実装の改善
- **アドレス境界**: SIZEに基づく正確な丸め処理
- **有効バイト位置**: アドレスとSIZEに基づく正確な計算
- **バースト制御**: SIZEに基づく適切なアドレス増分

### 9.3 テストの品質向上
- **網羅性**: 様々なSIZEパターンのテスト
- **正確性**: 仕様に準拠した動作確認
- **信頼性**: 実装の妥当性検証

### 9.4 size_strategyの利点
- **FULL戦略**: 効率的なフルバス幅転送
- **RANDOM戦略**: 柔軟な部分バス幅転送
- **制約管理**: SIZE制約の適切な制御

## 10. まとめ

現在のPART11の実装は、ARM公式仕様書の要件を完全には満たしていません。特に以下の点で修正が必要です：

1. **最優先: バースト内アドレス計算**: SIZEに基づくバイトアドレスの増分（現在はワードアドレス増分で根本的に間違い）
2. **SIZE生成**: `size_strategy`に基づく適切な制御が必要
3. **アドレス境界**: SIZEに基づく正確な丸め処理
4. **有効バイト位置**: SIZEとアドレスに基づく正確な計算
5. **STROBE生成**: バースト内ビート位置を考慮した制御

## 11. テストベンチのAXI4 WRAPバースト仕様準拠性分析

### 11.1 現在のテストベンチ設定の問題点

#### 重大な仕様違反
```systemverilog
// ❌ 現在の設定（仕様違反）
'{weight: 1, length_min: 15, length_max: 31, burst_type: "WRAP", size_strategy: "RANDOM"}

// 問題点
// 1. バースト長15-31: 仕様書で許可されていない値
// 2. アライメントチェック: 実装されていない
// 3. 制約チェック: 実装されていない
```

#### AXI4仕様書との乖離
- **仕様書の要件**: バースト長は 2, 4, 8, 16 のいずれかでなければならない
- **現在の設定**: バースト長15-31（仕様違反）
- **開始アドレス**: 転送サイズにアラインされている必要があるが、チェック未実装

### 11.2 size_strategyの使用可能性分析

#### 使用可能な理由
1. **仕様書準拠**: SIZE制約に違反しない
2. **柔軟性**: 様々なSIZEでのテストが可能
3. **実用性**: 実際のシステムでの使用例がある

#### 1バイトWRAP転送の技術的可能性
- **理論的**: 仕様書で明示的に禁止されていない
- **実用的**: 複雑だが実装可能
- **制約**: 開始アドレスが1バイトアラインされている必要

#### 実装上の考慮事項
```systemverilog
// 1バイトWRAP転送の例
if (r_t0_size == 0) begin // 1バイト転送
    // アドレス増分: 1バイト
    r_t0_addr <= r_t0_addr + 1;
    
    // ラップ境界: 16バイト（LEN=15の場合）
    if (r_t0_addr >= (axi_ar_addr + 16)) begin
        r_t0_addr <= axi_ar_addr;
    end
end
```

### 11.3 推奨される修正方針

#### 保守的アプローチ（推奨）
1バイトWRAP転送対応は複雑になるため、安全な設定に留める

```systemverilog
// ✅ 推奨設定（安全なWRAPバースト）
burst_config_t burst_config_weights[] = '{
    '{weight: 4, length_min: 1, length_max: 3, burst_type: "INCR", size_strategy: "FULL"},
    '{weight: 3, length_min: 4, length_max: 7, burst_type: "INCR", size_strategy: "RANDOM"},
    '{weight: 2, length_min: 8, length_max: 15, burst_type: "INCR", size_strategy: "RANDOM"},
    // WRAPバースト（安全な設定）
    '{weight: 1, length_min: 1, length_max: 1, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=1 (2転送)
    '{weight: 1, length_min: 3, length_max: 3, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=3 (4転送)
    '{weight: 1, length_min: 7, length_max: 7, burst_type: "WRAP", size_strategy: "FULL"},     // LEN=7 (8転送)
    '{weight: 1, length_min: 15, length_max: 15, burst_type: "WRAP", size_strategy: "FULL"},   // LEN=15 (16転送)
    '{weight: 1, length_min: 0, length_max: 0, burst_type: "FIXED", size_strategy: "RANDOM"}
};
```

#### 制約チェックの実装
```systemverilog
// WRAPバーストの制約チェック
if (selected_type == "WRAP") begin
    // バースト長の制約チェック
    if (!((selected_length + 1) inside {2, 4, 8, 16})) begin
        $error("WRAP burst: Burst length %0d must be 2, 4, 8, or 16", selected_length + 1);
        $finish;
    end
    
    // 開始アドレスのアライメントチェック
    int size_bytes = size_to_bytes(selected_size);
    if (base_addr % size_bytes != 0) begin
        $error("WRAP burst: Start address 0x%x not aligned to transfer size %0d bytes", base_addr, size_bytes);
        $finish;
    end
end
```

### 11.4 修正の優先度

#### 最優先（即座に修正）
1. **WRAPバースト長の制約違反**: 仕様書で許可されていない値
2. **アライメントチェックの未実装**: 不正なアドレスでの動作

#### 高優先度
3. **FULL戦略の不足**: WRAPバーストでの適切なSIZE制御
4. **制約チェックの実装**: テストベンチでの事前検証

### 11.5 結論

- **size_strategy**: 使用可能、仕様書準拠
- **1バイトWRAP転送**: 理論的に可能だが実装が複雑
- **推奨方針**: 保守的アプローチで安全な設定に留める
- **緊急度**: 現在の設定は仕様違反のため即座に修正が必要

### 10.1 size_strategyの動作
- **FULL**: バス幅とSIZE一致、全ビット有効
- **RANDOM**: バス幅以下でSIZE乱数発生、SIZEに基づく制約付き制御

### 10.2 実装の指針
- `strobe_strategy` → `size_strategy` への変更
- SIZE制約の適切な管理
- アドレス境界とバイト位置の正確な計算

これらの修正により、AXI4プロトコルに完全準拠した実装となり、より柔軟で正確なテストが可能になります。

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
