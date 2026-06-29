// -----------------------------------------------------------------------------
// plate_overlay_bbox_dynamic.v
// PLATE_V1_STEP4: draw a dynamic outer-black / inner-red bbox overlay.
// Coordinates are local to one 800x480 HDMI window.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module plate_overlay_bbox_dynamic #(
    parameter [11:0] INNER_INSET  = 12'd6,
    parameter [11:0] BORDER_WIDTH = 12'd3,
    parameter [15:0] OUTER_COLOR  = 16'h0000,
    parameter [15:0] INNER_COLOR  = 16'hF800
)(
    input  wire [15:0] rgb565_in,
    input  wire [11:0] local_x,
    input  wire [11:0] local_y,
    input  wire        de,
    input  wire        bbox_valid,
    input  wire [11:0] bbox_x0,
    input  wire [11:0] bbox_y0,
    input  wire [11:0] bbox_x1,
    input  wire [11:0] bbox_y1,
    output wire [15:0] rgb565_out,
    output wire        border_hit
);

wire bbox_geometry_ok = bbox_valid &&
                        (bbox_x1 > (bbox_x0 + (INNER_INSET << 1) + BORDER_WIDTH)) &&
                        (bbox_y1 > (bbox_y0 + (INNER_INSET << 1) + BORDER_WIDTH));
wire [11:0] inner_x0 = bbox_x0 + INNER_INSET;
wire [11:0] inner_y0 = bbox_y0 + INNER_INSET;
wire [11:0] inner_x1 = bbox_x1 - INNER_INSET;
wire [11:0] inner_y1 = bbox_y1 - INNER_INSET;

wire outer_in_box = de && bbox_geometry_ok &&
                    (local_x >= bbox_x0) && (local_x <= bbox_x1) &&
                    (local_y >= bbox_y0) && (local_y <= bbox_y1);
wire outer_border = outer_in_box &&
                    (((local_x >= bbox_x0) && (local_x < (bbox_x0 + BORDER_WIDTH))) ||
                     ((local_x <= bbox_x1) && (local_x > (bbox_x1 - BORDER_WIDTH))) ||
                     ((local_y >= bbox_y0) && (local_y < (bbox_y0 + BORDER_WIDTH))) ||
                     ((local_y <= bbox_y1) && (local_y > (bbox_y1 - BORDER_WIDTH))));

wire inner_in_box = de && bbox_geometry_ok &&
                    (local_x >= inner_x0) && (local_x <= inner_x1) &&
                    (local_y >= inner_y0) && (local_y <= inner_y1);
wire inner_border = inner_in_box &&
                    (((local_x >= inner_x0) && (local_x < (inner_x0 + BORDER_WIDTH))) ||
                     ((local_x <= inner_x1) && (local_x > (inner_x1 - BORDER_WIDTH))) ||
                     ((local_y >= inner_y0) && (local_y < (inner_y0 + BORDER_WIDTH))) ||
                     ((local_y <= inner_y1) && (local_y > (inner_y1 - BORDER_WIDTH))));

assign border_hit = outer_border | inner_border;
assign rgb565_out = outer_border ? OUTER_COLOR :
                    inner_border ? INNER_COLOR :
                                   rgb565_in;

endmodule
