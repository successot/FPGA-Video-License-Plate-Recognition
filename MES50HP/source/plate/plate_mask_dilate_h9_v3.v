// -----------------------------------------------------------------------------
// plate_mask_dilate_h9_v3.v
// PLATE_V1_STEP3_FIX5: simple binary dilation for color-mask neighborhood.
//
// It expands a blue/green plate-color candidate mask horizontally by 9 pixels
// and vertically by 3 rows.  This lets vertical edges on white/black characters
// next to blue/green plate background survive the usable-edge gate.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module plate_mask_dilate_h9_v3 #(
    parameter integer IMG_W = 800
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        de,
    input  wire [11:0] local_x,
    input  wire        mask_in,
    output reg         mask_near
);

localparam [11:0] IMG_W_L = IMG_W;

reg linebuf0 [0:IMG_W-1];
reg linebuf1 [0:IMG_W-1];

wire [9:0] x_addr = local_x[9:0];
wire lb0_rd = (x_addr < IMG_W) ? linebuf0[x_addr] : 1'b0;
wire lb1_rd = (x_addr < IMG_W) ? linebuf1[x_addr] : 1'b0;

reg [8:0] sh_top;
reg [8:0] sh_mid;
reg [8:0] sh_cur;

wire near_w = |sh_top | |sh_mid | |sh_cur;

always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        sh_top   <= 9'd0;
        sh_mid   <= 9'd0;
        sh_cur   <= 9'd0;
        mask_near <= 1'b0;
    end else begin
        mask_near <= de && near_w;
        if(de && (x_addr < IMG_W)) begin
            linebuf1[x_addr] <= lb0_rd;
            linebuf0[x_addr] <= mask_in;

            if(local_x == 12'd0) begin
                sh_top <= {8'd0, lb1_rd};
                sh_mid <= {8'd0, lb0_rd};
                sh_cur <= {8'd0, mask_in};
            end else begin
                sh_top <= {sh_top[7:0], lb1_rd};
                sh_mid <= {sh_mid[7:0], lb0_rd};
                sh_cur <= {sh_cur[7:0], mask_in};
            end
        end else begin
            sh_top <= 9'd0;
            sh_mid <= 9'd0;
            sh_cur <= 9'd0;
        end
    end
end

endmodule
