# Radius-Outlier-Remove-Hardware-Acclerator
###  實作內容 :
利用 Vivado 開發平台進行硬體/軟體協同設計 (HW/SW Co-design) 實作了一個基於 FPGA 的 3D 點雲離群點去除 (Radius Outlier Removal, ROR) 硬體加速器，並利用並行架構加速 3D 空間中點對點的距離運算，增加點雲資料過濾的處理效率。

###  開發環境 :
* **FPGA Development Kit** : Digilent ZedBoard ( Xilinx Zynq-7000 SoC )
* **Development Tools** : Vivado Design Suite, PetaLinux, MATLAB/Python, EDA Tool
<br>
<img width="1189" height="466" alt="image" src="https://github.com/user-attachments/assets/b305f05d-e8d7-4319-98aa-b355700ad669" />


##  演算法說明

### 控制參數 :

ROR 的濾波強度由以下兩個關鍵參數決定：

* **搜尋半徑 ( $ε$ )** ：以目標點 $p$ 為中心所劃定的球體搜尋範圍。
* **最小鄰居數 ( $k_{min}$ )** ：在 $ε$ 範圍內必須包含的最少點數門檻。


### 判斷邏輯 :

對於點雲中的每一個點 $p$，演算法會執行以下判別邏輯：

1. **距離計算**：計算 $p$ 其餘點 $q$ 的歐氏距離。
2. **條件判定**： 若在以 $p$ 為中心、半徑為 $ε$ 的範圍內，鄰近點數量 $k_{min}$ 滿足： $$k < k_{min}$$ ，則該點 $q$ 被標記為 **離群雜訊 (Outlier)** 並予以移除；否則保留為有效點。

<img width="348" height="351" alt="image" src="https://github.com/user-attachments/assets/5038b08e-6fd1-440b-b912-fb09950e7591" />

##  硬體加速架構 (Hardware Architecture)

為了在 ZedBoard 上實現高效能過濾，本實作針對運算密集處進行了硬體電路優化：

1. **距離運算單元 (Distance Calculation Unit)**：
   利用 FPGA 的並行特性，同時對多組點資料進行距離計算。為節省運算資源（DSP Slices），採用 **距離平方比較法**，避開耗時的開根號運算：
   $$(x_i - x_j)^2 + (y_i - y_j)^2 + (z_i - z_j)^2 < d_{radius}^2$$

2. **資料傳輸優化 (Data Movement)**：
   * 使用 **AXI4-Stream 介面** 實現硬體加速器 (IP Core) 與記憶體之間的高速資料流。
   * 透過 **DMA (Direct Memory Access)** Proxy 驅動程序，減少 CPU 介入，提升資料吞吐量。

3. **流水線設計 (Pipelining)**：
   在 Vivado HLS/HDL 中設計了深度流水線，確保每個時鐘週期都能產出一個點的過濾結果。




