import open3d as o3d
import os
import numpy as np

def voxel_upsample(pcd, voxel_size, upscale_factor=4):
    """
    透過 Voxel 結構進行上採樣
    :param pcd: 原始點雲
    :param voxel_size: 體素大小 (數值愈小愈精細)
    :param upscale_factor: 每個 Voxel 產生的新點數量
    """
    # 1. 建立 Voxel Grid
    v_grid = o3d.geometry.VoxelGrid.create_from_point_cloud(pcd, voxel_size)
    voxels = v_grid.get_voxels()
    
    # 2. 取得所有佔用 Voxel 的中心點
    centers = np.array([v_grid.get_voxel_center_coordinate(v.grid_index) for v in voxels])
    
    # 3. 在每個中心點周圍產生隨機微小偏移的點 (模擬上採樣)
    new_points = []
    for center in centers:
        # 產生 N 個點，分佈在該 Voxel 範圍內
        offsets = np.random.uniform(-voxel_size/4, voxel_size/4, (upscale_factor, 3))
        new_points.append(center + offsets)
    
    upsampled_pcd = o3d.geometry.PointCloud()
    upsampled_pcd.points = o3d.utility.Vector3dVector(np.vstack(new_points))
    
    # 如果原點雲有顏色，這裡可以簡單地繼承或處理顏色 (可選)
    return upsampled_pcd

def display_pcd(file_path):
    if not os.path.exists(file_path):
        print(f"錯誤：找不到檔案 {file_path}")
        return

    print("正在讀取原始點雲...")
    pcd = o3d.io.read_point_cloud(file_path)

    if pcd.is_empty():
        print("讀取失敗或檔案內容為空。")
        return

    print(f"原始點數：{len(pcd.points)}")

    # --- 執行 Voxel 上採樣 ---
    # voxel_size 建議設定為原始點雲平均間距的 1~2 倍
    # 如果您的數據單位是公尺，0.05 代表 5cm 的格子
    v_size = 0.001 
    print(f"正在執行 Voxel 上採樣 (Voxel Size: {v_size})...")
    pcd_upsampled = voxel_upsample(pcd, voxel_size=v_size, upscale_factor=4)
    print(f"上採樣後點數：{len(pcd_upsampled.points)}")
    # -----------------------
    
    # 將原始點雲設為紅色，上採樣點雲設為綠色，方便對比 (可選)
    pcd.paint_uniform_color([1, 0, 0])          # 紅色
    pcd_upsampled.paint_uniform_color([0, 1, 0]) # 綠色
    
    print("正在顯示視窗（紅色為原始，綠色為上採樣結果）")
    o3d.visualization.draw_geometries([pcd_upsampled], 
                                      window_name="Open3D Voxel Upsampling Viewer",
                                      width=800, 
                                      height=600)

if __name__ == "__main__":
    pcd_filename = "outputv1.pcd" 
    display_pcd(pcd_filename)