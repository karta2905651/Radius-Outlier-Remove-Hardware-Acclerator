import open3d as o3d
import os

def main():
    file_path = "output.pcd"

    # 檢查檔案是否存在
    if not os.path.exists(file_path):
        print(f"錯誤：找不到檔案 '{file_path}'")
        return

    print("正在讀取點雲...")
    # 讀取 PCD 檔案
    pcd = o3d.io.read_point_cloud(file_path)

    # 檢查點雲是否為空
    if pcd.is_empty():
        print("讀取失敗：點雲資料為空。")
        return

    print(f"成功讀取點雲，包含 {len(pcd.points)} 個點。")
    print("正在開啟顯示視窗... (按 'q' 或 'Esc' 關閉視窗)")
    
    # 顯示點雲
    o3d.visualization.draw_geometries([pcd], 
                                      window_name="Open3D 點雲顯示",
                                      width=800, 
                                      height=600)

if __name__ == "__main__":
    main()