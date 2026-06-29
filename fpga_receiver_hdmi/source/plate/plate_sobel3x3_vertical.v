// -----------------------------------------------------------------------------
// plate_sobel3x3_vertical.v
// PLATE_V1_STEP3_FIX5: vertical Sobel edge detector for 800x480 local windows.
//
// The module is deliberately conservative for Pango/PDS RTL:
//   * one clocked process uses only non-blocking assignments
//   * line buffers keep two previous gray rows
//   * Sobel arithmetic is explicitly widened; theoretical abs_gx is 0..1020
//   * threshold >= 1020 is treated as force-off for the 1023 extinguish test
//   * edge output is gated by de and local coordinate validity
//
// Note: raw Sobel on a real camera/monitor scene can still be dense.  The top
// level therefore also provides a color-near gated debug mode for usable plate
// candidate visualization.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module plate_sobel3x3_vertical #(
    parameter integer IMG_W = 800,
    parameter [10:0] SOBEL_TH = 11'd700
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        de,
    input  wire [11:0] local_x,
    input  wire [11:0] local_y,
    input  wire [7:0]  gray_in,
    output reg         edge_valid,
    output reg         edge_mask,
    output reg  [10:0] abs_gx
);

localparam [11:0] IMG_W_L = IMG_W;

reg [7:0] linebuf0 [0:IMG_W-1]; // previous row
reg [7:0] linebuf1 [0:IMG_W-1]; // two rows back

wire [9:0] x_addr = local_x[9:0];
wire [7:0] lb0_rd = (x_addr < IMG_W) ? linebuf0[x_addr] : 8'd0;
wire [7:0] lb1_rd = (x_addr < IMG_W) ? linebuf1[x_addr] : 8'd0;

reg [7:0] p00, p01, p02;
reg [7:0] p10, p11, p12;
reg [7:0] p20, p21, p22;

wire [10:0] sum_left_w  = {3'b000, p00} + ({3'b000, p10} << 1) + {3'b000, p20};
wire [10:0] sum_right_w = {3'b000, p02} + ({3'b000, p12} << 1) + {3'b000, p22};
wire signed [11:0] gx_w = $signed({1'b0, sum_right_w}) - $signed({1'b0, sum_left_w});
wire [10:0] abs_gx_w = gx_w[11] ? ((~gx_w[10:0]) + 11'd1) : gx_w[10:0];
wire coord_valid_w = de && (local_x >= 12'd2) && (local_x < IMG_W_L) && (local_y >= 12'd2);
wire th_force_off_w = (SOBEL_TH >= 11'd1020);
wire edge_mask_w = coord_valid_w && (!th_force_off_w) && (abs_gx_w > SOBEL_TH);

always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
        p10 <= 8'd0; p11 <= 8'd0; p12 <= 8'd0;
        p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;
        edge_valid <= 1'b0;
        edge_mask  <= 1'b0;
        abs_gx     <= 11'd0;
    end else begin
        edge_valid <= coord_valid_w;
        edge_mask  <= edge_mask_w;
        abs_gx     <= abs_gx_w;

        if(de && (x_addr < IMG_W)) begin
            linebuf1[x_addr] <= lb0_rd;
            linebuf0[x_addr] <= gray_in;

            if(local_x == 12'd0) begin
                p00 <= 8'd0;    p01 <= 8'd0;    p02 <= lb1_rd;
                p10 <= 8'd0;    p11 <= 8'd0;    p12 <= lb0_rd;
                p20 <= 8'd0;    p21 <= 8'd0;    p22 <= gray_in;
            end else begin
                p00 <= p01;     p01 <= p02;     p02 <= lb1_rd;
                p10 <= p11;     p11 <= p12;     p12 <= lb0_rd;
                p20 <= p21;     p21 <= p22;     p22 <= gray_in;
            end
        end else begin
            // During blank or outside-window cycles, do not let stale end-of-row
            // samples leak into the next active row.
            p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
            p10 <= 8'd0; p11 <= 8'd0; p12 <= 8'd0;
            p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;
        end
    end
end

endmodule
