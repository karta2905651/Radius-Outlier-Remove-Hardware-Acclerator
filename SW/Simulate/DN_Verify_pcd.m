% MATLAB 程式：讀取 input.pcd 並進行定點數 ROR 驗證

% 1. 設定檔案名稱
filename = 'input.pcd'; 

% 2. 讀取 PCD 檔案資料
try
    ptCloud = pcread(filename); % 使用 MATLAB 內建函式讀取 PCD
    
    % 提取 x, y, z 座標
    % pcread 讀入的 Location 可能是 M x N x 3 (有序) 或 N x 3 (無序)
    % 使用 reshape 強制轉為 N x 3 格式，確保相容後續邏輯
    data = reshape(ptCloud.Location, [], 3); 
    
    % 確保數據為 double 類型以便進行數學運算 (雖然之後會轉定點數)
    data = single(data);
    
    fprintf('成功讀取 %s，點雲數量: %d\n', filename, size(data, 1));
catch ME
    error('讀取 PCD 失敗。請確認您有安裝 Computer Vision Toolbox 或 Lidar Toolbox。\n錯誤訊息: %s', ME.message);
end

% 3. 定點數轉換 (Q16.16 模擬)
% 將浮點數座標轉換為整數表示 (模擬 FPGA/硬體行為)
q8_8_data = round(data * 2^16);

% 4. 初始化參數
% 距離閾值平方 (0.05^2 = 0.0025)，並根據 Q16.16 的平方 (2^32) 進行縮放
threshold = round(0.0025 * 2^32); 
maxCount = 20;    % 最小鄰居數 (MinPts)
counts = zeros(size(data,1), 1); % 結果儲存陣列

tic;
% 5. 主迴圈：計算鄰居 (暴力法 O(N^2))
% 注意：在 MATLAB 中跑雙層迴圈處理大量點雲會非常慢
num_points = size(data, 1);

for i = 1:num_points
    
    count = 0; 
    neighbor_true = 0;

    % 這裡可以直接與所有點比較
    for j = 1:num_points
        % 優化：跳過自己與自己的比較 (雖然距離為0符合條件，但通常定義鄰居不含自己或是含自己需調整 maxCount)
        % 您的原始邏輯包含自己，這裡維持原樣
        
        % 計算兩點的定點數平方距離
        distance = discal(q8_8_data(i,:), q8_8_data(j,:));
        
        % 如果距離小於等於閥值，計數累加
        if distance <= threshold
            count = count + 1;
        end
        
        % 當累加超過 maxCount 時，判定為核心點/有效點，提早跳出
        if count > maxCount
            neighbor_true = 1;
            break;
        end
    end

    counts(i) = neighbor_true; % 儲存結果 (1:保留, 0:雜訊)
    
    % (選用) 顯示進度，避免以為當機
    if mod(i, 1000) == 0
        fprintf('已處理: %d / %d\n', i, num_points);
    end
end

exe_time = toc;
fprintf('執行時間為 %2f s\n', exe_time);

% 6. 輸出結果
writematrix(counts, 'DN_Verify_64bit.dat');
fprintf('結果已儲存至 DN_Verify_64bit.dat\n');


% --- 輔助函式 ---
function disout = discal(p1, p2)
    % discal 計算兩個三維點之間的平方距離 (針對定點數整數操作)
    % 輸入: p1, p2 為 1x3 向量
    
    % 計算各方向的偏差
    bias = p2 - p1;

    % 計算平方距離 (注意 MATLAB 預設 double 精度足夠容納 2^32 以上的數值)
    % 如果要完全模擬硬體溢位行為，這裡可能需要轉 int64 或做位元限制，
    % 但一般演算法驗證用 double 儲存大整數即可。
    disout = sum(bias .^ 2);
end