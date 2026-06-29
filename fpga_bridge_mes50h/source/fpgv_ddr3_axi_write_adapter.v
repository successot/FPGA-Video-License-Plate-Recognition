`timescale 1ns / 1ps
`default_nettype wire
// -----------------------------------------------------------------------------
// fpgv_ddr3_axi_write_adapter
// -----------------------------------------------------------------------------
// 用途：
//   把阶段4抽象 DDR 写前级产生的 32bit 写数据，转换成 ddr3_eth IP 的
//   128bit AXI 写接口。
// 
// 输入来自阶段4模块：
//   stage4_ddr_wdata_en
//   stage4_ddr_wdata[31:0]
//   stage4_ddr_frame_done_pulse
//
// 输出连接到 ddr3_eth IP：
//   axi_awaddr / axi_awlen / axi_awvalid / axi_awready
//   axi_wdata  / axi_wstrb / axi_wready
//
// 说明：
//   ddr3_eth 的用户数据宽度为 MEM_DQ_WIDTH*8 = 16*8 = 128bit。
//   因此本模块把 4 个 32bit word 合成为 1 个 128bit word 后写入 DDR3。
// -----------------------------------------------------------------------------
module fpgv_ddr3_axi_write_adapter #(
    parameter [27:0] FRAME0_BASE_ADDR = 28'h0000000,
    parameter [27:0] FRAME1_BASE_ADDR = 28'h0100000,
    parameter [31:0] EXPECTED_FRAME_BYTES = 32'd768000,
    parameter        ENABLE_DOUBLE_BUFFER = 1'b1,
    parameter        FIFO_ADDR_WIDTH = 10
)(
    input             clk,
    input             rst_n,
    input             ddr_init_done,

    input             in_wr_en,
    input      [31:0] in_wdata,
    input             in_frame_done,

    output reg [27:0] axi_awaddr,
    output reg        axi_awuser_ap,
    output reg [3:0]  axi_awuser_id,
    output reg [3:0]  axi_awlen,
    input             axi_awready,
    output reg        axi_awvalid,

    output reg [127:0] axi_wdata,
    output     [15:0]  axi_wstrb,
    input              axi_wready,

    output reg        axi_write_fire_pulse,
    output reg        axi_frame_done_pulse,
    output reg        fifo_overflow_pulse,
    output reg [31:0] in_word_count32,
    output reg [31:0] axi_word_count128,
    output reg [31:0] axi_frame_byte_count,
    output reg [31:0] axi_complete_frame_count,
    output reg [31:0] adapter_overflow_count,
    output reg [27:0] current_axi_addr,
    output reg        frame_buffer_index,
    output            word_fifo_full,
    output            word_fifo_empty
);

localparam FIFO_DEPTH = (1 << FIFO_ADDR_WIDTH);
localparam ST_IDLE = 2'd0;
localparam ST_AW   = 2'd1;
localparam ST_W    = 2'd2;

reg [127:0] fifo_mem [0:FIFO_DEPTH-1];
reg [FIFO_ADDR_WIDTH:0] wr_ptr;
reg [FIFO_ADDR_WIDTH:0] rd_ptr;

reg [127:0] pack_word;
reg [1:0]   pack_lane;

reg [127:0] cur_wdata;
reg [1:0]   state;

wire [FIFO_ADDR_WIDTH:0] fifo_used = wr_ptr - rd_ptr;

assign word_fifo_empty = (wr_ptr == rd_ptr);
assign word_fifo_full  = (fifo_used == FIFO_DEPTH[FIFO_ADDR_WIDTH:0]);
assign axi_wstrb       = 16'hFFFF;

// -----------------------------------------------------------------------------
// 32bit 输入打包为 128bit，并写入内部 word FIFO。
// -----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wr_ptr                 <= {FIFO_ADDR_WIDTH+1{1'b0}};
        pack_word              <= 128'd0;
        pack_lane              <= 2'd0;
        in_word_count32        <= 32'd0;
        fifo_overflow_pulse    <= 1'b0;
        adapter_overflow_count <= 32'd0;
    end else begin
        fifo_overflow_pulse <= 1'b0;

        if(in_wr_en) begin
            in_word_count32 <= in_word_count32 + 32'd1;

            case(pack_lane)
            2'd0: begin
                pack_word[127:96] <= in_wdata;
                pack_lane         <= 2'd1;
            end

            2'd1: begin
                pack_word[95:64] <= in_wdata;
                pack_lane        <= 2'd2;
            end

            2'd2: begin
                pack_word[63:32] <= in_wdata;
                pack_lane        <= 2'd3;
            end

            default: begin
                pack_lane <= 2'd0;
                if(!word_fifo_full) begin
                    fifo_mem[wr_ptr[FIFO_ADDR_WIDTH-1:0]] <= {pack_word[127:32], in_wdata};
                    wr_ptr <= wr_ptr + {{FIFO_ADDR_WIDTH{1'b0}}, 1'b1};
                end else begin
                    fifo_overflow_pulse    <= 1'b1;
                    adapter_overflow_count <= adapter_overflow_count + 32'd1;
                end
            end
            endcase
        end

        if(in_frame_done) begin
            // 800*480*2 = 768000 字节，能被 16 整除。
            // 正常帧结束时 pack_lane 应该已经回到 0。
            pack_lane <= 2'd0;
        end
    end
end

// -----------------------------------------------------------------------------
// 从内部 FIFO 取 128bit word，通过 ddr3_eth AXI 写接口写入 DDR3。
// 当前采用单 beat burst：axi_awlen = 0。
// -----------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_ptr                   <= {FIFO_ADDR_WIDTH+1{1'b0}};
        state                    <= ST_IDLE;
        cur_wdata                <= 128'd0;

        axi_awaddr               <= FRAME0_BASE_ADDR;
        axi_awuser_ap            <= 1'b0;
        axi_awuser_id            <= 4'd0;
        axi_awlen                <= 4'd0;
        axi_awvalid              <= 1'b0;
        axi_wdata                <= 128'd0;

        axi_write_fire_pulse     <= 1'b0;
        axi_frame_done_pulse     <= 1'b0;
        axi_word_count128        <= 32'd0;
        axi_frame_byte_count     <= 32'd0;
        axi_complete_frame_count <= 32'd0;
        current_axi_addr         <= FRAME0_BASE_ADDR;
        frame_buffer_index       <= 1'b0;
    end else begin
        axi_write_fire_pulse <= 1'b0;
        axi_frame_done_pulse <= 1'b0;

        if(!ddr_init_done) begin
            state       <= ST_IDLE;
            axi_awvalid <= 1'b0;
        end else begin
            case(state)
            ST_IDLE: begin
                axi_awvalid <= 1'b0;

                if(!word_fifo_empty) begin
                    cur_wdata   <= fifo_mem[rd_ptr[FIFO_ADDR_WIDTH-1:0]];
                    rd_ptr      <= rd_ptr + {{FIFO_ADDR_WIDTH{1'b0}}, 1'b1};

                    axi_awaddr  <= current_axi_addr;
                    axi_awlen   <= 4'd0;
                    axi_awvalid <= 1'b1;
                    state       <= ST_AW;
                end
            end

            ST_AW: begin
                axi_awvalid <= 1'b1;

                if(axi_awvalid && axi_awready) begin
                    axi_awvalid <= 1'b0;
                    axi_wdata   <= cur_wdata;
                    state       <= ST_W;
                end
            end

            ST_W: begin
                axi_wdata <= cur_wdata;

                if(axi_wready) begin
                    axi_write_fire_pulse <= 1'b1;
                    axi_word_count128    <= axi_word_count128 + 32'd1;
                    axi_awuser_id        <= axi_awuser_id + 4'd1;

                    if(axi_frame_byte_count == (EXPECTED_FRAME_BYTES - 32'd16)) begin
                        axi_frame_done_pulse     <= 1'b1;
                        axi_complete_frame_count <= axi_complete_frame_count + 32'd1;
                        axi_frame_byte_count     <= 32'd0;

                        if(ENABLE_DOUBLE_BUFFER) begin
                            frame_buffer_index <= ~frame_buffer_index;
                            current_axi_addr   <= frame_buffer_index ? FRAME0_BASE_ADDR : FRAME1_BASE_ADDR;
                        end else begin
                            current_axi_addr   <= FRAME0_BASE_ADDR;
                        end
                    end else begin
                        axi_frame_byte_count <= axi_frame_byte_count + 32'd16;
                        current_axi_addr     <= current_axi_addr + 28'd8;
                    end

                    state <= ST_IDLE;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
            endcase
        end
    end
end

endmodule
