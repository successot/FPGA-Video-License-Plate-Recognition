// -----------------------------------------------------------------------------
// plate_overlay_box.v
// PLATE_V1_STEP2: fixed HDMI local-coordinate test rectangle overlay.
//
// Purpose:
//   Verify that each 800x480 HDMI window has the expected local coordinate
//   origin before adding Sobel, morphology, bbox tracking, or ROI crop.
//
// Function:
//   Draw a fixed dual rectangle: outer black border + inner red border.
//   This matches the requested "outer black / inner red" test-box style.
//   Otherwise pass rgb565_in unchanged.
// -----------------------------------------------------------------------------
module plate_overlay_box #(
    parameter [11:0] BOX_X0       = 12'd200,
    parameter [11:0] BOX_Y0       = 12'd180,
    parameter [11:0] BOX_X1       = 12'd500,
    parameter [11:0] BOX_Y1       = 12'd260,
    parameter [11:0] INNER_INSET  = 12'd14,
    parameter [11:0] BORDER_WIDTH = 12'd4,
    parameter [15:0] OUTER_COLOR  = 16'h0000,
    parameter [15:0] INNER_COLOR  = 16'hF800
)(
    input  wire [15:0] rgb565_in,
    input  wire [11:0] local_x,
    input  wire [11:0] local_y,
    input  wire        de,
    output wire [15:0] rgb565_out,
    output wire        border_hit
);

localparam [11:0] INNER_X0 = BOX_X0 + INNER_INSET;
localparam [11:0] INNER_Y0 = BOX_Y0 + INNER_INSET;
localparam [11:0] INNER_X1 = BOX_X1 - INNER_INSET;
localparam [11:0] INNER_Y1 = BOX_Y1 - INNER_INSET;

wire outer_in_box = de &&
                    (local_x >= BOX_X0) && (local_x <= BOX_X1) &&
                    (local_y >= BOX_Y0) && (local_y <= BOX_Y1);

wire outer_border = outer_in_box &&
                    (((local_x >= BOX_X0) && (local_x < (BOX_X0 + BORDER_WIDTH))) ||
                     ((local_x <= BOX_X1) && (local_x > (BOX_X1 - BORDER_WIDTH))) ||
                     ((local_y >= BOX_Y0) && (local_y < (BOX_Y0 + BORDER_WIDTH))) ||
                     ((local_y <= BOX_Y1) && (local_y > (BOX_Y1 - BORDER_WIDTH))));

wire inner_in_box = de &&
                    (local_x >= INNER_X0) && (local_x <= INNER_X1) &&
                    (local_y >= INNER_Y0) && (local_y <= INNER_Y1);

wire inner_border = inner_in_box &&
                    (((local_x >= INNER_X0) && (local_x < (INNER_X0 + BORDER_WIDTH))) ||
                     ((local_x <= INNER_X1) && (local_x > (INNER_X1 - BORDER_WIDTH))) ||
                     ((local_y >= INNER_Y0) && (local_y < (INNER_Y0 + BORDER_WIDTH))) ||
                     ((local_y <= INNER_Y1) && (local_y > (INNER_Y1 - BORDER_WIDTH))));

assign border_hit = outer_border | inner_border;
assign rgb565_out = outer_border ? OUTER_COLOR :
                    inner_border ? INNER_COLOR :
                                   rgb565_in;

endmodule
