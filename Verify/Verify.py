import os

# ================= 檔案名稱設定 =================
FILE_DATA = "output_neg.dat"             
FILE_TARGET = "ROR_Result_Open3D.dat"   
# ===============================================

def get_bit0_from_hex(hex_char):
    """ 將 Hex 字元轉成數值並取第 0 bit """
    try:
        val = int(hex_char, 16)
        return val & 1
    except ValueError:
        return None

def main():
    print(f"--- 啟動逐行對應模式 (Row-by-Row Check) ---")
    
    if not os.path.exists(FILE_DATA) or not os.path.exists(FILE_TARGET):
        print("❌ 錯誤：找不到檔案！請確認資料夾內是否有這兩個 .dat 檔。")
        input("按 Enter 結束...")
        return

    with open(FILE_DATA, 'r', encoding='utf-8') as f1:
        lines_data = [line.strip() for line in f1.readlines() if line.strip()]
        
    with open(FILE_TARGET, 'r', encoding='utf-8') as f2:
        lines_target = [line.strip() for line in f2.readlines() if line.strip()]

    len_data = len(lines_data)
    len_target = len(lines_target)
    
    print(f"資料檔行數: {len_data}")
    print(f"標準檔行數: {len_target}")
    
    if len_data != len_target:
        print(f"⚠️ 警告：兩個檔案行數不同！程式將以較短的檔案為準進行比對。")
        print("-" * 40)
    else:
        print("-" * 40)

    error_list = []
    compare_count = min(len_data, len_target)

    for i in range(compare_count):
        line_num = i + 1
        
        data_str = lines_data[i]
        last_hex_char = data_str[-1] # 取最後一位 Hex
        data_bit = get_bit0_from_hex(last_hex_char) # 轉成 Bit 0

        target_str = lines_target[i]
        
        try:
            target_bit = int(target_str)
        except ValueError:
            error_list.append(f"第 {line_num} 行無法比對: 標準檔內容 '{target_str}' 不是數字")
            continue

        if data_bit is None:
            error_list.append(f"第 {line_num} 行資料錯誤: '{last_hex_char}' 非 Hex 字元")
            continue

        if data_bit != target_bit:
            error_list.append(
                f"第 {line_num} 行錯誤 | "
                f"Hex末碼[{last_hex_char}] -> Bit0[{data_bit}] != 標準[{target_bit}]"
            )

    if len(error_list) == 0:
        print(f"✅ 完美！共比對 {compare_count} 行，全部相符。")
    else:
        print(f"❌ 發現 {len(error_list)} 個錯誤：")
        print("--- 錯誤列表 (僅列出前 20 筆) ---")
        for err in error_list[:20]:
            print("  " + err)
        if len(error_list) > 20:
            print(f"  ... (還有 {len(error_list)-20} 筆錯誤未顯示)")
        print("-" * 40)
        print(f"統計：錯誤率 {len(error_list)}/{compare_count}")

    input("\n請按 Enter 鍵結束...")

if __name__ == "__main__":
    main()