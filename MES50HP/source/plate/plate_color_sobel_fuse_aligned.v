// -----------------------------------------------------------------------------
// plate_color_sobel_fuse_aligned.v
// PLATE_V1_STEP3_FIX6: aligned color-near + vertical Sobel fusion.
//
// Why this module exists:
//   The previous STEP3_FIX5 generated color_near_mask and sobel_edge in two
//   separate pipelines, then directly ANDed them in the top level.  Because the
//   two pipelines have different line/pixel latency, the AND could compare two
//   different image coordinates and leave only random-looking sparse dots.
//
// Fix in this module:
//   Use one shared 9x3 streaming window for both branches.  The output center is
//   the same pixel for the color-near gate and the Sobel edge test, so
//   usable_edge_mask is intrinsically aligned.
//
// Window geometry:
//   At input pixel (x,y), the 9x3 window covers columns x-8..x and rows y-2..y.
//   The aligned output represents center pixel (x-4, y-1).  The displayed debug
//   image is therefore shifted a few pixels, which is acceptable for this stage;
//   the important property is that color_near_mask and edge_mask share the same
//   center coordinate.
//
// Debug-related outputs:
//   raw_edge_mask       : aligned raw Sobel vertical edge
//   color_clean_mask    : 3x3 majority-cleaned color candidate at center
//   color_near_mask     : denoised 9x3 color-neighborhood gate at center
//   usable_edge_mask    : raw_edge_mask & color_near_mask, same-pixel aligned
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module plate_color_sobel_fuse_aligned #(
    parameter integer IMG_W = 800,
    parameter [10:0] SOBEL_TH = 11'd220,
    parameter [3:0]  COLOR_CLEAN_MIN = 4'd4,
    parameter [5:0]  COLOR_NEAR_MIN  = 6'd4
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        de,
    input  wire [11:0] local_x,
    input  wire [11:0] local_y,
    input  wire [7:0]  gray_in,
    input  wire        color_mask_in,

    output reg         aligned_valid,
    output reg  [11:0] aligned_x,
    output reg  [11:0] aligned_y,
    output reg         raw_edge_mask,
    output reg         color_clean_mask,
    output reg         color_near_mask,
    output reg         usable_edge_mask,
    output reg  [10:0] abs_gx
);

localparam [11:0] IMG_W_L = IMG_W;

reg [7:0] gray_linebuf0 [0:IMG_W-1]; // previous row y-1
reg [7:0] gray_linebuf1 [0:IMG_W-1]; // two rows back y-2
reg       mask_linebuf0 [0:IMG_W-1];
reg       mask_linebuf1 [0:IMG_W-1];

wire [9:0] x_addr = local_x[9:0];
wire active_w = de && (local_x < IMG_W_L);

wire [7:0] gray_lb0_rd = active_w ? gray_linebuf0[x_addr] : 8'd0;
wire [7:0] gray_lb1_rd = active_w ? gray_linebuf1[x_addr] : 8'd0;
wire       mask_lb0_rd = active_w ? mask_linebuf0[x_addr] : 1'b0;
wire       mask_lb1_rd = active_w ? mask_linebuf1[x_addr] : 1'b0;

// Shift-register windows.  Chunk 0 / bit 0 is the newest column x;
// chunk 8 / bit 8 is the oldest column x-8.
reg [71:0] gray_top_sh;
reg [71:0] gray_mid_sh;
reg [71:0] gray_cur_sh;
reg [8:0]  mask_top_sh;
reg [8:0]  mask_mid_sh;
reg [8:0]  mask_cur_sh;

wire [71:0] gray_top_next = active_w ? ((local_x == 12'd0) ? {64'd0, gray_lb1_rd} : {gray_top_sh[63:0], gray_lb1_rd}) : 72'd0;
wire [71:0] gray_mid_next = active_w ? ((local_x == 12'd0) ? {64'd0, gray_lb0_rd} : {gray_mid_sh[63:0], gray_lb0_rd}) : 72'd0;
wire [71:0] gray_cur_next = active_w ? ((local_x == 12'd0) ? {64'd0, gray_in   } : {gray_cur_sh[63:0], gray_in   }) : 72'd0;
wire [8:0]  mask_top_next = active_w ? ((local_x == 12'd0) ? {8'd0, mask_lb1_rd} : {mask_top_sh[7:0], mask_lb1_rd}) : 9'd0;
wire [8:0]  mask_mid_next = active_w ? ((local_x == 12'd0) ? {8'd0, mask_lb0_rd} : {mask_mid_sh[7:0], mask_lb0_rd}) : 9'd0;
wire [8:0]  mask_cur_next = active_w ? ((local_x == 12'd0) ? {8'd0, color_mask_in} : {mask_cur_sh[7:0], color_mask_in}) : 9'd0;

// Helper count for 9-bit binary rows.
function [3:0] count9;
    input [8:0] bits;
    begin
        count9 = {3'd0, bits[0]} + {3'd0, bits[1]} + {3'd0, bits[2]} +
                 {3'd0, bits[3]} + {3'd0, bits[4]} + {3'd0, bits[5]} +
                 {3'd0, bits[6]} + {3'd0, bits[7]} + {3'd0, bits[8]};
    end
endfunction

wire [5:0] color_sum27_w = {2'd0, count9(mask_top_next)} +
                           {2'd0, count9(mask_mid_next)} +
                           {2'd0, count9(mask_cur_next)};
wire [3:0] color_sum3x3_w = {3'd0, mask_top_next[3]} + {3'd0, mask_top_next[4]} + {3'd0, mask_top_next[5]} +
                             {3'd0, mask_mid_next[3]} + {3'd0, mask_mid_next[4]} + {3'd0, mask_mid_next[5]} +
                             {3'd0, mask_cur_next[3]} + {3'd0, mask_cur_next[4]} + {3'd0, mask_cur_next[5]};

// 3x3 Sobel around the same center x-4/y-1.  In the 9-wide shift register,
// index 3 is center+1 and index 5 is center-1 because bit/chunk 0 is newest.
wire [7:0] top_c3 = gray_top_next[31:24];
wire [7:0] top_c5 = gray_top_next[47:40];
wire [7:0] mid_c3 = gray_mid_next[31:24];
wire [7:0] mid_c5 = gray_mid_next[47:40];
wire [7:0] cur_c3 = gray_cur_next[31:24];
wire [7:0] cur_c5 = gray_cur_next[47:40];

wire [10:0] sum_left_w  = {3'b000, top_c5} + ({3'b000, mid_c5} << 1) + {3'b000, cur_c5};
wire [10:0] sum_right_w = {3'b000, top_c3} + ({3'b000, mid_c3} << 1) + {3'b000, cur_c3};
wire signed [11:0] gx_w = $signed({1'b0, sum_right_w}) - $signed({1'b0, sum_left_w});
wire [10:0] abs_gx_w = gx_w[11] ? ((~gx_w[10:0]) + 11'd1) : gx_w[10:0];

wire valid_w = active_w && (local_x >= 12'd8) && (local_y >= 12'd2);
wire th_force_off_w = (SOBEL_TH >= 11'd1020);
wire raw_edge_w = valid_w && (!th_force_off_w) && (abs_gx_w > SOBEL_TH);
wire color_clean_w = valid_w && (color_sum3x3_w >= COLOR_CLEAN_MIN);
wire color_near_w  = valid_w && (color_sum27_w  >= COLOR_NEAR_MIN);
wire usable_edge_w = raw_edge_w && color_near_w;

always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        gray_top_sh <= 72'd0;
        gray_mid_sh <= 72'd0;
        gray_cur_sh <= 72'd0;
        mask_top_sh <= 9'd0;
        mask_mid_sh <= 9'd0;
        mask_cur_sh <= 9'd0;
        aligned_valid    <= 1'b0;
        aligned_x        <= 12'd0;
        aligned_y        <= 12'd0;
        raw_edge_mask    <= 1'b0;
        color_clean_mask <= 1'b0;
        color_near_mask  <= 1'b0;
        usable_edge_mask <= 1'b0;
        abs_gx           <= 11'd0;
    end else begin
        aligned_valid    <= valid_w;
        aligned_x        <= valid_w ? (local_x - 12'd4) : 12'd0;
        aligned_y        <= valid_w ? (local_y - 12'd1) : 12'd0;
        raw_edge_mask    <= raw_edge_w;
        color_clean_mask <= color_clean_w;
        color_near_mask  <= color_near_w;
        usable_edge_mask <= usable_edge_w;
        abs_gx           <= abs_gx_w;

        gray_top_sh <= gray_top_next;
        gray_mid_sh <= gray_mid_next;
        gray_cur_sh <= gray_cur_next;
        mask_top_sh <= mask_top_next;
        mask_mid_sh <= mask_mid_next;
        mask_cur_sh <= mask_cur_next;

        if(active_w) begin
            gray_linebuf1[x_addr] <= gray_lb0_rd;
            gray_linebuf0[x_addr] <= gray_in;
            mask_linebuf1[x_addr] <= mask_lb0_rd;
            mask_linebuf0[x_addr] <= color_mask_in;
        end
    end
end

endmodule
