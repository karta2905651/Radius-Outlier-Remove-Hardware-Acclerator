`timescale 1ns / 1ps
// `include "ROR_Unit.v"

module ROR_IP #
       (
           parameter integer C_S00_AXIS_TDATA_WIDTH = 128,
           parameter integer C_M00_AXIS_TDATA_WIDTH = 128,
           parameter integer C_M00_AXIS_START_COUNT = 0
       )
       (
           // S00_AXIS
           input  wire                                     s00_axis_aclk,
           input  wire                                     s00_axis_aresetn,
           output wire                                     s00_axis_tready,
           input  wire [C_S00_AXIS_TDATA_WIDTH-1:0]        s00_axis_tdata,
           input  wire [(C_S00_AXIS_TDATA_WIDTH/8)-1:0]    s00_axis_tstrb,
           input  wire                                     s00_axis_tlast,
           input  wire                                     s00_axis_tvalid,

           // M00_AXIS
           input  wire                                     m00_axis_aclk,
           input  wire                                     m00_axis_aresetn,
           (* mark_debug = "true" *) output wire                                     m00_axis_tvalid,
           (* mark_debug = "true" *) output wire [C_M00_AXIS_TDATA_WIDTH-1:0]        m00_axis_tdata,
           output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1:0]    m00_axis_tstrb,
           (* mark_debug = "true" *) output wire                                     m00_axis_tlast,
           (* mark_debug = "true" *) input  wire                                     m00_axis_tready
       );

wire aclk    = s00_axis_aclk;
wire aresetn = s00_axis_aresetn;

// ============================================================
// Parameters
// ============================================================
localparam integer C_MAX_WORDS = 16384;
localparam integer PTR_WIDTH   = $clog2(C_MAX_WORDS);
// Total Width = 128 bits (96 PCD + 32 NOM)
localparam integer RAM_WIDTH   = 128;
localparam integer BYTE_WIDTH  = 8;
localparam integer NUM_BYTES   = RAM_WIDTH / BYTE_WIDTH; // 16 bytes

// ============================================================
// 1. 單一 TDP RAM 定義 (Single True Dual-Port RAM)
// ============================================================
(* ram_style = "block" *)
reg [RAM_WIDTH-1:0] ram [0:C_MAX_WORDS-1];
reg [RAM_WIDTH-1:0] ram_out; // Port B Output Register

// Pointers
reg [PTR_WIDTH-1:0] wr_ptr = 0; // Unified Write Pointer (RECV)
(* mark_debug = "true" *) reg [PTR_WIDTH-1:0] rd_ptr = 0;// Unified Read Pointer (SEND)
reg [PTR_WIDTH:0]   word_count = 0;

// FSM States
localparam [1:0] IDLE = 2'd0,
           RECV = 2'd1,
           RORC = 2'd2,
           SEND = 2'd3;

(* mark_debug = "true" *) reg [1:0] state      = IDLE;
reg [1:0] next_state = IDLE;

// AXI Interface
assign s00_axis_tready = (state == RECV);
reg m_tvalid_r = 1'b0;
reg m_tlast_r  = 1'b0;


// 直接連接 RAM 輸出 (No PRE_SEND needed)
assign m00_axis_tdata  = data_buf;
assign m00_axis_tvalid = m_tvalid_r;
assign m00_axis_tlast  = m_tlast_r;
assign m00_axis_tstrb  = {(C_M00_AXIS_TDATA_WIDTH/8){1'b1}};

// DN Unit Signals
reg pcd_ready;
wire [PTR_WIDTH-1:0] pcd_addr;
wire [PTR_WIDTH-1:0] nom_addr;
wire [RAM_WIDTH-1:0] pcd_data_from_dn_read; // Full 128-bit read
wire pcd_req, nom_valid, nom_data, finish;

// ============================================================
// 2. RAM 控制訊號 (Port A & Port B Muxing)
// ============================================================

// --- Port A (負責寫入: RECV & RORC write) ---
reg [PTR_WIDTH-1:0] addr_a;
reg [RAM_WIDTH-1:0] din_a;
reg [NUM_BYTES-1:0] we_a; // Byte Write Enable (16 bits)

always @(*)
begin
    // 預設值
    addr_a = wr_ptr;
    din_a  = s00_axis_tdata;
    we_a   = 16'd0;

    if (state == RECV && s00_axis_tvalid && s00_axis_tready)
    begin
        // RECV 狀態：寫入完整的 128-bit
        addr_a = wr_ptr;
        din_a  = s00_axis_tdata;
        we_a   = 16'hFFFF; // 所有 Byte 都寫入
    end
    else if (state == RORC && nom_valid)
    begin
        // RORC 狀態：只寫入低 32-bit (NOM)，高位保持不變
        addr_a = nom_addr;
        din_a  = {96'd0, 31'd0, nom_data}; // 高位補0 (因為WE不開，不會寫入)
        we_a   = 16'h000F; // 只開啟最低 4 個 Byte (32-bit) 的寫入權限
    end
end

// --- Port B (負責讀取: RORC read & SEND) ---
reg [PTR_WIDTH-1:0] addr_b;

always @(*)
begin
    if (state == RORC)
        addr_b = pcd_addr; // DN 讀取 PCD
    else if(state == SEND)
        addr_b = (m_tvalid_r && !m00_axis_tready) ? rd_ptr - 1 : rd_ptr;
    else
        addr_b = rd_ptr;   // SEND 讀取完整資料
end

// ============================================================
// 3. 記憶體行為模型 (Byte-Write BRAM Inference)
//
// ============================================================
integer i;
always @(negedge aclk)
begin
    // Port A: 支援 Byte Write
    for (i = 0; i < NUM_BYTES; i = i + 1)
    begin
        if (we_a[i])
        begin
            ram[addr_a][(i*8) +: 8] <= din_a[(i*8) +: 8];
        end
    end

    // Port B: 同步讀取
    ram_out <= ram[addr_b];
end

// ============================================================
// 4. FSM Next State Logic
// ============================================================
always @(*)
begin
    case (state)
        IDLE:
            if (s00_axis_tvalid)
                next_state = RECV;
            else
                next_state = IDLE;
        RECV:
            if (s00_axis_tvalid && s00_axis_tready && s00_axis_tlast)
                next_state = RORC;
            else
                next_state = RECV;
        RORC:
            if (finish)
                next_state = SEND;
            else
                next_state = RORC;
        SEND:
            if (m_tvalid_r && m00_axis_tready && m_tlast_r)
                next_state = IDLE;
            else
                next_state = SEND;
        default:
            next_state = IDLE;
    endcase
end

// ============================================================
// 5. 主控制邏輯 (指標更新)
// ============================================================
always @(posedge aclk)
begin
    if (!aresetn)
    begin
        state      <= IDLE;
        wr_ptr     <= 0;
        rd_ptr     <= 0;
        word_count <= 0;
        m_tvalid_r <= 0;
        m_tlast_r  <= 0;
    end
    else
    begin
        state <= next_state;

        case (state)
            IDLE:
            begin
                wr_ptr <= 0;
                rd_ptr <= 0;
                word_count <= 0;
                m_tvalid_r <= 0;
                m_tlast_r <= 0;
            end

            RECV:
            begin
                if (s00_axis_tvalid && s00_axis_tready)
                begin
                    wr_ptr     <= wr_ptr + 1;
                    word_count <= word_count + 1;
                end
                m_tvalid_r <= 0;
                m_tlast_r <= 0;
            end

            RORC:
            begin
                if (finish)
                begin
                    rd_ptr     <= 0; // 重置讀取指標
                    m_tvalid_r <= 0;
                end
                else
                begin
                    m_tvalid_r <= 0;
                end
            end

            SEND:
            begin
                if (!m_tvalid_r || (m_tvalid_r && m00_axis_tready))
                begin
                    if (rd_ptr < word_count)
                    begin
                        m_tvalid_r <= 1'b1;
                        m_tlast_r  <= (rd_ptr == word_count - 1);
                        rd_ptr     <= rd_ptr + 1;
                    end
                    else
                    begin
                        m_tvalid_r <= 0;
                        m_tlast_r <= 0;
                    end
                end
            end

            default:
            begin
                state <= IDLE;
                m_tvalid_r <= 0;
            end
        endcase
    end
end


// Data Buffer
(* mark_debug = "true" *)reg [RAM_WIDTH-1:0] data_buf;

always @(posedge aclk)
begin
    if (!aresetn)
        data_buf <= 128'd0;
    else
        data_buf <= ram_out;
end


// ROR Unit Interface
always @(posedge aclk)
begin
    if (!aresetn)
        pcd_ready <= 1'b0;
    else
        pcd_ready <= (s00_axis_tvalid && s00_axis_tready && s00_axis_tlast) ? 1'b1 :
                  (finish) ? 1'b0 : pcd_ready;
end

// 解包 RAM 輸出給 DN (DN 只需要 PCD 部分，高位)
// ram_out [127:0] = {PCD[95:0], NOM[31:0]}
// 所以 PCD 在 [127:32]
assign pcd_data_from_dn_read = ram_out;

// DN 介面連接
DN D1 (
       .clk(aclk),
       .reset(!aresetn),
       .pcd_addr(pcd_addr),
       .pcd_req(pcd_req),
       .pcd_ready(pcd_ready),

       // 注意：這裡只取高 96 bits 給 DN
       .pcd_data({pcd_data_from_dn_read[127:32], 32'd0}),

       .nom_addr(nom_addr),
       .nom_valid(nom_valid),
       .nom_data(nom_data),
       .finish(finish)
   );

endmodule
