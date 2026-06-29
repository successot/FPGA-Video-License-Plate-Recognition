// -----------------------------------------------------------------------------
// plate_rgb565_preprocess.v
// PLATE_V1_STEP2: RGB565 basic preprocessing and license-plate color masks.
//
// This module is intentionally lightweight RTL:
//   * RGB565 -> r8/g8/b8
//   * integer grayscale approximation: gray=(77*R + 150*G + 29*B)>>8
//   * blue / green plate-color candidate masks with parameterized thresholds
//   * debug display mode for HDMI threshold tuning
//
// DEBUG_MODE:
//   3'd0: pass original rgb565_in
//   3'd1: show color_mask as black/white image
//   3'd2: overlay color_mask with HIGHLIGHT_COLOR on top of original image
//   3'd3: show grayscale image
//   3'd4..7: pass original rgb565_in; top-level Sobel/debug mux handles these modes
// -----------------------------------------------------------------------------
module plate_rgb565_preprocess #(
    parameter [7:0] BLUE_B_MIN       = 8'd120,
    parameter [7:0] BLUE_BR_DIFF     = 8'd44,
    parameter [7:0] BLUE_BG_DIFF     = 8'd30,
    parameter [7:0] GREEN_G_MIN      = 8'd255,
    parameter [7:0] GREEN_GR_DIFF    = 8'd15,
    parameter [7:0] GREEN_GB_MARGIN  = 8'd20,
    parameter [2:0] DEBUG_MODE       = 3'd0,
    parameter [15:0] HIGHLIGHT_COLOR = 16'hFFE0
)(
    input  wire [15:0] rgb565_in,
    input  wire        de,
    output wire [15:0] rgb565_out,
    output wire [7:0]  gray,
    output wire        blue_mask,
    output wire        green_mask,
    output wire        color_mask
);

wire [7:0] r8 = {rgb565_in[15:11], rgb565_in[15:13]};
wire [7:0] g8 = {rgb565_in[10:5],  rgb565_in[10:9]};
wire [7:0] b8 = {rgb565_in[4:0],   rgb565_in[4:2]};

wire [15:0] gray_r = r8 * 8'd77;
wire [15:0] gray_g = g8 * 8'd150;
wire [15:0] gray_b = b8 * 8'd29;
wire [17:0] gray_sum = {2'b00, gray_r} + {2'b00, gray_g} + {2'b00, gray_b};
assign gray = gray_sum[15:8];

// Use 9-bit comparisons to avoid overflow when adding tunable threshold margins.
wire [8:0] r9 = {1'b0, r8};
wire [8:0] g9 = {1'b0, g8};
wire [8:0] b9 = {1'b0, b8};

assign blue_mask = de &&
                   (b8 > BLUE_B_MIN) &&
                   (b9 > (r9 + {1'b0, BLUE_BR_DIFF})) &&
                   (b9 > (g9 + {1'b0, BLUE_BG_DIFF}));

assign green_mask = de &&
                    (g8 > GREEN_G_MIN) &&
                    (g9 > (r9 + {1'b0, GREEN_GR_DIFF})) &&
                    ((g9 + {1'b0, GREEN_GB_MARGIN}) >= b9);

assign color_mask = blue_mask | green_mask;

wire [15:0] gray565 = {gray[7:3], gray[7:2], gray[7:3]};
wire [15:0] mask_bw = color_mask ? 16'hFFFF : 16'h0000;
wire [15:0] mask_overlay = color_mask ? HIGHLIGHT_COLOR : rgb565_in;

assign rgb565_out = !de ? rgb565_in :
                    (DEBUG_MODE == 3'd1) ? mask_bw :
                    (DEBUG_MODE == 3'd2) ? mask_overlay :
                    (DEBUG_MODE == 3'd3) ? gray565 :
                                           rgb565_in;

endmodule
