% MATLAB 程式：讀取 PCD 並轉換為無空格 128-bit HEX 格式 (C Code 模擬版)
clear; clc;

% --- 1. 檔案設定 ---
input_file = 'input.pcd';                % 輸入檔案
output_file = 'point_cloud_64bithex_pcd.dat'; % 輸出檔案

% --- 2. 讀取 PCD 數據 ---
fprintf('正在讀取 %s ...\n', input_file);
data = read_pcd_auto(input_file); 

% 確保是 N x 3 格式
data = reshape(data, [], 3);

% [關鍵修改 1] 強制轉為 single (32-bit float)，模擬 C 語言 struct 行為
data = single(data); 

num_points = size(data, 1);
fprintf('讀取成功，共 %d 個點。\n', num_points);

% --- 3. 定點數運算 (模擬 C 語言 roundf 行為) ---
word_length = 32;   
scale_factor = 65536; % 2^16

fprintf('正在執行 C-Style Rounding 與 HEX 轉換...\n');

% [關鍵修改 2] 手動運算：模擬 C 語言的 (int32)roundf(val * 65536.0)
% MATLAB 的 round() 對於 .5 的處理方式與 C 的 roundf() 相同 (Round half away from zero)
data_scaled = round(data * scale_factor);

% --- 4. 轉換核心 ---
% [關鍵修改 3] 因為已經手動乘過 65536 並取整了，這裡的小數位數 (FracLength) 設為 0
% 這樣 fi 就會直接把輸入的整數轉為 2補數 Hex，不會再做一次精度轉換
fi_x = fi(data_scaled(:, 1), 1, word_length, 0);
fi_y = fi(data_scaled(:, 2), 1, word_length, 0);
fi_z = fi(data_scaled(:, 3), 1, word_length, 0);

% 提取 HEX 字串
hex_x = string(fi_x.hex);
hex_y = string(fi_y.hex);
hex_z = string(fi_z.hex);

% [關鍵修改 4] 修改 Padding 為 DEADBEEF 以完全匹配 C Code 輸出
% C Code: tx_ptr[i*4 + 0] = 0xDEADBEEF;
padding = repmat("deadbeef", num_points, 1);

% --- 5. 字串合併 ---
% 順序：X(High) -> Y -> Z -> P(Low)
final_hex_strings = hex_x + hex_y + hex_z + padding;

% --- 6. 寫入檔案 ---
fid = fopen(output_file, 'w');
if fid == -1
    error('無法開啟輸出檔案');
end

fprintf(fid, '%s\n', final_hex_strings);
fclose(fid);

fprintf('轉換完成！\n');
fprintf('結果已儲存至: %s\n', output_file);
fprintf('格式範例 (前3行):\n');
disp(final_hex_strings(1:min(3, num_points)));


% =========================================================
%  輔助函式：自動讀取 PCD
% =========================================================
function points = read_pcd_auto(filename)
    try
        ptCloud = pcread(filename);
        points = double(ptCloud.Location);
        return;
    catch
    end
    
    fid = fopen(filename, 'r');
    if fid == -1; error('無法開啟檔案'); end
    
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'DATA binary')
            fclose(fid);
            error('錯誤: 此腳本僅支援 ASCII 格式 PCD。');
        end
        if contains(line, 'DATA ascii')
            break;
        end
    end
    
    raw = textscan(fid, '%f %f %f %*[^\n]');
    fclose(fid);
    
    if isempty(raw{1})
        error('讀不到數據，請檢查檔案內容');
    end
    
    points = [raw{1}, raw{2}, raw{3}];
end