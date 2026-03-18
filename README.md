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

##  演算法說明

### 控制參數 :

ROR 的濾波強度由以下兩個關鍵參數決定：

* **搜尋半徑 ( $ε$ )** ：以目標點 $p$ 為中心所劃定的球體搜尋範圍。
* **最小鄰居數 ( $MinPts$ )** ：在 $ε$ 範圍內必須包含的最少點數門檻。


### 判斷邏輯 :

對於點雲中的每一個點 $p$，演算法會執行以下判別邏輯：

1. **距離計算**：計算 $p$ 其餘點 $q$ 的歐氏距離。
2. **條件判定**： 若在以 $p$ 為中心、半徑為 $ε$ 的範圍內，鄰近點數量 $MinPts$ 滿足： $$N_{ε}(p) < MinPts$$ ，則該點 $p$ 被標記為 **離群雜訊 (Outlier)** 並予以移除；否則保留為有效點。

<br>
<img width="1062" height="510" alt="image" src="https://github.com/user-attachments/assets/06d6642d-7d58-4cf5-be67-fdf807d4b13b" />
<p align="center">
  <b>ROR algorithm</b>
</p>
<br>

##  硬體架構 (Hardware Architecture)
### 數據傳輸 :
利用 AXI DMA 硬體介面結合 DMA_proxy 驅動模組，在 Linux 使用者空間與 PL 端加速器之間建立了一條雙向資料路徑，支援使用者在應用軟體端透過檔案介面高效傳輸數據。
##### 參考資料 : https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842418/Linux+DMA+From+User+Space
<br>

<img width="1480" height="508" alt="block" src="https://github.com/user-attachments/assets/ea763768-da68-4338-b6a8-3aaea45d5479" />
<br>
<p align="center">
  <b>Block Diaogram</b>
</p>
<br>

### ROR 硬體加速器 (ROR Hardware Accelerator) :
#### 1. ROR 運算單元 (ROR UNIT)
* **運算元件 ( PE )**：使用 **Verilog HDL** 根據三維歐幾里德距離公式開發運算單元，作為點雲資料的距離計算與鄰近點計數邏輯。為了節省硬體資源與運算速度，設計中省略開根號改為後續直接與閥值平方做比較，公式如下 : $$d^2 = (x_2-x_1)^2 + (y_2-y_1)^2 + (z_2-z_1)^2 \le \epsilon^2$$
* **並行化架構**：導入 PE 並行架構，實現多個點同步進行距離運算與鄰近點計數邏輯，提升點雲資料處理效率。

#### 2. 記憶體層級設計 (Memory Hierarchy Design) :
* **BRAM 快取**：加速器 IP 內部利用 **Block RAM (BRAM)** 暫存當前運算的點雲子集，降低對外部 DDR 頻繁存取所造成的匯流排延遲。
* **True Dual-Port 架構**：採用 **True Dual-Port BRAM**，達成數據的「讀寫同步存取」，同時讀取輸入的點雲資訊以及寫入判斷結果。

<br>
<img width="986" height="480" alt="Diagram1" src="https://github.com/user-attachments/assets/f64fa57b-23e8-446a-9f58-7c4a77f8fa1d" />
<br>
<p align="center">
  <b>ROR Accelerator Diaogram</b>
</p>
<br>

## 軟硬體整合 (Co-Design) 

<table border="0">
  <tr>
    <td width="55%" valign="top">
      <h4>1. User-Level Application Framwork : </h4>
        <ul>
          負責執行使用者的應用邏輯，在此設計中主要進行讀取並解析 .pcd 點雲標準格式檔案，將三維座標數據提取至緩衝區，並將點雲座標根據硬體 AXI4-Stream 介面的位元寬度對齊。
        </ul>
        <h4>2. DMA Proxy Driver</h4>
        <ul>
          負責扮演橋樑的角色讓 User Space 的程式可以與最接近硬體層面的 DMA 驅動溝通，提供一個代理介面（Proxy），處理記憶體分配與傳輸請求。確保了應用程式不需要具備核心權限也能控制 AXI DMA 進行數據傳輸。
        </ul>
        <h4>3. DMA Engine Driver & Xilinx DMA Driver</h4>
        <ul>
          最接近硬體層面也是最主要操控 DMA 的驅動，負責管理硬體通道傳輸狀態、中斷處理以及硬體暫存器的映射，確保資料交換。
        </ul>
    </td>
    <td width="45%" valign="center">
      <p align="center"><b>System Integration & API Flow</b></p>
      <img src="https://github.com/user-attachments/assets/7b68cbdc-4ca6-42b9-98e5-f5066c486a88" alt="System API Architecture" width="100%">
    </td>
  </tr>
</table>

<br>

### ROR-Delete (Application Framwork) :

<table border="0">
  <tr>
    <td width="55%" align="center" valign="middle">
      <p style="text-align: center; margin-bottom: 12px;">
        <b>Point Cloud Data file format</b>
      </p>  
      <img src="https://github.com/user-attachments/assets/127f22bc-3579-4d33-8457-b4c6b908fa53" 
           alt="Point Cloud Data file format" 
           width="80%" 
           style="display: block; margin: 0 auto;">
    </td>
    <td width="45%" valign="top">
      <h4>1. Header (標頭檔) : </h4>
        <ul>
          Header 位於檔案的最上方，用來定義這份點雲的規格，普遍以 Binary 、 ASCII 文本格式儲存的。
        </ul>
        <h4>2. Point Cloud Data :</h4>
        <ul>
          緊接在 Header 的 DATA 行後的是每個點的 (X,Y,Z) 位置資訊，以浮點數計載每個點的實際的座標資訊。
        </ul>
    </td>
  </tr>
</table>

<br> 

**ROR-Delete Application 負責的部分在於讀取點雲檔並解析 Header 取得每個點的座標資訊，由於座標值是以浮點數的型式表示，因此需先將浮點數轉換為 Q16.16定點數（Fixed-point）再將座標放入緩衝區以便傳送至加速器端中的快取。接著在硬體處理完點雲後，以輸出的布林值來表示點雲是否為有效點，以此為判斷是否要將此點座標寫入新的輸出點雲檔中，來達成點雲過濾的效果，如下圖表示。**

<br>
<br>

<img width="999" height="556" alt="image" src="https://github.com/user-attachments/assets/a6094ef5-9658-4ee0-927c-64a9a12f74d2" />
<p align="center">
  <b>Data Flow 示意</b>
</p>
<br>

## 成果展示 (Demo Video)
<p align="center">
  <a href="https://www.youtube.com/watch?v=sfzBos3J_24">
    <img src="https://img.youtube.com/vi/sfzBos3J_24/maxresdefault.jpg" width="800px" alt="Point Cloud ROR Accelerator Demo">
    <br>
    <b>點擊上方圖片觀看：Point Cloud ROR Accelerator 實機演示</b>
  </a>
</p>
<br>

## 效能比較
<img width="1234" height="682" alt="image" src="https://github.com/user-attachments/assets/2238645c-a5ca-4cbf-bb9a-56105f30ca6a" />
<br>

* **測試輸入點雲數量**：**11739**
* **加速比**：**8.01x** 
* **定點數誤差比**：**1/11739** $\approx$ **0.0085%**


<img width="802" height="262" alt="image" src="https://github.com/user-attachments/assets/6e20bcc2-22e4-4a2b-bbb2-1b300c960c6c" />
