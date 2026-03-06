# Radius-Outlier-Remove-Hardware-Acclerator
###  實作內容 :
利用 Vivado 開發平台進行硬體/軟體協同設計 (HW/SW Co-design) 實作了一個基於 FPGA 的 3D 點雲離群點去除 (Radius Outlier Removal, ROR) 硬體加速器，並利用並行架構加速 3D 空間中點對點的距離運算，增加點雲資料過濾的處理效率。

###  開發環境 :
* **FPGA Development Kit** : Digilent ZedBoard ( Xilinx Zynq-7000 SoC )
* **Development Tools** : Vivado Design Suite, PetaLinux, MATLAB/Python, EDA Tool
<br>
<img width="1189" height="466" alt="image" src="https://github.com/user-attachments/assets/b305f05d-e8d7-4319-98aa-b355700ad669" />
<br>
<p align="center">
  <b>Point Cloud Outlier Remove</b>
</p>
<br>
<br>

##  演算法說明

### 控制參數 :

ROR 的濾波強度由以下兩個關鍵參數決定：

* **搜尋半徑 ( $ε$ )** ：以目標點 $p$ 為中心所劃定的球體搜尋範圍。
* **最小鄰居數 ( $MinPts$ )** ：在 $ε$ 範圍內必須包含的最少點數門檻。


### 判斷邏輯 :

對於點雲中的每一個點 $p$，演算法會執行以下判別邏輯：

1. **距離計算**：計算 $p$ 其餘點 $q$ 的歐氏距離。
2. **條件判定**： 若在以 $p$ 為中心、半徑為 $ε$ 的範圍內，鄰近點數量 $MinPts$ 滿足： $$N_{ε}(p) < MinPts$$ ，則該點 $p$ 被標記為 **離群雜訊 (Outlier)** 並予以移除；否則保留為有效點。

<img width="1062" height="510" alt="image" src="https://github.com/user-attachments/assets/06d6642d-7d58-4cf5-be67-fdf807d4b13b" />
<br>
<p align="center">
  <b>ROR algorithm</b>
</p>
<br>
<br>

##  硬體架構 (Hardware Architecture)
### 數據傳輸 :
利用 AXI DMA 硬體介面結合 DMA_proxy 驅動模組，在 Linux 使用者空間與 PL 端加速器之間建立了一條雙向資料路徑，支援使用者在應用軟體端透過檔案介面高效傳輸數據。
##### 參考資料 : https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842418/Linux+DMA+From+User+Space
<br>
<br>

<img width="1480" height="508" alt="block" src="https://github.com/user-attachments/assets/ea763768-da68-4338-b6a8-3aaea45d5479" />
<br>
<p align="center">
  <b>Block Diaogram</b>
</p>

### ROR 硬體加速器 (ROR Hardware Accelerator) :
#### 1. ROR 運算單元 (ROR UNIT)
* **運算元件 ( PE )**：使用 **Verilog HDL** 根據三維歐幾里德距離公式開發運算單元，作為點雲資料的距離計算與鄰近點計數邏輯。為了節省硬體資源與運算速度，設計中省略開根號改為後續直接與閥值平方做比較，公式如下 : $$d^2 = (x_2-x_1)^2 + (y_2-y_1)^2 + (z_2-z_1)^2 \le \epsilon^2$$
* **並行化架構**：導入 PE 並行架構，實現多個點同步進行距離運算與鄰近點計數邏輯，提升點雲資料處理效率。

#### 2. 記憶體層級設計 (Memory Hierarchy Design) 
* **BRAM 快取**：加速器 IP 內部利用 **Block RAM (BRAM)** 暫存當前運算的點雲子集，降低對外部 DDR 頻繁存取所造成的匯流排延遲。
* **True Dual-Port 架構**：採用 **True Dual-Port BRAM**，達成數據的「讀寫同步存取」，同時讀取輸入的點雲資訊以及寫入判斷結果。

<img width="986" height="480" alt="Diagram1" src="https://github.com/user-attachments/assets/f64fa57b-23e8-446a-9f58-7c4a77f8fa1d" />
<br>
<p align="center">
  <b>ROR Accelerator Diaogram</b>
</p>

## 軟硬體整合 (Co-Design) :



## 成果展示 (Demo Video)
<p align="center">
  <a href="https://www.youtube.com/watch?v=sfzBos3J_24">
    <img src="https://img.youtube.com/vi/sfzBos3J_24/maxresdefault.jpg" width="800px" alt="Point Cloud ROR Accelerator Demo">
    <br>
    <b>點擊上方圖片觀看：Point Cloud ROR Accelerator 實機演示</b>
  </a>
</p>
