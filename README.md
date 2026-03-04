# Radius-Outlier-Remove-Hardware-Acclerator
Radius Outlier Removal (ROR) Hardware Accelerator
本專案實作了一個基於 FPGA 的 3D 點雲離群點去除 (Radius Outlier Removal, ROR) 硬體加速器。透過在 Digilent ZedBoard (Zynq-7000) 平台上進行硬體/軟體協同設計 (HW/SW Co-design)，針對大規模點雲資料提供高效能的過濾處理。

🚀 效能表現 (Performance)
處理規模：11,739 個點雲數據。

加速倍率：相較於純軟體實作，硬體加速器達成了 7.86x 的速度提升。

算術精度：採用 Q16.16 定點數 (Fixed-point) 運算，兼顧硬體資源佔用與計算精確度。

🛠️ 系統架構 (System Architecture)
本系統將運算密集度最高的 ROR 演算法封裝為 AXI-Stream 介面的 IP 核，並透過 DMA 進行高速資料交換。

FPGA 核心 (PL)：使用 Verilog RTL 實作，包含 BRAM 快取策略與 AXI-Stream 握手協議邏輯。

嵌入式系統 (PS)：運行 PetaLinux，並透過自定義的 C 語言 API 框架 驅動 DMA 進行資料對齊與傳輸。

驗證流程：使用 MATLAB 與 Python (Open3D) 建立 Golden Pattern，確保定點數硬體運算的誤差率符合預期。

📂 專案結構
/rtl：包含 Vivado 專案與 Verilog 源碼。

/sw：基於 PetaLinux 的 C 語言驅動程式與 API 框架。

/scripts：用於資料預處理與誤差分析的 MATLAB/Python 腳本。

💻 開發環境
Hardware: Digilent ZedBoard (Xilinx Zynq-7000 SoC)。

Tools: Vivado Design Suite, PetaLinux, MATLAB, Python (Open3D)。
