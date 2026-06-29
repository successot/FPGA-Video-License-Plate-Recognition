`timescale 1ns / 1ps
`default_nettype wire
module fpgv_stage4_async_byte_fifo #(
    parameter ADDR_WIDTH = 12
)(
    input                  wr_clk,
    input                  wr_rst_n,
    input                  wr_en,
    input      [7:0]       wr_data,
    output                 full,
    output reg             overflow,

    input                  rd_clk,
    input                  rd_rst_n,
    input                  rd_en,
    output reg [7:0]       rd_data,
    output                 empty,
    output reg             underflow,

    output     [ADDR_WIDTH:0] wr_level_approx,
    output     [ADDR_WIDTH:0] rd_level_approx
);

localparam DEPTH = (1 << ADDR_WIDTH);

reg [7:0] mem [0:DEPTH-1];

reg [ADDR_WIDTH:0] wr_ptr_bin;
reg [ADDR_WIDTH:0] wr_ptr_gray;
reg [ADDR_WIDTH:0] rd_ptr_bin;
reg [ADDR_WIDTH:0] rd_ptr_gray;

reg [ADDR_WIDTH:0] rd_ptr_gray_wclk_d1;
reg [ADDR_WIDTH:0] rd_ptr_gray_wclk_d2;
reg [ADDR_WIDTH:0] wr_ptr_gray_rclk_d1;
reg [ADDR_WIDTH:0] wr_ptr_gray_rclk_d2;

function [ADDR_WIDTH:0] bin2gray;
    input [ADDR_WIDTH:0] bin;
    begin
        bin2gray = (bin >> 1) ^ bin;
    end
endfunction

function [ADDR_WIDTH:0] gray2bin;
    input [ADDR_WIDTH:0] gray;
    integer i;
    begin
        gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
        for(i = ADDR_WIDTH-1; i >= 0; i = i - 1)
            gray2bin[i] = gray2bin[i+1] ^ gray[i];
    end
endfunction

wire [ADDR_WIDTH:0] wr_ptr_bin_plus1  = wr_ptr_bin + {{ADDR_WIDTH{1'b0}}, 1'b1};
wire [ADDR_WIDTH:0] wr_ptr_gray_plus1 = bin2gray(wr_ptr_bin_plus1);
wire                 wr_do_write      = wr_en && !full;
wire [ADDR_WIDTH:0]  wr_ptr_bin_next  = wr_ptr_bin + {{ADDR_WIDTH{1'b0}}, wr_do_write};
wire [ADDR_WIDTH:0]  wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);

wire                 rd_do_read       = rd_en && !empty;
wire [ADDR_WIDTH:0]  rd_ptr_bin_next  = rd_ptr_bin + {{ADDR_WIDTH{1'b0}}, rd_do_read};
wire [ADDR_WIDTH:0]  rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

assign full  = (wr_ptr_gray_plus1 == {~rd_ptr_gray_wclk_d2[ADDR_WIDTH:ADDR_WIDTH-1],
                                       rd_ptr_gray_wclk_d2[ADDR_WIDTH-2:0]});
assign empty = (rd_ptr_gray == wr_ptr_gray_rclk_d2);

wire [ADDR_WIDTH:0] rd_ptr_bin_wclk = gray2bin(rd_ptr_gray_wclk_d2);
wire [ADDR_WIDTH:0] wr_ptr_bin_rclk = gray2bin(wr_ptr_gray_rclk_d2);

assign wr_level_approx = wr_ptr_bin - rd_ptr_bin_wclk;
assign rd_level_approx = wr_ptr_bin_rclk - rd_ptr_bin;

always @(posedge wr_clk or negedge wr_rst_n) begin
    if(!wr_rst_n) begin
        wr_ptr_bin          <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray         <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_wclk_d1 <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_wclk_d2 <= {ADDR_WIDTH+1{1'b0}};
        overflow            <= 1'b0;
    end else begin
        rd_ptr_gray_wclk_d1 <= rd_ptr_gray;
        rd_ptr_gray_wclk_d2 <= rd_ptr_gray_wclk_d1;

        if(wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end else if(wr_en && full) begin
            overflow <= 1'b1;
        end
    end
end

always @(posedge rd_clk or negedge rd_rst_n) begin
    if(!rd_rst_n) begin
        rd_ptr_bin          <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray         <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_rclk_d1 <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_rclk_d2 <= {ADDR_WIDTH+1{1'b0}};
        rd_data             <= 8'd0;
        underflow           <= 1'b0;
    end else begin
        wr_ptr_gray_rclk_d1 <= wr_ptr_gray;
        wr_ptr_gray_rclk_d2 <= wr_ptr_gray_rclk_d1;

        if(rd_en && !empty) begin
            rd_data     <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end else if(rd_en && empty) begin
            underflow <= 1'b1;
        end
    end
end

endmodule
