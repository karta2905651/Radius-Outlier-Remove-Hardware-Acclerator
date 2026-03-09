import numpy as np
import open3d as o3d
import time
import copy

# 1. 讀取原始點雲
file_path = "downsampled_cloud.pcd" 
pcd = o3d.io.read_point_cloud(file_path)

if not pcd.has_points():
    print("無法讀取原始點雲檔案。")
else:
    points = np.asarray(pcd.points)

    # --- 暴力法 ROR 函數 ---
    def brute_force_ror(points, radius, min_neighbors):
        num_points = len(points)
        mask = np.zeros(num_points, dtype=bool)
        print(f"開始暴力法過濾...")
        radius_sq = radius**2
        for i in range(num_points):
            diff = points - points[i]
            dist_sq = np.sum(diff**2, axis=1)
            count = np.sum(dist_sq < radius_sq)
            if count >= min_neighbors + 1:
                mask[i] = True
        return mask

    # 2. 執行暴力過濾
    radius_val = 0.05
    min_nb = 20
    mask = brute_force_ror(points, radius=radius_val, min_neighbors=min_nb)
    filtered_pcd = pcd.select_by_index(np.where(mask)[0])

    # 3. 讀取要比對的 output.pcd
    compare_file = "output.pcd"
    pcd_output = o3d.io.read_point_cloud(compare_file)

    if not pcd_output.has_points():
        print(f"警告：找不到 {compare_file}，無法進行比對。")
    else:
        # 將點雲座標轉為 tuple 集合以便比對 (tuple 是可雜湊的)
        # 我們將精度取到小數點後 6 位以避免浮點數誤差
        def pcd_to_set(pcd_obj):
            return set(tuple(np.round(p, 6)) for p in np.asarray(pcd_obj.points))

        set_filtered = pcd_to_set(filtered_pcd)
        set_output = pcd_to_set(pcd_output)

        # 計算交集與差集
        # 相同的點：兩個集合都有
        same_points = set_filtered.intersection(set_output)
        # 不同的點：(A 有 B 沒有) + (B 有 A 沒有)
        diff_points = set_filtered.symmetric_difference(set_output)

        print("-" * 30)
        print(f"比對統計：")
        print(f"相同的點數 (灰色): {len(same_points)}")
        print(f"不同的點數 (紅色): {len(diff_points)}")
        print("-" * 30)

        # 4. 建立顯示用的點雲物件
        viz_elements = []

        if same_points:
            pcd_same = o3d.geometry.PointCloud()
            pcd_same.points = o3d.utility.Vector3dVector(np.array(list(same_points)))
            pcd_same.paint_uniform_color([0.6, 0.6, 0.6])  # 灰色
            viz_elements.append(pcd_same)

        if diff_points:
            pcd_diff = o3d.geometry.PointCloud()
            pcd_diff.points = o3d.utility.Vector3dVector(np.array(list(diff_points)))
            pcd_diff.paint_uniform_color([1, 0, 0])  # 紅色
            viz_elements.append(pcd_diff)

        # 5. 顯示結果
        if viz_elements:
            print("正在開啟視窗：灰色代表兩者一致，紅色代表有差異...")
            o3d.visualization.draw_geometries(viz_elements, 
                                              window_name="Comparison: Gray (Same), Red (Different)",
                                              width=1024, height=768)
        else:
            print("兩個點雲完全一致，沒有可顯示的差異。")