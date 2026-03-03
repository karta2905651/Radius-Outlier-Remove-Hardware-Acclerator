% 輸入檔案路徑
file1 = 'data\ROR_Result_Open3D.dat';
file2 = 'DN_Verify_64bit.dat';

% 讀取數據
try
    data1 = load(file1);
    data2 = load(file2);
catch ME
    fprintf('無法讀取檔案: %s\n', ME.message);
    return;
end

% 檢查大小是否相同
if ~isequal(size(data1), size(data2))
    fprintf('兩個檔案的數據大小不同:\n');
    fprintf('File1: %d x %d\n', size(data1, 1), size(data1, 2));
    fprintf('File2: %d x %d\n', size(data2, 1), size(data2, 2));
    return;
end

% 比對數據
difference = data1 - data2;
if all(difference(:) == 0)
    fprintf('兩個檔案的數據完全相同。\n');
else
    error_count = nnz(difference ~= 0); % 計算非零元素數量，即錯誤數據數量
    fprintf('兩個檔案的數據存在差異，共有 %d 筆錯誤資料。\n', error_count);
    fprintf('error rate 為 %.2f%% \n', (error_count/11739)*100);
end
