#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "dma-proxy.h"

// 定點數參數 (Q16.16)
#define FRAC_BITS 16
#define SCALE_FACTOR (float)(1 << FRAC_BITS)

// PCD 點結構 (Binary Float)
struct Point3D_Float {
    float x, y, z;
};

// 錯誤處理
static void die(const char *msg) { perror(msg); exit(1); }

// 輔助函式：跳過 PCD Header 找 DATA binary
long find_pcd_data_offset(FILE *fp) {
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "DATA binary", 11) == 0) {
            return ftell(fp);
        }
    }
    return -1;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "用法: %s <input.pcd> <output.dat>\n", argv[0]);
        fprintf(stderr, "說明: 將 PCD 轉換並執行 DMA，將所有結果輸出為 128-bit Hex 格式。\n");
        return 1;
    }

    const char *pcd_file = argv[1];
    const char *output_file = argv[2];

    printf("=== PCD to 128-bit Hex Dump Tool ===\n");
    printf("Input: %s\nOutput: %s\n", pcd_file, output_file);
    printf("Format: X[127:96] Y[95:64] Z[63:32] P[31:0]\n");

    // 1. 開啟檔案
    FILE *fp = fopen(pcd_file, "rb");
    if (!fp) die("fopen input");
    long data_start = find_pcd_data_offset(fp);
    if (data_start < 0) die("Invalid PCD header");
    fseek(fp, data_start, SEEK_SET);

    FILE *f_out = fopen(output_file, "w");
    if (!f_out) die("fopen output");

    // 2. 初始化 DMA
    int ftx = open("/dev/dma_proxy_tx", O_RDWR);
    int frx = open("/dev/dma_proxy_rx", O_RDWR);
    if (ftx < 0 || frx < 0) die("open dma device");

    struct channel_buffer *txb = mmap(NULL, sizeof(struct channel_buffer) * TX_BUFFER_COUNT,
                                      PROT_READ|PROT_WRITE, MAP_SHARED, ftx, 0);
    struct channel_buffer *rxb = mmap(NULL, sizeof(struct channel_buffer) * RX_BUFFER_COUNT,
                                      PROT_READ|PROT_WRITE, MAP_SHARED, frx, 0);
    if (txb == MAP_FAILED || rxb == MAP_FAILED) die("mmap");

    // 3. 分批處理邏輯 (確保 buffer 對齊且能處理大檔案)
    // 每個點佔 4 個 int32 (128-bit)
    size_t batch_limit = BUFFER_SIZE / (4 * sizeof(int32_t));
    
    struct Point3D_Float *temp_floats = malloc(batch_limit * sizeof(struct Point3D_Float));
    if (!temp_floats) die("malloc");

    int tx_id = 0, rx_id = 0;
    size_t points_read;
    size_t total_processed = 0;

    // --- 迴圈開始：一批一批讀 ---
    while ((points_read = fread(temp_floats, sizeof(struct Point3D_Float), batch_limit, fp)) > 0) {
        
        // 填入 TX Buffer
        int32_t *tx_ptr = (int32_t *)txb[tx_id].buffer;
        int32_t *rx_ptr = (int32_t *)rxb[rx_id].buffer;
        
        // 清空 RX
        memset(rx_ptr, 0, BUFFER_SIZE);

        for (size_t i = 0; i < points_read; i++) {
            // [關鍵修改] 128-bit Mapping: X(High) ... P(Low)
            // Little Endian 記憶體排列: [0]=Low, [3]=High
            // 所以 tx_ptr[0] 對應 P[31:0]
            // 所以 tx_ptr[3] 對應 X[127:96]
            
            // P [31:0] (Padding / NOM)
            tx_ptr[i*4 + 0] = 0xDEADBEEF; 

            // Z [63:32]
            tx_ptr[i*4 + 1] = (int32_t)roundf(temp_floats[i].z * SCALE_FACTOR); 
            
            // Y [95:64]
            tx_ptr[i*4 + 2] = (int32_t)roundf(temp_floats[i].y * SCALE_FACTOR);
            
            // X [127:96]
            tx_ptr[i*4 + 3] = (int32_t)roundf(temp_floats[i].x * SCALE_FACTOR);
        }

        // 執行 DMA
        size_t total_bytes = points_read * 16; // 16 bytes per point
        txb[tx_id].length = total_bytes;
        rxb[rx_id].length = total_bytes;

        if (ioctl(frx, START_XFER, &rx_id) < 0) die("RX START");
        if (ioctl(ftx, START_XFER, &tx_id) < 0) die("TX START");
        if (ioctl(ftx, FINISH_XFER, &tx_id) < 0) die("TX FINISH");
        if (ioctl(frx, FINISH_XFER, &rx_id) < 0) die("RX FINISH");

        // [關鍵修改] 輸出到檔案
        for (size_t i = 0; i < points_read; i++) {
            // 從 RX Buffer 取出 (順序與 TX 相同)
            uint32_t p_val = (uint32_t)rx_ptr[i*4 + 0]; // [31:0]
            uint32_t z_val = (uint32_t)rx_ptr[i*4 + 1]; // [63:32]
            uint32_t y_val = (uint32_t)rx_ptr[i*4 + 2]; // [95:64]
            uint32_t x_val = (uint32_t)rx_ptr[i*4 + 3]; // [127:96]

            // 格式化寫入: X Y Z P (高位在前，低位在後)
            // 這樣在文字檔中看起來就是一個完整的 128-bit 數值
            fprintf(f_out, "%08X%08X%08X%08X\n", x_val, y_val, z_val, p_val);
        }

        total_processed += points_read;
        printf("\rProcessed: %zu points...", total_processed);
        fflush(stdout);
    }

    printf("\nDone! Results saved to %s\n", output_file);

    // 清理
    free(temp_floats);
    munmap(txb, sizeof(struct channel_buffer) * TX_BUFFER_COUNT);
    munmap(rxb, sizeof(struct channel_buffer) * RX_BUFFER_COUNT);
    close(ftx);
    close(frx);
    fclose(fp);
    fclose(f_out);

    return 0;
}
