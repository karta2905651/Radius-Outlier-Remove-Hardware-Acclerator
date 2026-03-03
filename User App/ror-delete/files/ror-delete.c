#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <time.h> // 引入時間函式庫

#include "dma-proxy.h"

#define FRAC_BITS 16
#define INV_SCALE_FACTOR (1.0f / (float)(1 << FRAC_BITS))
#define SCALE_FACTOR (float)(1 << FRAC_BITS)

struct Point3D_Float {
    float x, y, z;
};

// 輔助函式：計算時間差（秒）
double get_elapsed_time(struct timespec start, struct timespec end) {
    return (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
}

static void die(const char *msg) {
    perror(msg);
    exit(1);
}

long find_pcd_data_offset(FILE *fp) {
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "DATA binary", 11) == 0)
            return ftell(fp);
    }
    return -1;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "用法: %s <input.pcd> <output_filtered.pcd>\n", argv[0]);
        return 1;
    }

    struct timespec total_start, total_end, compute_start, compute_end;
    clock_gettime(CLOCK_MONOTONIC, &total_start); // 開始總計時

    const char *pcd_file = argv[1];
    const char *output_file = argv[2];

    FILE *fp = fopen(pcd_file, "rb");
    if (!fp) die("fopen input");

    // 1. 初始化 DMA
    int ftx = open("/dev/dma_proxy_tx", O_RDWR);
    int frx = open("/dev/dma_proxy_rx", O_RDWR);
    if (ftx < 0 || frx < 0) die("open dma device");

    struct channel_buffer *txb = mmap(NULL, sizeof(struct channel_buffer) * TX_BUFFER_COUNT,
                                      PROT_READ | PROT_WRITE, MAP_SHARED, ftx, 0);
    struct channel_buffer *rxb = mmap(NULL, sizeof(struct channel_buffer) * RX_BUFFER_COUNT,
                                      PROT_READ | PROT_WRITE, MAP_SHARED, frx, 0);

    // 2. 準備緩衝區
    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    find_pcd_data_offset(fp); 
    struct Point3D_Float *out_buffer = malloc(file_size);
    size_t out_count = 0;

    size_t batch_limit = BUFFER_SIZE / (4 * sizeof(int32_t));
    struct Point3D_Float *temp_floats = malloc(batch_limit * sizeof(struct Point3D_Float));

    printf("開始執行硬體加速過濾與格式轉換...\n");
    
    // 3. 處理迴圈 (核心計算計時開始)
    clock_gettime(CLOCK_MONOTONIC, &compute_start);

    size_t points_read;
    while ((points_read = fread(temp_floats, sizeof(struct Point3D_Float), batch_limit, fp)) > 0) {
        int32_t *tx_ptr = (int32_t *)txb[0].buffer;
        int32_t *rx_ptr = (int32_t *)rxb[0].buffer;

        // [軟體端] 浮點數 -> 定點數
        for (size_t i = 0; i < points_read; i++) {
            tx_ptr[i * 4 + 0] = 0;
            tx_ptr[i * 4 + 1] = (int32_t)roundf(temp_floats[i].z * SCALE_FACTOR);
            tx_ptr[i * 4 + 2] = (int32_t)roundf(temp_floats[i].y * SCALE_FACTOR);
            tx_ptr[i * 4 + 3] = (int32_t)roundf(temp_floats[i].x * SCALE_FACTOR);
        }

        // DMA 傳輸
        txb[0].length = points_read * 16;
        rxb[0].length = points_read * 16;
        ioctl(frx, START_XFER, &rxb[0]);
        ioctl(ftx, START_XFER, &txb[0]);
        ioctl(ftx, FINISH_XFER, &txb[0]);
        ioctl(frx, FINISH_XFER, &rxb[0]);

        // [軟體收斂] 過濾並轉回 Float
        for (size_t i = 0; i < points_read; i++) {
            uint32_t status_word = (uint32_t)rx_ptr[i * 4 + 0];
            if ((status_word & 0x1) == 1) {
                out_buffer[out_count].x = (float)rx_ptr[i * 4 + 3] * INV_SCALE_FACTOR;
                out_buffer[out_count].y = (float)rx_ptr[i * 4 + 2] * INV_SCALE_FACTOR;
                out_buffer[out_count].z = (float)rx_ptr[i * 4 + 1] * INV_SCALE_FACTOR;
                out_count++;
            }
        }
    }
    clock_gettime(CLOCK_MONOTONIC, &compute_end); // 核心計算結束

    // 4. 寫入 PCD 檔案
    FILE *f_out = fopen(output_file, "wb");
    if (!f_out) die("fopen output");

    fprintf(f_out, "# .PCD v0.7 - Point Cloud Data\n");
    fprintf(f_out, "FIELDS x y z\nSIZE 4 4 4\nTYPE F F F\nCOUNT 1 1 1\n");
    fprintf(f_out, "WIDTH %zu\nHEIGHT 1\nVIEWPOINT 0 0 0 1 0 0 0\n", out_count);
    fprintf(f_out, "POINTS %zu\n", out_count);
    fprintf(f_out, "DATA binary\n");

    fwrite(out_buffer, sizeof(struct Point3D_Float), out_count, f_out);

    clock_gettime(CLOCK_MONOTONIC, &total_end); // 總程序結束

    // --- 輸出結果 ---
    printf("\n==========================================\n");
    printf("過濾完成！過濾後剩餘點數: %zu\n", out_count);
    printf("核心處理時間 (DMA + FPGA): %.6f 秒\n", get_elapsed_time(compute_start, compute_end));
    printf("總執行時間 (含檔案 I/O):   %.6f 秒\n", get_elapsed_time(total_start, total_end));
    printf("==========================================\n");

    // 清理資源
    free(out_buffer);
    free(temp_floats);
    close(ftx); close(frx);
    fclose(fp); fclose(f_out);
    return 0;
}
