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

## 3. 具体的な動作例

### 3.1 SIZE=0（1バイト）の場合

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

### 3.2 SIZE=1（2バイト）の場合

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

### 3.3 SIZE=2（4バイト）の場合

#### アドレス0x01（64ビットバス）
```verilog
// アドレス境界: 4バイト境界で丸め
aligned_addr = (0x01 / 4) * 4 = 0x00;  // 下位2ビットを丸め
offset = 0x01 - 0x00 = 1;

// 有効バイト位置: bit8~31（4バイト連続）
strobe = 8'b0000_1111;  // bit0,1,2,3が1
```

## 4. 修正が必要な実装箇所

### 4.1 SIZE生成の修正

```systemverilog
// ✅ 正しい実装: バースト転送でもSIZEをランダム化
// SIZEは常にランダム（バースト転送でも制限なし）
selected_size = $urandom_range(0, $clog2(AXI_DATA_WIDTH / 8));

// 制約: SIZEはバス幅以下である必要
if (size_to_bytes(selected_size) > AXI_DATA_WIDTH / 8) begin
    $error("SIZE constraint violation: SIZE %0d exceeds bus width %0d bytes", 
           size_to_bytes(selected_size), AXI_DATA_WIDTH / 8);
    $finish;
end
```

### 4.2 アドレス境界の丸め処理

```systemverilog
// 現在の不十分な実装
int addr_offset = address % bus_width_bytes;

// 修正後の正しい実装
int size_bytes = size_to_bytes(size);
int aligned_addr = (address / size_bytes) * size_bytes;
int offset = address - aligned_addr;
```

### 4.3 STROBE生成の修正

```systemverilog
// 現在の不正確な実装
for (int byte_idx = 0; byte_idx < min_required_bytes && byte_idx < bus_width_bytes; byte_idx++) begin
    strobe_pattern[byte_idx] = 1'b1;
end

// 修正後の正しい実装
for (int byte_idx = 0; byte_idx < size_bytes; byte_idx++) begin
    int strobe_pos = offset + byte_idx;
    if (strobe_pos < bus_width_bytes) begin
        strobe_pattern[strobe_pos] = 1'b1;
    end
end
```

### 4.4 バースト転送でのアドレス計算

```systemverilog
// 現在の不正確な実装
r_t0_addr <= r_t0_addr + (AXI_DATA_WIDTH/8);

// 修正後の正しい実装
r_t0_addr <= r_t0_addr + size_to_bytes(r_t0_size);
```

## 5. 修正後の利点

### 5.1 仕様準拠
- **ARM公式仕様書**: 要件を完全に満たす
- **柔軟性**: バースト転送でも適切なSIZE選択
- **正確性**: SIZEとアドレスに基づく適切なSTROBE制御

### 5.2 実装の改善
- **アドレス境界**: SIZEに基づく正確な丸め処理
- **有効バイト位置**: アドレスとSIZEに基づく正確な計算
- **バースト制御**: SIZEに基づく適切なアドレス増分

### 5.3 テストの品質向上
- **網羅性**: 様々なSIZEパターンのテスト
- **正確性**: 仕様に準拠した動作確認
- **信頼性**: 実装の妥当性検証

## 6. まとめ

現在のPART11の実装は、ARM公式仕様書の要件を完全には満たしていません。特に以下の点で修正が必要です：

1. **SIZE生成**: バースト転送でもランダム化が必要
2. **アドレス境界**: SIZEに基づく正確な丸め処理
3. **有効バイト位置**: SIZEとアドレスに基づく正確な計算
4. **バースト制御**: SIZEに基づく適切なアドレス計算

これらの修正により、AXI4プロトコルに完全準拠した実装となり、より柔軟で正確なテストが可能になります。

## ライセンス

Licensed under the Apache License, Version 2.0 - see [LICENSE](https://www.apache.org/licenses/LICENSE-2.0) file for details.
