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

### ROR加速IP ( Hardware Accelerator ):


<img width="985" height="489" alt="Diagram" src="https://github.com/user-attachments/assets/22ee6787-0de9-4e4e-b3f7-ec4ca154687d" />



